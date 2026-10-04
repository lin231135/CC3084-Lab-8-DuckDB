#!/usr/bin/env python3
"""Arma el tablero del Ejercicio 7 en Metabase usando su API.

Hace lo siguiente, y se puede volver a ejecutar sin duplicar nada:
  1. Si Metabase es nuevo, completa la configuracion inicial y crea el usuario
     administrador local del laboratorio.
  2. Registra la base data/processed/taxis.duckdb como fuente de datos, en modo
     solo lectura y con la ruta de dentro del contenedor (/workspace/data/...).
  3. Crea una pregunta (card) de SQL nativo por cada indicador de
     scripts/tablero_indicadores.py, leyendo la consulta de sql/ejercicio_07/.
  4. Crea el tablero y acomoda las preguntas.

Requisitos: el ambiente levantado (docker compose up), la base ya construida con
scripts/benchmark_parquet_vs_tabla.py y con las vistas de
scripts/preparar_vistas_tablero.py. Metabase abre la base en solo lectura, asi que
no puede haber un proceso escribiendo en ella al mismo tiempo.

Uso (dentro del contenedor lab, desde /workspace):
    python scripts/montar_tablero_metabase.py
    python scripts/montar_tablero_metabase.py --url http://metabase:3000

Las credenciales son locales al laboratorio (ver README) y solo sirven para este
Metabase, que escucha unicamente en 127.0.0.1.
"""

import argparse
import re
import sys
import time
from pathlib import Path

import requests

from tablero_indicadores import INDICADORES, RUTA_SQL

RAIZ = Path(__file__).resolve().parent.parent
USUARIO = "lab8@example.com"
CLAVE = "Taxis-NYC-Lab8-2026"
NOMBRE_BASE = "Taxis NYC (DuckDB)"
NOMBRE_COLECCION = "Lab 8 DuckDB"
NOMBRE_TABLERO = "Taxis de Nueva York: indicadores"
ARCHIVO_DUCKDB = "/workspace/data/processed/taxis.duckdb"


class Metabase:
    def __init__(self, url: str):
        self.url = url.rstrip("/")
        self.http = requests.Session()

    def pedir(self, metodo: str, ruta: str, **kwargs):
        respuesta = self.http.request(metodo, f"{self.url}{ruta}", timeout=180, **kwargs)
        if not respuesta.ok:
            raise RuntimeError(f"{metodo} {ruta} -> {respuesta.status_code}: {respuesta.text[:400]}")
        return respuesta.json() if respuesta.content else None

    def esperar(self, segundos: int = 240):
        limite = time.time() + segundos
        while time.time() < limite:
            try:
                if self.http.get(f"{self.url}/api/health", timeout=5).json().get("status") == "ok":
                    return
            except requests.RequestException:
                pass
            time.sleep(3)
        raise SystemExit("Metabase no respondio a tiempo")

    def iniciar_sesion(self):
        propiedades = self.pedir("GET", "/api/session/properties")
        token = propiedades.get("setup-token")
        if token:
            print("Metabase nuevo: completando la configuracion inicial...")
            sesion = self.pedir("POST", "/api/setup", json={
                "token": token,
                "user": {"first_name": "Lab8", "last_name": "Equipo", "email": USUARIO,
                         "password": CLAVE, "site_name": "Lab 8 DuckDB"},
                "prefs": {"site_name": "Lab 8 DuckDB", "site_locale": "es", "allow_tracking": False},
            })
            self.http.headers["X-Metabase-Session"] = sesion["id"]
        else:
            sesion = self.pedir("POST", "/api/session", json={"username": USUARIO, "password": CLAVE})
            self.http.headers["X-Metabase-Session"] = sesion["id"]


def leer_sql(archivo: str):
    """Devuelve (consulta, titulo, descripcion) de un archivo de sql/ejercicio_07."""
    texto = (RAIZ / RUTA_SQL / f"{archivo}.sql").read_text(encoding="utf-8")
    comentarios = [l[2:].strip() for l in texto.splitlines() if l.startswith("--")]
    consulta = "\n".join(l for l in texto.splitlines() if not l.startswith("--")).strip().rstrip(";")
    descripcion = " ".join(comentarios)
    return consulta, descripcion


def configuracion_visual(ind: dict) -> dict:
    if ind["display"] == "scalar":
        return {}
    ajustes = {"graph.dimensions": [ind["x"]] + ([ind["serie"]] if ind.get("serie") else []),
               "graph.metrics": [ind["y"]]}
    if ind["display"] == "line":
        ajustes["graph.x_axis.scale"] = "ordinal"
    if ind.get("apilado"):
        ajustes["stackable.stack_type"] = ind["apilado"]
    return ajustes


