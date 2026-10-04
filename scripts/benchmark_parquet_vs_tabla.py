#!/usr/bin/env python3
"""Benchmark: consultar Parquet directamente contra una tabla materializada en DuckDB.

Que hace:
  1. Construye (o completa) la base data/processed/taxis.duckdb con la tabla
     `viajes` (amarillos y verdes de todos los anios que haya en data/raw, con
     la misma normalizacion de columnas que usan las consultas) y la tabla
     `zonas`. La carga es incremental: solo se insertan los meses que faltan, asi
     que al descargar un anio nuevo basta con volver a ejecutar el script.
  2. Para cada volumen de datos pedido (por ejemplo un mes, un anio, dos anios)
     ejecuta las mismas consultas de sql/ejercicio_06/ con las dos estrategias:
       - parquet: lee directamente los archivos Parquet de ese volumen;
       - tabla  : lee la tabla materializada, filtrada a esos mismos meses.
  3. Cada consulta se ejecuta una vez de calentamiento (no cuenta) y luego
     --repeticiones veces medidas. Se reporta mediana, minimo, maximo y desviacion.
  4. Comprueba que las dos estrategias devuelven el mismo resultado.

Uso (dentro del contenedor lab, desde /workspace):
    python scripts/benchmark_parquet_vs_tabla.py
    python scripts/benchmark_parquet_vs_tabla.py --volumenes 2026-08 2026 2024 2024,2026
    python scripts/benchmark_parquet_vs_tabla.py --volumenes 2024,2025,2026 --repeticiones 3
    python scripts/benchmark_parquet_vs_tabla.py --reconstruir          # rehace la tabla
    python scripts/benchmark_parquet_vs_tabla.py --reconstruir --solo-construir   # solo la carga

Un volumen es una lista de anios (2024) o meses (2026-08) separados por comas.

Salidas:
    docs/benchmark_resultados.csv     resumen por volumen, consulta y estrategia
    docs/benchmark_entorno.json       version de DuckDB, hilos, memoria, tamanos
    docs/benchmark_carga_tabla.json   tiempo de la ultima carga de la tabla
    data/processed/benchmark_crudo.csv   cada medicion individual (no va a Git)

Para medir de forma justa conviene detener Metabase y no correr nada mas pesado
mientras el script corre:  docker compose stop metabase
"""

import argparse
import csv
import hashlib
import json
import re
import statistics
import sys
import time
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
DIR_RAW = RAIZ / "data" / "raw"
DIR_SQL = RAIZ / "sql" / "ejercicio_06"
PLANTILLA = DIR_SQL / "00_normalizar_viajes.sql"
BASE_POR_DEFECTO = RAIZ / "data" / "processed" / "taxis.duckdb"
CSV_RESUMEN = RAIZ / "docs" / "benchmark_resultados.csv"
JSON_ENTORNO = RAIZ / "docs" / "benchmark_entorno.json"
CSV_CRUDO = RAIZ / "data" / "processed" / "benchmark_crudo.csv"
JSON_CARGA = RAIZ / "docs" / "benchmark_carga_tabla.json"
CSV_ZONAS = DIR_RAW / "zonas" / "taxi_zone_lookup.csv"

VOLUMENES_POR_DEFECTO = ["2026-08", "2026", "2024", "2024,2026"]


def orden_natural(ruta: Path):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", ruta.name)]


def descubrir_archivos() -> dict:
    """Devuelve {(anio, mes): {"yellow": ruta, "green": ruta}} con los Parquet de data/raw."""
    meses = {}
    for ruta in sorted(DIR_RAW.glob("*/*/*_tripdata_*.parquet")):
        coincide = re.search(r"(yellow|green)_tripdata_(\d{4})-(\d{2})\.parquet$", ruta.name)
        if not coincide:
            continue
        tipo, anio, mes = coincide.group(1), int(coincide.group(2)), int(coincide.group(3))
        meses.setdefault((anio, mes), {})[tipo] = ruta
    return meses


