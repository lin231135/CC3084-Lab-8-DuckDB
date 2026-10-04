-- KPI. Ingreso total pagado por los viajes utiles, en millones de dolares.
-- Visualizacion: numero.
SELECT round(sum(total_amount) / 1e6, 1) AS ingreso_millones_usd FROM viajes_limpios;
