-- 5.7 Los problemas de calidad de 2026, aparecen tambien en 2024?
-- Objetivo: repetir las mediciones principales de 3.6 por anio, para ver si
-- los nulos, las distancias en cero y los montos negativos son estables o son
-- propios de 2026.
-- Fuente: vista viajes (Parquet de todos los anios en data/raw).
SELECT
    tipo,
    anio_archivo AS anio,
    count(*) AS viajes,
    round(100.0 * count(*) FILTER (WHERE passenger_count IS NULL) / count(*), 1) AS pct_pasajeros_nulo,
    round(100.0 * count(*) FILTER (WHERE coalesce(payment_type, 0) = 0) / count(*), 1) AS pct_pago_nulo_o_0,
    round(100.0 * count(*) FILTER (WHERE trip_distance = 0) / count(*), 2) AS pct_distancia_cero,
    round(100.0 * count(*) FILTER (WHERE total_amount < 0) / count(*), 2) AS pct_total_negativo,
    round(100.0 * count(*) FILTER (WHERE epoch(dropoff - pickup) > 6 * 3600) / count(*), 3) AS pct_mas_de_6_horas,
    count(*) FILTER (WHERE pickup < make_date(anio_archivo, 1, 1)
                        OR pickup >= make_date(anio_archivo + 1, 1, 1)) AS pickup_fuera_del_anio,
    count(*) FILTER (WHERE cbd_congestion_fee IS NOT NULL) AS con_cbd_congestion_fee
FROM viajes
GROUP BY ALL
ORDER BY tipo, anio;
