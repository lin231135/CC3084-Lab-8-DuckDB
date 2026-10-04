-- Indicador 1b. Viajes por dia de los taxis verdes, por mes y anio.
-- Misma pregunta que 1a, en grafica aparte por la diferencia de escala.
-- Visualizacion: lineas, una serie por anio.
SELECT
    mes,
    CAST(anio AS VARCHAR) AS serie,
    round(count(*) * 1.0 / count(DISTINCT fecha)) AS viajes_por_dia
FROM viajes_limpios
WHERE tipo = 'green'
GROUP BY anio, mes
ORDER BY anio, mes;