def seleccionar_meses(meses: dict, volumen: str) -> list:
    """Meses (anio, mes) que componen un volumen como '2024,2026-08'."""
    elegidos = set()
    for ficha in volumen.split(","):
        ficha = ficha.strip()
        if re.fullmatch(r"\d{4}", ficha):
            elegidos |= {k for k in meses if k[0] == int(ficha)}
        elif re.fullmatch(r"\d{4}-\d{2}", ficha):
            clave = (int(ficha[:4]), int(ficha[5:]))
            if clave in meses:
                elegidos.add(clave)
        else:
            raise SystemExit(f"volumen no valido: {ficha!r} (use 2024 o 2024-03)")
    if not elegidos:
        raise SystemExit(f"el volumen {volumen!r} no tiene archivos en data/raw")
    return sorted(elegidos)


def lista_sql(rutas) -> str:
    return "[" + ", ".join("'" + str(r).replace("'", "''") + "'" for r in rutas) + "]"


def fuente_normalizada(meses: dict, claves: list) -> str:
    """SELECT normalizado sobre los Parquet de los meses dados (plantilla 00)."""
    amarillos = [meses[k]["yellow"] for k in claves if "yellow" in meses[k]]
    verdes = [meses[k]["green"] for k in claves if "green" in meses[k]]
    texto = PLANTILLA.read_text(encoding="utf-8")
    return texto.replace("$ARCHIVOS_YELLOW$", lista_sql(amarillos)).replace(
        "$ARCHIVOS_GREEN$", lista_sql(verdes))


def conectar(base, solo_lectura: bool, hilos: int, memoria: str):
    con = duckdb.connect(str(base) if base else ":memory:", read_only=solo_lectura)
    con.execute(f"SET threads = {hilos}")
    con.execute(f"SET memory_limit = '{memoria}'")
    return con


def construir_tabla(meses: dict, base: Path, reconstruir: bool, hilos: int, memoria: str) -> dict:
    """Crea o completa la tabla viajes. Devuelve tiempos y tamanos de la carga."""
    base.parent.mkdir(parents=True, exist_ok=True)
    if reconstruir and base.exists():
        base.unlink()
    con = conectar(base, False, hilos, memoria)
    existe = con.execute(
        "SELECT count(*) FROM information_schema.tables WHERE table_name = 'viajes'").fetchone()[0]
    todos = sorted(meses)
    if not existe:
        print("Creando la tabla viajes (esquema de todos los archivos)...")
        con.execute(f"CREATE TABLE viajes AS SELECT * FROM ({fuente_normalizada(meses, todos)}) WHERE false")
        cargados = set()
    else:
        cargados = {(a, int(m[5:])) for a, m in con.execute(
            "SELECT DISTINCT anio_archivo, mes_archivo FROM viajes").fetchall()}
    pendientes = [k for k in todos if k not in cargados]

    inicio = time.perf_counter()
    por_mes = {}
    for anio, mes in pendientes:
        t = time.perf_counter()
        con.execute(f"INSERT INTO viajes BY NAME {fuente_normalizada(meses, [(anio, mes)])}")
        por_mes[f"{anio}-{mes:02d}"] = round(time.perf_counter() - t, 1)
        print(f"  insertado {anio}-{mes:02d} ({por_mes[f'{anio}-{mes:02d}']} s)")
    segundos_carga = time.perf_counter() - inicio

    con.execute("DROP TABLE IF EXISTS zonas")
    con.execute(f"CREATE TABLE zonas AS SELECT LocationID, Borough AS barrio, Zone AS zona, "
                f"service_zone FROM read_csv('{CSV_ZONAS}')")
    con.execute("CHECKPOINT")
    filas = con.execute("SELECT count(*) FROM viajes").fetchone()[0]
    con.close()
    carga = {
        "meses_insertados": len(pendientes),
        "segundos_carga": round(segundos_carga, 1),
        "segundos_por_mes": por_mes,
        "filas_tabla": filas,
        "tamano_base_mb": round(base.stat().st_size / 1024 ** 2, 1),
    }
    if pendientes:  # solo se guarda cuando hubo una carga real que medir
        JSON_CARGA.write_text(json.dumps(carga, indent=2), encoding="utf-8")
    return carga


