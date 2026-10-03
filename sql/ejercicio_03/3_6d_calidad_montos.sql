-- 3.6 Calidad: montos de la tarifa y del total.
-- Objetivo: contar montos negativos, en cero y extremos, y ver cuanto pesan.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) FILTER (WHERE fare_amount < 0) AS tarifa_negativa,
    count(*) FILTER (WHERE fare_amount = 0) AS tarifa_cero,
    count(*) FILTER (WHERE total_amount < 0) AS total_negativo,
    count(*) FILTER (WHERE total_amount > 500) AS total_mayor_a_500,
    min(total_amount) AS total_minimo,
    max(total_amount) AS total_maximo,
    round(avg(total_amount), 2) AS total_promedio
FROM viajes
GROUP BY tipo
ORDER BY tipo;
