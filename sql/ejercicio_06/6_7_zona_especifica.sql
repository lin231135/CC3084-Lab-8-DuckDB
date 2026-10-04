-- Benchmark Q7: viajes desde una zona concreta (132, el aeropuerto JFK).
-- Mide un filtro de igualdad muy selectivo sobre una columna con pocos valores.
SELECT
    tipo,
    count(*) AS viajes,
    round(avg(fare_amount), 4) AS tarifa_promedio
FROM src
WHERE PULocationID = 132
GROUP BY tipo
ORDER BY tipo;
