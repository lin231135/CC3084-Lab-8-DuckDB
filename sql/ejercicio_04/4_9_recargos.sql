-- P9. Que tan frecuentes son los recargos (congestion, aeropuerto) y cuanto suman?
-- cbd_congestion_fee es el cargo de la zona de congestion de Manhattan, y
-- Airport_fee solo existe en amarillos. Se muestra la proporcion de viajes que
-- lo pagan y el monto promedio cuando se cobra.
-- Fuente: vista viajes_limpios (Parquet de 2026).
SELECT
    tipo,
    strftime(pickup, '%Y-%m') AS mes,
    count(*) AS viajes,
    round(100.0 * count(*) FILTER (WHERE cbd_congestion_fee > 0) / count(*), 1) AS pct_cbd,
    round(avg(cbd_congestion_fee) FILTER (WHERE cbd_congestion_fee > 0), 2) AS cbd_promedio,
    round(100.0 * count(*) FILTER (WHERE congestion_surcharge > 0) / count(*), 1) AS pct_congestion_surcharge,
    round(100.0 * count(*) FILTER (WHERE Airport_fee > 0) / count(*), 1) AS pct_airport_fee
FROM viajes_limpios
GROUP BY ALL
ORDER BY tipo, mes;
