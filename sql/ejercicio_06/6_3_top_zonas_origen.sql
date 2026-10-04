-- Benchmark Q3: las 10 zonas de recogida con mas viajes.
-- Mide una agregacion con muchos grupos (265 zonas) y un ordenamiento.
-- El desempate por PULocationID hace el resultado determinista.
SELECT
    PULocationID AS zona,
    count(*) AS viajes,
    round(avg(total_amount), 4) AS total_promedio
FROM src
GROUP BY PULocationID
ORDER BY viajes DESC, zona
LIMIT 10;
