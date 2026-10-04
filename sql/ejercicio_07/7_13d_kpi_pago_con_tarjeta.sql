-- KPI. Porcentaje de viajes pagados con tarjeta.
-- Visualizacion: numero.
SELECT round(100.0 * count(*) FILTER (WHERE payment_type = 1) / count(*), 1) AS pct_tarjeta
FROM viajes_anio;