def main() -> int:
    parser = argparse.ArgumentParser(description="Arma el tablero del Ejercicio 7 en Metabase.")
    parser.add_argument("--url", default="http://metabase:3000",
                        help="URL de Metabase vista desde donde corre el script (http://metabase:3000 en el contenedor lab)")
    argumentos = parser.parse_args()

    mb = Metabase(argumentos.url)
    mb.esperar()
    mb.iniciar_sesion()

    # Base de datos
    bases = mb.pedir("GET", "/api/database")
    lista = bases["data"] if isinstance(bases, dict) else bases
    base = next((b for b in lista if b["name"] == NOMBRE_BASE), None)
    if base is None:
        print("Registrando la base DuckDB (solo lectura)...")
        base = mb.pedir("POST", "/api/database", json={
            "engine": "duckdb", "name": NOMBRE_BASE, "is_full_sync": True, "auto_run_queries": True,
            "details": {"database_file": ARCHIVO_DUCKDB, "read_only": True, "memory_limit": "1GB",
                        "old_implicit_casting": True},
        })
    id_base = base["id"]
    mb.pedir("POST", f"/api/database/{id_base}/sync_schema")
    for _ in range(40):
        tablas = [t["name"] for t in mb.pedir("GET", f"/api/database/{id_base}/metadata").get("tables", [])]
        if {"viajes", "viajes_limpios"} <= set(tablas):
            break
        time.sleep(3)
    print(f"Tablas visibles en Metabase: {sorted(tablas)}")

    # Coleccion
    colecciones = mb.pedir("GET", "/api/collection")
    coleccion = next((c for c in colecciones if c.get("name") == NOMBRE_COLECCION), None)
    if coleccion is None:
        # En un Metabase recien instalado la secuencia de ids de la tabla de permisos puede
        # quedar desfasada y los primeros intentos fallan con un 500 (cada intento consume
        # un id). Reintentar unas veces lo resuelve; si no, se usa la coleccion raiz.
        for intento in range(1, 13):
            try:
                coleccion = mb.pedir("POST", "/api/collection", json={"name": NOMBRE_COLECCION})
                break
            except RuntimeError as error:
                print(f"  intento {intento} de crear la coleccion fallo ({str(error)[:60]}...)")
        else:
            print("  no se pudo crear la coleccion; se usa la raiz de Metabase")
    id_coleccion = coleccion["id"] if coleccion else None

    # Preguntas (cards)
    existentes = {c["name"]: c for c in mb.pedir("GET", "/api/card") if c.get("collection_id") == id_coleccion}
    ids = {}
    for ind in INDICADORES:
        consulta, descripcion = leer_sql(ind["archivo"])
        cuerpo = {
            "name": ind["titulo"], "description": descripcion[:1000], "collection_id": id_coleccion,
            "display": ind["display"], "visualization_settings": configuracion_visual(ind),
            "dataset_query": {"type": "native", "database": id_base, "native": {"query": consulta}},
        }
        if ind["titulo"] in existentes and existentes[ind["titulo"]]["id"] not in ids.values():
            tarjeta = mb.pedir("PUT", f"/api/card/{existentes[ind['titulo']]['id']}", json=cuerpo)
            accion = "actualizada"
        else:
            tarjeta = mb.pedir("POST", "/api/card", json=cuerpo)
            accion = "creada"
        ids[ind["archivo"]] = tarjeta["id"]
        print(f"  pregunta {accion}: {ind['titulo']}")

    # Tablero
    tableros = mb.pedir("GET", "/api/dashboard")
    tablero = next((d for d in tableros if d["name"] == NOMBRE_TABLERO and d.get("collection_id") == id_coleccion), None)
    if tablero is None:
        tablero = mb.pedir("POST", "/api/dashboard", json={
            "name": NOMBRE_TABLERO, "collection_id": id_coleccion,
            "description": "Indicadores de los viajes de taxi de Nueva York, calculados con DuckDB sobre la tabla "
                           "materializada. Cada pregunta guarda su consulta SQL (ver sql/ejercicio_07 en el repositorio)."})
    dashcards = []
    for n, ind in enumerate(INDICADORES, 1):
        fila, col, ancho, alto = ind["pos"]
        dashcards.append({"id": -n, "card_id": ids[ind["archivo"]], "row": fila, "col": col,
                          "size_x": ancho, "size_y": alto, "parameter_mappings": [], "series": [],
                          "visualization_settings": {}})
    mb.pedir("PUT", f"/api/dashboard/{tablero['id']}", json={"dashcards": dashcards})
    print(f"\nTablero listo: {argumentos.url}/dashboard/{tablero['id']}")
    print("Desde el navegador del equipo: http://127.0.0.1:3000  (usuario y clave en el README)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
