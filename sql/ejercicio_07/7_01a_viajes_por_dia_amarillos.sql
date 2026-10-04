-- Indicador 1a. Viajes por dia de los taxis amarillos, por mes y anio.
-- Pregunta: como evoluciona el volumen de viajes y como se comparan los mismos
-- meses entre anios? Se usa el promedio por dia y no el total, porque los meses
-- tienen distinta cantidad de dias. Amarillos y verdes van en graficas
-- separadas porque su escala es muy distinta (unos 110 mil contra 1,300 por dia).
-- Visualizacion: lineas, una serie por anio.
SELECT
    mes,
    CAST(anio AS VARCHAR) AS serie,
    round(count(*) * 1.0 / count(DISTINCT fecha)) AS viajes_por_dia
FROM viajes_limpios
WHERE tipo = 'yellow'
GROUP BY anio, mes
ORDER BY anio, mes;
