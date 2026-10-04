-- Benchmark Q5: viajes largos pagados con tarjeta, con su propina promedio.
-- Mide un filtro selectivo sobre dos columnas (payment_type y trip_distance).
SELECT
    tipo,
    count(*) AS viajes,
    round(avg(tip_amount), 4) AS propina_promedio
FROM src
WHERE payment_type = 1 AND trip_distance > 10
GROUP BY tipo
ORDER BY tipo;
