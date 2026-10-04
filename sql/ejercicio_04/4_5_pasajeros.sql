-- P5. Cuantas personas viajan normalmente en un taxi?
-- Se excluyen los viajes sin dato de pasajeros (nulos), que en la exploracion
-- inicial resultaron ser el 26% de los amarillos y el 14% de los verdes.
-- pct es sobre los viajes que si tienen el dato.
-- Fuente: vista viajes_limpios (Parquet de 2026).
WITH por_pasajeros AS (
    SELECT tipo, passenger_count AS pasajeros, count(*) AS viajes
    FROM viajes_limpios
    WHERE passenger_count IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    tipo, pasajeros, viajes,
    round(100.0 * viajes / sum(viajes) OVER (PARTITION BY tipo), 2) AS pct
FROM por_pasajeros
ORDER BY tipo, pasajeros;
