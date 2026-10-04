#!/usr/bin/env python3
"""Crea las vistas del tablero dentro de data/processed/taxis.duckdb.

Metabase se conecta a la base en modo solo lectura y no puede crear objetos,
asi que las vistas viajes_anio y viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql)
se crean aqui, con una conexion de escritura. Requiere que la tabla viajes ya
exista, o sea haber ejecutado antes scripts/benchmark_parquet_vs_tabla.py.

DuckDB admite un solo proceso con permiso de escritura: antes de ejecutar este
script hay que cerrar cualquier conexion abierta a la base, por ejemplo
    docker compose stop metabase

Uso (dentro del contenedor lab, desde /workspace):
    python scripts/preparar_vistas_tablero.py
"""

import sys
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "data" / "processed" / "taxis.duckdb"
VISTAS = RAIZ / "sql" / "ejercicio_07" / "00_vistas_tablero.sql"


def main() -> int:
    if not BASE.exists():
        print(f"No existe {BASE}. Ejecute primero scripts/benchmark_parquet_vs_tabla.py")
        return 1
    con = duckdb.connect(str(BASE))
    if not con.execute("SELECT count(*) FROM information_schema.tables WHERE table_name = 'viajes'").fetchone()[0]:
        print("La base no tiene la tabla viajes. Ejecute primero scripts/benchmark_parquet_vs_tabla.py")
        return 1
    con.execute(VISTAS.read_text(encoding="utf-8"))
    con.execute("CHECKPOINT")
    for vista in ("viajes_anio", "viajes_limpios"):
        filas = con.execute(f"SELECT count(*) FROM {vista}").fetchone()[0]
        print(f"{vista}: {filas:,} filas")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
