"""Catalogo de indicadores del tablero (Ejercicio 7).

Lo usan scripts/montar_tablero_metabase.py (arma el tablero en Metabase) y
scripts/generar_indicadores.py (genera las mismas graficas como PNG). Cada
indicador apunta a un archivo de sql/ejercicio_07/, que es donde vive la consulta.

Campos de cada indicador:
    archivo   nombre del .sql (sin extension)
    titulo    titulo corto que se muestra en el tablero
    display   tipo de grafica: scalar, line, bar o row
    x         columna del eje x (o de las categorias)
    serie     columna que separa series (None si no hay)
    y         columna de la metrica
    apilado   None, "stacked" o "normalized" (100%) para barras
    pos       (fila, columna, ancho, alto) en la cuadricula de 24 columnas de Metabase
"""

RUTA_SQL = "sql/ejercicio_07"

INDICADORES = [
    # fila 0: cifras principales
    dict(archivo="7_13a_kpi_viajes", titulo="Viajes utiles (todos los datos)", display="scalar",
         y="viajes", pos=(0, 0, 6, 3)),
    dict(archivo="7_13b_kpi_ingreso_total", titulo="Ingreso total (millones de USD)", display="scalar",
         y="ingreso_millones_usd", pos=(0, 6, 6, 3)),
    dict(archivo="7_13c_kpi_total_mediano", titulo="Total mediano por viaje, general (USD)", display="scalar",
         y="total_mediano_usd", pos=(0, 12, 6, 3)),
    dict(archivo="7_13d_kpi_pago_con_tarjeta", titulo="Viajes pagados con tarjeta (%)", display="scalar",
         y="pct_tarjeta", pos=(0, 18, 6, 3)),
    # volumen y mezcla de servicios
    dict(archivo="7_01a_viajes_por_dia_amarillos", titulo="Viajes por dia, amarillos", display="line",
         x="mes", serie="serie", y="viajes_por_dia", pos=(3, 0, 12, 7)),
    dict(archivo="7_01b_viajes_por_dia_verdes", titulo="Viajes por dia, verdes", display="line",
         x="mes", serie="serie", y="viajes_por_dia", pos=(3, 12, 12, 7)),
    dict(archivo="7_02_participacion_verdes", titulo="Participacion de los verdes (%)", display="line",
         x="mes", serie="serie", y="pct_verdes", pos=(10, 0, 8, 6)),
    dict(archivo="7_05_total_mediano_por_mes", titulo="Total mediano por viaje (USD)", display="line",
         x="mes", serie="serie", y="total_mediano", pos=(10, 8, 8, 6)),
    dict(archivo="7_10_velocidad_mediana_por_mes", titulo="Velocidad mediana (mph)", display="line",
         x="mes", serie="serie", y="velocidad_mediana_mph", pos=(10, 16, 8, 6)),
    # ritmo de la demanda
    dict(archivo="7_03_demanda_por_hora", titulo="Demanda por hora del dia (% de viajes)", display="line",
         x="hora", serie="serie", y="pct_viajes", pos=(16, 0, 12, 7)),
    dict(archivo="7_04_viajes_por_dia_de_semana", titulo="Viajes por dia de la semana (indice, 100 = promedio)",
         display="bar", x="dia", serie="serie", y="indice_semanal", pos=(16, 12, 12, 7)),
    # pagos y recargos
    dict(archivo="7_06_metodos_de_pago", titulo="Mezcla de metodos de pago (%)", display="bar",
         x="grupo", serie="metodo", y="pct_viajes", apilado="normalized", pos=(23, 0, 8, 7)),
    dict(archivo="7_07_tarifa_flexible_por_mes", titulo="Viajes de tarifa flexible (%)", display="line",
         x="mes", serie="serie", y="pct_tarifa_flexible", pos=(23, 8, 8, 7)),
    dict(archivo="7_11_propina_con_tarjeta", titulo="Propina mediana con tarjeta (% de la tarifa)", display="line",
         x="mes", serie="serie", y="propina_mediana_pct_tarifa", pos=(23, 16, 8, 7)),
    # zonas, congestion y calidad
    dict(archivo="7_08_cargo_congestion_por_mes", titulo="Viajes con cargo de congestion (%)", display="line",
         x="mes", serie="serie", y="pct_viajes_con_cargo", pos=(30, 0, 8, 7)),
    dict(archivo="7_09_top_zonas_origen", titulo="Top 10 zonas de recogida", display="row",
         x="zona", serie="serie", y="viajes", apilado="stacked", pos=(30, 8, 8, 7)),
    dict(archivo="7_12_calidad_viajes_descartados", titulo="Viajes que no pasan las reglas de calidad (%)",
         display="line", x="mes", serie="serie", y="pct_descartados", pos=(30, 16, 8, 7)),
]
