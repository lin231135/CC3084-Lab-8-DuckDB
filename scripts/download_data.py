#!/usr/bin/env python3
"""Descarga los archivos Parquet del NYC TLC Trip Record Data.

Descarga los registros de viajes de taxis amarillos (yellow) y verdes (green)
de los anios indicados. Por defecto descarga solo 2026, que es el conjunto de
datos inicial del laboratorio.

Fuente oficial de los datos:
    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Uso:
    python scripts/download_data.py                        # amarillos y verdes de 2026
    python scripts/download_data.py --taxi yellow
    python scripts/download_data.py --years 2024 2026
    python scripts/download_data.py --years 2024 2025 2026 --taxi green
    python scripts/download_data.py --verify-only          # solo verifica, no descarga

Los archivos se guardan en:
    data/raw/<tipo>/<anio>/<nombre-original>.parquet

Comportamiento:
  - La TLC publica cada mes con varias semanas de atraso, por lo que no todos
    los meses del anio en curso existen todavia. El script consulta al
    servidor (peticion HEAD) que meses estan publicados en lugar de
    suponerlos. Un 403 o 404 significa "no publicado"; cualquier otro error
    de red se reporta como fallo y no se confunde con un mes inexistente.
  - Un archivo local solo se considera bueno si su tamano coincide con el
    Content-Length del servidor y su pie de pagina Parquet se puede leer.
    Si no cumple, se vuelve a descargar. Un archivo bueno no se toca.
  - La descarga se hace sobre un nombre temporal (.part) y solo se renombra al
    terminar, despues de comprobar el tamano recibido, de modo que una
    interrupcion no deja archivos .parquet a medias.
  - Tambien se descarga una vez la tabla de zonas de la TLC
    (data/raw/zonas/taxi_zone_lookup.csv), que sirve para nombrar las zonas.
  - Al final se imprime una verificacion de completitud: meses esperados
    (los publicados) contra meses presentes y legibles en disco.
"""

import argparse
import sys
from pathlib import Path

import pyarrow.parquet as pq
import requests

ANIO_POR_DEFECTO = 2026
TIPOS_TAXI = ("yellow", "green")
URL_BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data"
DIR_DESTINO = Path("data/raw")
URL_ZONAS = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
RUTA_ZONAS = DIR_DESTINO / "zonas" / "taxi_zone_lookup.csv"

TIEMPO_ESPERA = 60          # segundos por peticion
INTENTOS = 3                # intentos por archivo antes de darse por vencido
BLOQUE = 1024 * 1024        # 1 MiB por bloque de descarga
SUFIJO_TEMPORAL = ".part"
CODIGOS_NO_PUBLICADO = (403, 404)


def construir_nombre(tipo: str, anio: int, mes: int) -> str:
    """Nombre del archivo publicado por la TLC, p. ej. yellow_tripdata_2026-01.parquet."""
    return f"{tipo}_tripdata_{anio}-{mes:02d}.parquet"


def construir_url(tipo: str, anio: int, mes: int) -> str:
    """URL completa del archivo Parquet mensual."""
    return f"{URL_BASE}/{construir_nombre(tipo, anio, mes)}"


def ruta_destino(tipo: str, anio: int, mes: int) -> Path:
    """Ruta local donde se guarda el archivo."""
    return DIR_DESTINO / tipo / str(anio) / construir_nombre(tipo, anio, mes)


def consultar_servidor(url: str):
    """Pregunta al servidor por el archivo sin descargarlo.

    Devuelve el tamano publicado en bytes si existe, None si la TLC aun no lo
    publica. Lanza requests.RequestException ante cualquier otro problema.
    """
    respuesta = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
    if respuesta.status_code in CODIGOS_NO_PUBLICADO:
        return None
    respuesta.raise_for_status()
    longitud = respuesta.headers.get("Content-Length")
    return int(longitud) if longitud is not None else -1


def parquet_legible(ruta: Path) -> bool:
    """Indica si el pie de pagina del Parquet se puede leer (archivo no truncado)."""
    try:
        pq.ParquetFile(ruta).metadata
    except Exception:
        return False
    return True


