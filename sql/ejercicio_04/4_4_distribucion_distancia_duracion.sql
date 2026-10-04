-- P4. Como se distribuyen la distancia, la duracion y la velocidad de los viajes?
-- Se reportan promedio y percentiles para ver si la media representa bien al
-- viaje tipico o la arrastra la cola larga. Los percentiles se piden como una
-- lista en una sola llamada, porque una llamada por percentil guarda una copia
-- de los 28 millones de valores y agota la memoria del contenedor.
-- Fuente: vista viajes_limpios (Parquet de 2026).
WITH medidas AS (
    SELECT tipo, 'distancia_millas' AS variable, trip_distance AS valor FROM viajes_limpios
    UNION ALL
    SELECT tipo, 'duracion_min', duracion_min FROM viajes_limpios
    UNION ALL
    SELECT tipo, 'velocidad_mph', velocidad_mph FROM viajes_limpios
),
resumen AS (
    SELECT
        tipo, variable,
        avg(valor) AS promedio,
        quantile_cont(valor, [0.10, 0.25, 0.50, 0.75, 0.90, 0.99]) AS p,
        max(valor) AS maximo
    FROM medidas
    GROUP BY tipo, variable
)
SELECT
    tipo, variable,
    round(promedio, 2) AS promedio,
    round(p[1], 2) AS p10,
    round(p[2], 2) AS p25,
    round(p[3], 2) AS mediana,
    round(p[4], 2) AS p75,
    round(p[5], 2) AS p90,
    round(p[6], 2) AS p99,
    round(maximo, 2) AS maximo
FROM resumen
ORDER BY tipo, variable;
