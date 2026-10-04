-- Indicador 12. Porcentaje de viajes que no pasan las reglas de calidad, por mes.
-- Pregunta: la calidad de los datos mejora o empeora con el tiempo? Mide los
-- viajes con duracion absurda, distancia en cero o fuera de rango, o total no
-- positivo, sobre los viajes con fecha valida.
-- Visualizacion: lineas, una serie por tipo y anio.
SELECT
    mes,
    tipo || ' ' || anio AS serie,
    round(100.0 * count(*) FILTER (WHERE NOT (
        epoch(dropoff - pickup) BETWEEN 60 AND 6 * 3600
        AND trip_distance > 0 AND trip_distance <= 100
        AND total_amount > 0)) / count(*), 2) AS pct_descartados
FROM viajes_anio
GROUP BY tipo, anio, mes
ORDER BY serie, mes;