def condicion_tabla(claves: list) -> str:
    """Filtro de la tabla equivalente a leer solo los archivos de esos meses."""
    lista = ", ".join(f"'{a}-{m:02d}'" for a, m in claves)
    return f"mes_archivo IN ({lista})"


def huella(filas) -> str:
    return hashlib.sha256(repr(filas).encode("utf-8")).hexdigest()[:12]


def medir(con, sql: str, repeticiones: int, calentamiento: int):
    """Ejecuta una consulta y devuelve (tiempos, primera_ejecucion, huella_del_resultado)."""
    primera = None
    resultado = None
    for i in range(calentamiento):
        t = time.perf_counter()
        resultado = con.execute(sql).fetchall()
        if primera is None:
            primera = time.perf_counter() - t
    tiempos = []
    for _ in range(repeticiones):
        t = time.perf_counter()
        resultado = con.execute(sql).fetchall()
        tiempos.append(time.perf_counter() - t)
    return tiempos, primera, huella(resultado)


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Parquet contra tabla DuckDB.")
    parser.add_argument("--volumenes", nargs="+", default=VOLUMENES_POR_DEFECTO,
                        help="volumenes a medir, p. ej. 2026-08 2026 2024 2024,2026")
    parser.add_argument("--repeticiones", type=int, default=5, help="mediciones por consulta (5)")
    parser.add_argument("--calentamiento", type=int, default=1, help="ejecuciones previas que no cuentan (1)")
    parser.add_argument("--base", type=Path, default=BASE_POR_DEFECTO, help="archivo .duckdb de la tabla")
    parser.add_argument("--reconstruir", action="store_true", help="borra y vuelve a crear la tabla")
    parser.add_argument("--solo-construir", action="store_true",
                        help="construir o completar la tabla y terminar, sin medir consultas")
    parser.add_argument("--solo-consultas", nargs="*", default=None, metavar="PREFIJO",
                        help="medir solo las consultas cuyo nombre empieza con estos prefijos")
    parser.add_argument("--hilos", type=int, default=4, help="hilos de DuckDB (4)")
    parser.add_argument("--memoria", default="2GB", help="limite de memoria de DuckDB (2GB)")
    parser.add_argument("--salida", type=Path, default=CSV_RESUMEN, help="CSV con el resumen")
    argumentos = parser.parse_args()

    meses = descubrir_archivos()
    if not meses:
        raise SystemExit("no hay Parquet en data/raw; ejecute primero scripts/download_data.py")
    consultas = sorted((c for c in DIR_SQL.glob("6_*.sql")), key=orden_natural)
    if argumentos.solo_consultas is not None:
        consultas = [c for c in consultas if any(c.name.startswith(p) for p in argumentos.solo_consultas)]

    print(f"DuckDB {duckdb.__version__}, {argumentos.hilos} hilos, memoria {argumentos.memoria}")
    print("\n== Construccion de la tabla materializada ==")
    carga = construir_tabla(meses, argumentos.base, argumentos.reconstruir, argumentos.hilos, argumentos.memoria)
    print(f"  meses insertados en esta corrida: {carga['meses_insertados']}")
    print(f"  filas en la tabla: {carga['filas_tabla']:,}  base: {carga['tamano_base_mb']} MB")
    if carga["meses_insertados"]:
        print(f"  tiempo de carga: {carga['segundos_carga']} s para {carga['meses_insertados']} meses")
    if argumentos.solo_construir:
        return 0

    resumen, crudo = [], []
    huellas = {}
    for volumen in argumentos.volumenes:
        claves = seleccionar_meses(meses, volumen)
        archivos = [p for k in claves for p in meses[k].values()]
        mb_parquet = sum(p.stat().st_size for p in archivos) / 1024 ** 2
        filas_volumen = None
        print(f"\n== Volumen {volumen}: {len(claves)} meses, {len(archivos)} archivos, {mb_parquet:.0f} MB de Parquet ==")

        for estrategia in ("parquet", "tabla"):
            if estrategia == "parquet":
                con = conectar(None, False, argumentos.hilos, argumentos.memoria)
                con.execute(f"CREATE VIEW src AS {fuente_normalizada(meses, claves)}")
            else:
                con = conectar(argumentos.base, True, argumentos.hilos, argumentos.memoria)
                con.execute(f"CREATE TEMP VIEW src AS SELECT * FROM viajes WHERE {condicion_tabla(claves)}")
            if filas_volumen is None:
                filas_volumen = con.execute("SELECT count(*) FROM src").fetchone()[0]
            for consulta in consultas:
                sql = consulta.read_text(encoding="utf-8")
                try:
                    tiempos, primera, h = medir(con, sql, argumentos.repeticiones, argumentos.calentamiento)
                except Exception as error:
                    print(f"  {estrategia:<7} {consulta.stem:<38} ERROR {str(error)[:90]}")
                    resumen.append({"volumen": volumen, "meses": len(claves), "filas": filas_volumen,
                                    "consulta": consulta.stem, "estrategia": estrategia, "error": str(error)[:120]})
                    continue
                huellas[(volumen, consulta.stem, estrategia)] = h
                for n, s in enumerate(tiempos, 1):
                    crudo.append({"volumen": volumen, "consulta": consulta.stem, "estrategia": estrategia,
                                  "repeticion": n, "segundos": round(s, 4)})
                resumen.append({
                    "volumen": volumen, "meses": len(claves), "filas": filas_volumen,
                    "mb_parquet": round(mb_parquet, 1), "consulta": consulta.stem, "estrategia": estrategia,
                    "primera_s": round(primera, 3) if primera is not None else "",
                    "mediana_s": round(statistics.median(tiempos), 3),
                    "minimo_s": round(min(tiempos), 3), "maximo_s": round(max(tiempos), 3),
                    "desviacion_s": round(statistics.pstdev(tiempos), 3), "repeticiones": len(tiempos),
                })
                print(f"  {estrategia:<7} {consulta.stem:<38} mediana {statistics.median(tiempos):7.3f} s "
                      f"(min {min(tiempos):.3f}, max {max(tiempos):.3f})")
            con.close()

    # Validez de la comparacion: las dos estrategias deben devolver lo mismo.
    distintos = []
    for fila in resumen:
        if "error" in fila:
            continue
        a = huellas.get((fila["volumen"], fila["consulta"], "parquet"))
        b = huellas.get((fila["volumen"], fila["consulta"], "tabla"))
        fila["resultado_igual"] = "si" if a == b else "NO"
        if a != b:
            distintos.append((fila["volumen"], fila["consulta"]))

    columnas = ["volumen", "meses", "filas", "mb_parquet", "consulta", "estrategia", "primera_s", "mediana_s",
                "minimo_s", "maximo_s", "desviacion_s", "repeticiones", "resultado_igual", "error"]
    argumentos.salida.parent.mkdir(parents=True, exist_ok=True)
    with argumentos.salida.open("w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=columnas, extrasaction="ignore")
        escritor.writeheader()
        escritor.writerows(resumen)
    CSV_CRUDO.parent.mkdir(parents=True, exist_ok=True)
    with CSV_CRUDO.open("w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=["volumen", "consulta", "estrategia", "repeticion", "segundos"])
        escritor.writeheader()
        escritor.writerows(crudo)
    mb_parquet_total = sum(p.stat().st_size for rutas in meses.values() for p in rutas.values()) / 1024 ** 2
    JSON_ENTORNO.write_text(json.dumps({
        "duckdb": duckdb.__version__, "hilos": argumentos.hilos, "memoria": argumentos.memoria,
        "repeticiones": argumentos.repeticiones, "calentamiento": argumentos.calentamiento,
        "volumenes": argumentos.volumenes,
        # si la tabla ya existia, se informa la ultima carga real que se midio
        "carga_tabla": (json.loads(JSON_CARGA.read_text(encoding="utf-8"))
                        if carga["meses_insertados"] == 0 and JSON_CARGA.exists() else carga),
        "mb_parquet_total": round(mb_parquet_total, 1),
    }, indent=2), encoding="utf-8")

    print(f"\nResumen guardado en {argumentos.salida}")
    if distintos:
        print("ATENCION: resultados distintos entre estrategias en:", distintos)
        return 1
    print("Todas las consultas devolvieron el mismo resultado con las dos estrategias.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
