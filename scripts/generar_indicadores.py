#!/usr/bin/env python3
"""Genera como PNG los indicadores del tablero (Ejercicio 7).

Ejecuta cada consulta de sql/ejercicio_07/ sobre la base data/processed/taxis.duckdb
(en modo solo lectura) y dibuja la misma grafica que el tablero de Metabase. Sirve
como evidencia del tablero y para comprobar los indicadores sin abrir Metabase.

Requiere haber ejecutado antes scripts/benchmark_parquet_vs_tabla.py y
scripts/preparar_vistas_tablero.py.

Uso (dentro del contenedor lab, desde /workspace):
    python scripts/generar_indicadores.py
    python scripts/generar_indicadores.py --salida docs/img/tablero

Salida: un PNG por indicador y tablero_resumen.png con todos juntos.
"""

import argparse
import re
import sys
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from tablero_indicadores import INDICADORES, RUTA_SQL

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "data" / "processed" / "taxis.duckdb"

COLOR_TIPO = {"yellow": "#c98f00", "green": "#2e8b57"}
ESTILO_ANIO = {"2024": ("--", 0.75), "2025": (":", 0.85), "2026": ("-", 1.0)}
PALETA = ["#4c78a8", "#e45756", "#72b7b2", "#f58518", "#b279a2", "#9d755d", "#54a24b", "#eeca3b"]


def estilo_serie(nombre: str, indice: int):
    """Color por tipo de taxi y trazo por anio cuando la serie es 'tipo anio'."""
    partes = nombre.split()
    if len(partes) == 2 and partes[0] in COLOR_TIPO and partes[1] in ESTILO_ANIO:
        trazo, opacidad = ESTILO_ANIO[partes[1]]
        return COLOR_TIPO[partes[0]], trazo, opacidad
    if len(partes) == 3 and partes[0] in COLOR_TIPO and partes[1:] in (["entre", "semana"], ["fin", "de"]):
        return COLOR_TIPO[partes[0]], "-", 1.0
    if len(partes) == 4 and partes[0] in COLOR_TIPO and partes[1:] == ["fin", "de", "semana"]:
        return COLOR_TIPO[partes[0]], "--", 0.8
    if nombre in COLOR_TIPO:
        return COLOR_TIPO[nombre], "-", 1.0
    if nombre in ESTILO_ANIO:
        trazo, opacidad = ESTILO_ANIO[nombre]
        return "#4c78a8", trazo, opacidad
    return PALETA[indice % len(PALETA)], "-", 1.0


def titulo_de(archivo: str) -> str:
    return next(i["titulo"] for i in INDICADORES if i["archivo"] == archivo)


