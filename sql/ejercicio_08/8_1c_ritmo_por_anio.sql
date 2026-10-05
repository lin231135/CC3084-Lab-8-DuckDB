-- 8.5 Evolucion por anio: duracion, velocidad y propina, mismos meses.
-- Objetivo: comparar la mediana de la duracion, de la velocidad y de la propina
-- (como porcentaje de la tarifa, solo pagos con tarjeta) entre 2024, 2025 y 2026,
-- con enero a agosto de cada anio.
-- Fuente: vista viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql).
SELECT
    tipo,
    anio,
    round(quantile_cont(duracion_min, 0.5), 2) AS duracion_mediana_min,
    round(quantile_cont(velocidad_mph, 0.5), 2) AS velocidad_mediana_mph,
    round(quantile_cont(100.0 * tip_amount / fare_amount, 0.5)
          FILTER (WHERE payment_type = 1 AND fare_amount > 0), 2) AS propina_mediana_pct_tarifa
FROM viajes_limpios
WHERE mes <= 8
GROUP BY tipo, anio
ORDER BY tipo, anio;
