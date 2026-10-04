-- 5.6 Consulta conjunta: indicadores basicos por anio, mismos meses.
-- Objetivo: comprobar que las consultas de analisis funcionan sobre varios
-- anios a la vez. Como 2026 solo llega hasta agosto, se comparan enero a agosto
-- de cada anio para que los volumenes sean comparables.
-- Se usan los viajes que pasan las reglas de limpieza de 3_7a.
-- Fuente: vista viajes_limpios (requiere sql/ejercicio_04/00_vistas_apoyo.sql).
SELECT
    tipo,
    anio_archivo AS anio,
    count(*) AS viajes_ene_a_ago,
    round(count(*) * 1.0 / count(DISTINCT CAST(pickup AS DATE))) AS viajes_por_dia,
    round(median(trip_distance), 2) AS mediana_millas,
    round(median(duracion_min), 1) AS mediana_min,
    round(median(total_amount), 2) AS mediana_total,
    round(avg(total_amount), 2) AS total_promedio
FROM viajes_limpios
WHERE month(pickup) <= 8
GROUP BY ALL
ORDER BY tipo, anio;
