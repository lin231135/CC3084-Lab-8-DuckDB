-- P7. En que se parecen y en que se diferencian los viajes amarillos y verdes?
-- Medianas de distancia, duracion y montos, y el comportamiento de propinas
-- solo en viajes pagados con tarjeta (payment_type = 1), porque las propinas
-- en efectivo no se registran.
-- Fuente: vista viajes_limpios (Parquet de 2026).
SELECT
    tipo,
    count(*) AS viajes,
    round(quantile_cont(trip_distance, 0.5), 2) AS mediana_distancia_millas,
    round(quantile_cont(duracion_min, 0.5), 1) AS mediana_duracion_min,
    round(quantile_cont(fare_amount, 0.5), 2) AS mediana_tarifa,
    round(quantile_cont(total_amount, 0.5), 2) AS mediana_total,
    round(100.0 * count(*) FILTER (WHERE payment_type = 1) / count(*), 1) AS pct_pago_tarjeta,
    round(100.0 * count(*) FILTER (WHERE payment_type = 1 AND tip_amount > 0)
          / nullif(count(*) FILTER (WHERE payment_type = 1), 0), 1) AS pct_tarjeta_con_propina,
    round(quantile_cont(100.0 * tip_amount / fare_amount, 0.5)
          FILTER (WHERE payment_type = 1 AND fare_amount > 0), 1) AS mediana_propina_pct_tarifa
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo;
