-- KPI. Total mediano pagado por viaje, en dolares.
-- Visualizacion: numero.
SELECT round(quantile_cont(total_amount, 0.5), 2) AS total_mediano_usd FROM viajes_limpios;