def dibujar(eje, ind: dict, datos: pd.DataFrame):
    x, serie, y = ind.get("x"), ind.get("serie"), ind["y"]
    eje.set_title(ind["titulo"], fontsize=10, loc="left")
    if ind["display"] == "scalar":
        valor = datos.iloc[0][y]
        eje.text(0.5, 0.5, f"{valor:,.2f}".rstrip("0").rstrip(".") if isinstance(valor, float) else f"{valor:,}",
                 ha="center", va="center", fontsize=26)
        eje.axis("off")
        return
    ancho = datos.pivot_table(index=x, columns=serie, values=y, aggfunc="sum", sort=False)
    if ind["display"] == "line":
        for i, col in enumerate(ancho.columns):
            color, trazo, opacidad = estilo_serie(str(col), i)
            eje.plot(range(len(ancho.index)) if not pd.api.types.is_numeric_dtype(ancho.index) else ancho.index,
                     ancho[col], label=str(col), color=color, linestyle=trazo, alpha=opacidad, linewidth=1.8)
    elif ind["display"] in ("bar", "row"):
        if ind.get("apilado") == "normalized":
            ancho = ancho.div(ancho.sum(axis=1), axis=0) * 100
        horizontal = ind["display"] == "row"
        apilado = ind.get("apilado") is not None
        ancho.plot(kind="barh" if horizontal else "bar", stacked=apilado, ax=eje, legend=False,
                   color=[estilo_serie(str(c), i)[0] for i, c in enumerate(ancho.columns)], width=0.8)
        if horizontal:
            eje.invert_yaxis()
        eje.tick_params(axis="x", rotation=0 if horizontal else 30)
    if ind.get("apilado") == "normalized":
        eje.legend(fontsize=7, frameon=False, loc="upper left", bbox_to_anchor=(1.0, 1.0))
    elif ind["display"] == "line" and ancho.shape[1] > 4:
        # con seis series la leyenda tapa las lineas: va debajo de la grafica
        eje.legend(fontsize=7, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.1), ncol=3)
    else:
        eje.legend(fontsize=7, frameon=False)
    if ind["display"] == "line" and not pd.api.types.is_numeric_dtype(ancho.index) and len(ancho.index) > 8:
        # etiquetas de texto (p. ej. 2025-01): se muestran espaciadas para que no se amontonen
        paso = max(1, len(ancho.index) // 8)
        eje.set_xticks(range(0, len(ancho.index), paso))
        eje.set_xticklabels([str(m) for m in ancho.index[::paso]], rotation=30, ha="right")
    eje.spines[["top", "right"]].set_visible(False)
    eje.grid(axis="y" if ind["display"] != "row" else "x", alpha=0.25)
    eje.set_xlabel("")
    eje.tick_params(labelsize=8)


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera los indicadores del tablero como PNG.")
    parser.add_argument("--salida", type=Path, default=RAIZ / "docs" / "img" / "tablero")
    argumentos = parser.parse_args()
    if not BASE.exists():
        print(f"No existe {BASE}. Ejecute primero el benchmark y preparar_vistas_tablero.py")
        return 1
    argumentos.salida.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(str(BASE), read_only=True)
    con.execute("SET threads = 4")
    con.execute("SET memory_limit = '2GB'")

    resultados = {}
    for ind in INDICADORES:
        sql = (RAIZ / RUTA_SQL / f"{ind['archivo']}.sql").read_text(encoding="utf-8")
        datos = con.execute(sql).df()
        resultados[ind["archivo"]] = datos
        fig, eje = plt.subplots(figsize=(7, 3.4))
        dibujar(eje, ind, datos)
        fig.tight_layout()
        fig.savefig(argumentos.salida / f"{ind['archivo']}.png", dpi=110)
        plt.close(fig)
        print(f"OK  {ind['archivo']}  ({len(datos)} filas)")

    # Resumen: todas las graficas en una sola imagen, con la cuadricula del tablero.
    kpis = [i for i in INDICADORES if i["display"] == "scalar"]
    graficos = [i for i in INDICADORES if i["display"] != "scalar"]
    columnas = 3
    filas = (len(graficos) + columnas - 1) // columnas
    fig = plt.figure(figsize=(18, 3.6 * filas + 1.6))
    cuadricula = fig.add_gridspec(filas + 1, columnas, height_ratios=[0.45] + [1] * filas)
    cabecera = cuadricula[0, :].subgridspec(1, len(kpis))
    for k, ind in enumerate(kpis):
        dibujar(fig.add_subplot(cabecera[0, k]), ind, resultados[ind["archivo"]])
    for k, ind in enumerate(graficos):
        dibujar(fig.add_subplot(cuadricula[1 + k // columnas, k % columnas]), ind, resultados[ind["archivo"]])
    fig.suptitle("Taxis de Nueva York: indicadores (generado con DuckDB desde data/processed/taxis.duckdb)",
                 fontsize=13, x=0.01, ha="left")
    fig.tight_layout(rect=[0, 0, 1, 0.955])
    fig.savefig(argumentos.salida / "tablero_resumen.png", dpi=90)
    plt.close(fig)
    print(f"\nImagenes guardadas en {argumentos.salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
