-- Indicador 11. Propina mediana como porcentaje de la tarifa, pagos con tarjeta.
-- Pregunta: cuanto dejan de propina los pasajeros y cambia con el tiempo? Solo
-- tarjeta (payment_type = 1), porque las propinas en efectivo no se registran.
-- Visualizacion: lineas, una serie por tipo y anio.
SELECT
    mes,
    tipo || ' ' || anio AS serie,
    round(quantile_cont(100.0 * tip_amount / fare_amount, 0.5), 2) AS propina_mediana_pct_tarifa
FROM viajes_limpios
WHERE payment_type = 1 AND fare_amount > 0
GROUP BY tipo, anio, mes
ORDER BY serie, mes;
