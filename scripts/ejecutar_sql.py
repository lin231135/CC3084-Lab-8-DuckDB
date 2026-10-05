#!/usr/bin/env python3
"""Ejecuta los archivos .sql de una carpeta sobre los Parquet con DuckDB.

Sirve para reproducir resultados desde la terminal y para comprobar que las
consultas siguen funcionando cuando cambian los datos (por ejemplo al agregar
un anio). Cada archivo debe contener una sola consulta.

Uso (dentro del contenedor lab, desde /workspace):
    python scripts/ejecutar_sql.py sql/ejercicio_04 \\
        --vistas sql/ejercicio_03/00_vista_viajes.sql sql/ejercicio_04/00_vistas_apoyo.sql
    python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas ... --salida data/processed/resultados/ej04
    python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas ... --solo 4_1_ 4_8_
    python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas ... --anios 2024 2026
    python scripts/ejecutar_sql.py sql/ejercicio_08 --base data/processed/taxis.duckdb

Comportamiento:
  - Los archivos de --vistas se ejecutan primero y en el orden dado. Los
    archivos de la carpeta que empiezan con 00 se ignoran como consultas.
  - Las consultas se ejecutan en orden natural (4_2 antes que 4_10).
  - Con --salida se guarda el resultado de cada consulta en un CSV, que se
    puede comparar entre corridas con --comparar.
  - El codigo de salida es distinto de cero si alguna consulta falla.
"""

import argparse
import re
import sys
import time
from pathlib import Path

import duckdb
import pandas as pd


def orden_natural(ruta: Path):
    """Ordena 4_2_x antes que 4_10_x (los numeros se comparan como numeros)."""
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", ruta.name)]


def main() -> int:
    parser = argparse.ArgumentParser(description="Ejecuta archivos .sql con DuckDB.")
    parser.add_argument("carpeta", type=Path, help="carpeta con las consultas")
    parser.add_argument("--vistas", type=Path, nargs="*", default=[],
                        help="archivos .sql que crean vistas, se ejecutan primero")
    parser.add_argument("--solo", nargs="*", default=None, metavar="PREFIJO",
                        help="ejecutar solo las consultas cuyo nombre empieza con estos prefijos")
    parser.add_argument("--salida", type=Path, default=None,
                        help="carpeta donde guardar el resultado de cada consulta en CSV")
    parser.add_argument("--comparar", type=Path, default=None,
                        help="carpeta con CSV de una corrida anterior para comparar resultados")
    parser.add_argument("--base", type=Path, default=None,
                        help="en lugar de leer los Parquet, usar esta base .duckdb en modo solo lectura "
                             "(por ejemplo data/processed/taxis.duckdb, que ya trae las vistas del tablero)")
    parser.add_argument("--anios", type=int, nargs="+", default=None, metavar="ANIO",
                        help="anios a incluir en las vistas (por defecto, todos los que haya en data/raw)")
    parser.add_argument("--hilos", type=int, default=4,
                        help="hilos de DuckDB (por defecto 4, para no agotar la memoria del contenedor)")
    parser.add_argument("--memoria", default="2GB",
                        help="limite de memoria de DuckDB (por defecto 2GB)")
    parser.add_argument("--silencioso", action="store_true",
                        help="no imprimir las tablas de resultados, solo el resumen")
    argumentos = parser.parse_args()

    pd.set_option("display.width", 250)
    pd.set_option("display.max_columns", 40)

    con = duckdb.connect(str(argumentos.base), read_only=True) if argumentos.base else duckdb.connect()
    # Con 8 hilos y sin limite, los percentiles exactos sobre 28 millones de
    # filas agotaron la memoria del contenedor (unos 5 GB compartidos con Metabase).
    con.execute(f"SET threads = {argumentos.hilos}")
    con.execute(f"SET memory_limit = '{argumentos.memoria}'")
    if argumentos.anios:
        lista = ", ".join(str(a) for a in argumentos.anios)
        con.execute(f"SET VARIABLE anios = [{lista}]")
    for vista in argumentos.vistas:
        con.execute(vista.read_text(encoding="utf-8"))

    archivos = sorted(
        (a for a in argumentos.carpeta.glob("*.sql") if not a.name.startswith("00")),
        key=orden_natural,
    )
    if argumentos.solo is not None:
        archivos = [a for a in archivos if any(a.name.startswith(p) for p in argumentos.solo)]
    if argumentos.salida:
        argumentos.salida.mkdir(parents=True, exist_ok=True)

    fallidas, distintas = [], []
    for archivo in archivos:
        inicio = time.time()
        try:
            resultado = con.sql(archivo.read_text(encoding="utf-8")).df()
        except Exception as error:  # se reporta y se sigue con las demas
            print(f"FALLO  {archivo.name}: {error}")
            fallidas.append(archivo.name)
            continue
        segundos = time.time() - inicio
        print(f"OK     {archivo.name}  ({len(resultado)} filas, {segundos:.1f} s)")
        if not argumentos.silencioso:
            print(resultado.to_string(max_colwidth=45))
            print()
        if argumentos.salida:
            resultado.to_csv(argumentos.salida / (archivo.stem + ".csv"), index=False)
        if argumentos.comparar:
            anterior = argumentos.comparar / (archivo.stem + ".csv")
            if not anterior.exists():
                distintas.append(f"{archivo.name} (sin referencia)")
            else:
                previo = pd.read_csv(anterior)
                actual = pd.read_csv(pd.io.common.StringIO(resultado.to_csv(index=False)))
                if not previo.equals(actual):
                    try:
                        pd.testing.assert_frame_equal(previo, actual, check_dtype=False)
                    except AssertionError:
                        distintas.append(archivo.name)

    print(f"\nConsultas ejecutadas: {len(archivos)}  fallidas: {len(fallidas)}")
    if argumentos.comparar:
        print(f"Distintas a la referencia: {len(distintas)}")
        for nombre in distintas:
            print(f"  {nombre}")
    return 1 if fallidas else 0


if __name__ == "__main__":
    sys.exit(main())
