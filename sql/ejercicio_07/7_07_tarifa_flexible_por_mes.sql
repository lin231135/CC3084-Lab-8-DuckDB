-- Indicador 7. Porcentaje de viajes de tarifa flexible (Flex Fare), por mes.
-- Pregunta: que tan importante es la tarifa flexible y crece con el tiempo?
-- Son los viajes sin numero de pasajeros ni propina registrada, que se
-- comportan distinto al resto (ver docs/ejercicio_03.md y docs/ejercicio_04.md).
-- Visualizacion: lineas, una serie por tipo y anio.
SELECT
    mes,
    tipo || ' ' || anio AS serie,
    round(100.0 * count(*) FILTER (WHERE coalesce(payment_type, 0) = 0) / count(*), 2) AS pct_tarifa_flexible
FROM viajes_anio
GROUP BY tipo, anio, mes
ORDER BY serie, mes;
