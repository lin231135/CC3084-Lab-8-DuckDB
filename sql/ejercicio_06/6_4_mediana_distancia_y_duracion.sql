-- Benchmark Q4: mediana de distancia y de duracion por tipo.
-- Mide una agregacion pesada en memoria (percentiles exactos), que necesita
-- guardar todos los valores de las columnas que usa.
SELECT
    tipo,
    round(quantile_cont(trip_distance, 0.5), 4) AS mediana_millas,
    round(quantile_cont(epoch(dropoff - pickup) / 60, 0.5), 4) AS mediana_min
FROM src
GROUP BY tipo
ORDER BY tipo;
