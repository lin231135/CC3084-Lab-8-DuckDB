-- Benchmark Q2: viajes y total promedio por tipo y hora de recogida.
-- Mide una agregacion con una columna derivada (hour) y un promedio.
SELECT
    tipo,
    hour(pickup) AS hora,
    count(*) AS viajes,
    round(avg(total_amount), 4) AS total_promedio
FROM src
GROUP BY tipo, hora
ORDER BY tipo, hora;