def archivo_bueno(ruta: Path, tamano_servidor: int) -> bool:
    """El archivo existe, tiene el tamano publicado y es un Parquet legible."""
    if not ruta.exists() or ruta.stat().st_size == 0:
        return False
    if tamano_servidor >= 0 and ruta.stat().st_size != tamano_servidor:
        return False
    return parquet_legible(ruta)


def formato_tamanio(n: float) -> str:
    for unidad in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unidad == "GiB":
            return f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n:.1f} GiB"


def descargar_archivo(url: str, destino: Path, tamano_esperado: int) -> int:
    """Descarga `url` en `destino`. Devuelve la cantidad de bytes escritos."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporal = destino.with_name(destino.name + SUFIJO_TEMPORAL)

    ultimo_error = None
    for intento in range(1, INTENTOS + 1):
        try:
            with requests.get(url, stream=True, timeout=TIEMPO_ESPERA) as respuesta:
                respuesta.raise_for_status()
                escritos = 0
                with temporal.open("wb") as archivo:
                    for bloque in respuesta.iter_content(chunk_size=BLOQUE):
                        if bloque:
                            archivo.write(bloque)
                            escritos += len(bloque)
            if escritos == 0:
                raise requests.RequestException("el servidor devolvio un archivo vacio")
            if tamano_esperado >= 0 and escritos != tamano_esperado:
                raise requests.RequestException(
                    f"tamano recibido {escritos} distinto del publicado {tamano_esperado}"
                )
            if not parquet_legible(temporal):
                raise requests.RequestException("el archivo descargado no es un Parquet legible")
            temporal.replace(destino)
            return escritos
        except requests.RequestException as error:
            ultimo_error = error
            temporal.unlink(missing_ok=True)
            if intento < INTENTOS:
                print(f"      intento {intento}/{INTENTOS} fallido ({error}); reintentando")

    raise requests.RequestException(f"no se pudo descargar {url}: {ultimo_error}")


def descargar_zonas(verificar_solo: bool) -> bool:
    """Descarga la tabla de zonas de la TLC (LocationID a nombre de zona).

    Es un CSV pequeno y fijo, no depende del anio. Si ya existe y no esta
    vacio no se vuelve a descargar. Devuelve True si queda disponible.
    """
    print("\n=== ZONAS (taxi_zone_lookup.csv) ===")
    if RUTA_ZONAS.exists() and RUTA_ZONAS.stat().st_size > 0:
        print("  ya existe, se omite")
        return True
    if verificar_solo:
        print("  FALTA (modo --verify-only)")
        return False
    RUTA_ZONAS.parent.mkdir(parents=True, exist_ok=True)
    try:
        respuesta = requests.get(URL_ZONAS, timeout=TIEMPO_ESPERA)
        respuesta.raise_for_status()
    except requests.RequestException as error:
        print(f"  ERROR: {error}")
        return False
    if not respuesta.content:
        print("  ERROR: el servidor devolvio un archivo vacio")
        return False
    RUTA_ZONAS.write_bytes(respuesta.content)
    print(f"  listo ({formato_tamanio(len(respuesta.content))}) -> {RUTA_ZONAS}")
    return True


def procesar(tipo: str, anio: int, verificar_solo: bool) -> dict:
    """Descarga (o verifica) todos los meses publicados de un tipo y anio."""
    print(f"\n=== {tipo.upper()} {anio} ===")
    resumen = {
        "descargados": 0, "omitidos": 0, "redescargados": 0,
        "publicados": [], "no_publicados": [], "fallidos": [],
    }

    for mes in range(1, 13):
        etiqueta = f"{anio}-{mes:02d}"
        destino = ruta_destino(tipo, anio, mes)
        url = construir_url(tipo, anio, mes)

        try:
            tamano = consultar_servidor(url)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR consultando al servidor: {error}")
            resumen["fallidos"].append(etiqueta)
            continue

        if tamano is None:
            print(f"  {etiqueta}  aun no publicado por la TLC")
            resumen["no_publicados"].append(etiqueta)
            continue
        resumen["publicados"].append(etiqueta)

        if archivo_bueno(destino, tamano):
            print(f"  {etiqueta}  ya existe y es valido, se omite")
            resumen["omitidos"] += 1
            continue

        if verificar_solo:
            print(f"  {etiqueta}  FALTA o esta incompleto (modo --verify-only)")
            resumen["fallidos"].append(etiqueta)
            continue

        existia = destino.exists()
        if existia:
            print(f"  {etiqueta}  existe pero no coincide con el servidor, se vuelve a descargar")
        else:
            print(f"  {etiqueta}  descargando...")
        try:
            escritos = descargar_archivo(url, destino, tamano)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR: {error}")
            resumen["fallidos"].append(etiqueta)
        else:
            print(f"  {etiqueta}  listo ({formato_tamanio(escritos)}) -> {destino}")
            resumen["redescargados" if existia else "descargados"] += 1

    return resumen


def verificar_completitud(tipos, anios) -> bool:
    """Compara los meses publicados contra los archivos legibles en disco."""
    print("\n" + "=" * 60)
    print("VERIFICACION DE COMPLETITUD (publicados contra legibles en disco)")
    print("=" * 60)
    completo = True
    for tipo in tipos:
        for anio in anios:
            esperados = 0
            legibles = 0
            for mes in range(1, 13):
                try:
                    tamano = consultar_servidor(construir_url(tipo, anio, mes))
                except requests.RequestException:
                    completo = False
                    continue
                if tamano is None:
                    continue
                esperados += 1
                if archivo_bueno(ruta_destino(tipo, anio, mes), tamano):
                    legibles += 1
            marca = "OK" if esperados == legibles else "INCOMPLETO"
            if esperados != legibles:
                completo = False
            print(f"  {tipo:<6} {anio}: esperados {esperados:>2}  legibles {legibles:>2}  {marca}")
    print("=" * 60)
    return completo


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Descarga los datos de taxis amarillos y verdes del NYC TLC."
    )
    parser.add_argument(
        "--taxi", choices=(*TIPOS_TAXI, "all"), default="all",
        help="tipo de taxi a descargar (por defecto: all)",
    )
    parser.add_argument(
        "--years", type=int, nargs="+", default=[ANIO_POR_DEFECTO], metavar="ANIO",
        help=f"anios a descargar (por defecto: {ANIO_POR_DEFECTO})",
    )
    parser.add_argument(
        "--verify-only", action="store_true",
        help="solo verifica los archivos locales contra el servidor, sin descargar",
    )
    argumentos = parser.parse_args()

    tipos = TIPOS_TAXI if argumentos.taxi == "all" else (argumentos.taxi,)
    anios = sorted(set(argumentos.years))

    zonas_ok = descargar_zonas(argumentos.verify_only)

    total = {"descargados": 0, "omitidos": 0, "redescargados": 0, "no_publicados": [], "fallidos": []}
    for tipo in tipos:
        for anio in anios:
            resumen = procesar(tipo, anio, argumentos.verify_only)
            for clave in ("descargados", "omitidos", "redescargados"):
                total[clave] += resumen[clave]
            total["no_publicados"] += [f"{tipo} {m}" for m in resumen["no_publicados"]]
            total["fallidos"] += [f"{tipo} {m}" for m in resumen["fallidos"]]

    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    print(f"  descargados     : {total['descargados']}")
    print(f"  redescargados   : {total['redescargados']}")
    print(f"  ya existian     : {total['omitidos']}")
    print(f"  no publicados   : {len(total['no_publicados'])}")
    if total["no_publicados"]:
        print(f"      {', '.join(total['no_publicados'])}")
    print(f"  fallidos        : {len(total['fallidos'])}")
    if total["fallidos"]:
        print(f"      {', '.join(total['fallidos'])}")
    print("=" * 60)

    completo = verificar_completitud(tipos, anios)
    return 0 if completo and zonas_ok and not total["fallidos"] else 1


if __name__ == "__main__":
    sys.exit(main())
