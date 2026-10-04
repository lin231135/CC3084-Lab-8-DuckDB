-- Indicador 8. Viajes que pagan el cargo de congestion del centro de Manhattan.
-- Pregunta: que tan frecuente es el cargo y como evoluciona? Solo se consideran
-- los meses donde la columna existe (cbd_congestion_fee no esta en los archivos
-- de 2024, el cargo empezo el 5 de enero de 2025 segun el diccionario de la TLC).
-- Visualizacion: lineas, una serie por tipo de taxi.
SELECT
    strftime(make_date(anio, mes, 1), '%Y-%m') AS mes,
    tipo AS serie,
    round(100.0 * count(*) FILTER (WHERE cbd_congestion_fee > 0) / count(*), 2) AS pct_viajes_con_cargo
FROM viajes_limpios
WHERE cbd_congestion_fee IS NOT NULL
GROUP BY tipo, anio, mes
ORDER BY mes, serie;
