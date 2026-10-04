-- Indicador 2. Participacion de los taxis verdes en el total de viajes.
-- Pregunta: cuanto pesan los verdes frente a los amarillos y esa proporcion
-- cambia entre anios?
-- Visualizacion: lineas, una serie por anio.
SELECT
    mes,
    CAST(anio AS VARCHAR) AS serie,
    round(100.0 * count(*) FILTER (WHERE tipo = 'green') / count(*), 2) AS pct_verdes
FROM viajes_limpios
GROUP BY anio, mes
ORDER BY anio, mes;
