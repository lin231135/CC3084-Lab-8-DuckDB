-- Indicador 5. Total mediano pagado por viaje, por mes, tipo y anio.
-- Pregunta: cuanto paga un pasajero por un viaje tipico y como cambia con el
-- tiempo? Se usa la mediana porque unos pocos viajes muy caros suben el promedio
-- (en 2026 el 8% de los viajes amarillos generaba el 24% del ingreso).
-- Visualizacion: lineas, una serie por tipo y anio.
SELECT
    mes,
    tipo || ' ' || anio AS serie,
    round(quantile_cont(total_amount, 0.5), 2) AS total_mediano
FROM viajes_limpios
GROUP BY tipo, anio, mes
ORDER BY serie, mes;
