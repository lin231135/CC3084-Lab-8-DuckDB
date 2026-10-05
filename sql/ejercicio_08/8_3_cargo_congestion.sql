-- 8.6 El cargo de congestion del centro de Manhattan, mes a mes desde que existe.
-- Objetivo: ver cuando aparece cbd_congestion_fee, que proporcion de viajes lo
-- paga y de cuanto es. En 2024 la columna no existe (nulo), asi que solo se
-- listan los meses con la columna presente. Un viaje cuenta como "con cargo" si
-- el valor es mayor a cero.
-- Fuente: vista viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql).
SELECT
    tipo,
    strftime(make_date(anio, mes, 1), '%Y-%m') AS mes,
    count(*) AS viajes,
    round(100.0 * count(*) FILTER (WHERE cbd_congestion_fee > 0) / count(*), 1) AS pct_con_cargo,
    round(avg(cbd_congestion_fee) FILTER (WHERE cbd_congestion_fee > 0), 2) AS cargo_promedio,
    round(max(cbd_congestion_fee), 2) AS cargo_maximo
FROM viajes_limpios
WHERE cbd_congestion_fee IS NOT NULL
GROUP BY tipo, anio, mes
ORDER BY tipo, mes;
