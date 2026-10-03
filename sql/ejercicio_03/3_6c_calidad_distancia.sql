-- 3.6 Calidad: distancia de los viajes.
-- Objetivo: contar distancias en cero, negativas y absurdamente grandes.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) FILTER (WHERE trip_distance < 0) AS distancia_negativa,
    count(*) FILTER (WHERE trip_distance = 0) AS distancia_cero,
    count(*) FILTER (WHERE trip_distance > 100) AS mayor_a_100_millas,
    count(*) FILTER (WHERE trip_distance > 1000) AS mayor_a_1000_millas,
    max(trip_distance) AS distancia_maxima,
    round(quantile_cont(trip_distance, 0.50) FILTER (WHERE trip_distance > 0), 2) AS mediana_millas
FROM viajes
GROUP BY tipo
ORDER BY tipo;
