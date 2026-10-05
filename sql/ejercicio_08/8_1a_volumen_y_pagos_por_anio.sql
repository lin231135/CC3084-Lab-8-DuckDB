-- 8.5 Evolucion por anio: volumen, pagos y cargos, mismos meses.
-- Objetivo: comparar 2024, 2025 y 2026 con la misma ventana de meses. 2026 solo
-- llega hasta agosto, asi que solo se consideran enero a agosto de cada anio.
-- Son conteos y proporciones, no necesitan guardar valores en memoria.
-- Fuente: vistas viajes_anio y viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql)
-- sobre la tabla materializada data/processed/taxis.duckdb.
WITH limpios AS (
    SELECT
        tipo, anio,
        count(*) AS viajes_utiles,
        round(count(*) * 1.0 / count(DISTINCT fecha)) AS viajes_por_dia,
        round(100.0 * count(*) FILTER (WHERE cbd_congestion_fee > 0)
              / nullif(count(*) FILTER (WHERE cbd_congestion_fee IS NOT NULL), 0), 1) AS pct_con_cargo_congestion
    FROM viajes_limpios
    WHERE mes <= 8
    GROUP BY tipo, anio
),
todos AS (
    SELECT
        tipo, anio,
        count(*) AS viajes_con_fecha_valida,
        round(100.0 * count(*) FILTER (WHERE coalesce(payment_type, 0) = 0) / count(*), 1) AS pct_tarifa_flexible,
        round(100.0 * count(*) FILTER (WHERE payment_type = 1) / count(*), 1) AS pct_tarjeta,
        round(100.0 * count(*) FILTER (WHERE payment_type = 2) / count(*), 1) AS pct_efectivo,
        round(100.0 * count(*) FILTER (WHERE NOT (
            epoch(dropoff - pickup) BETWEEN 60 AND 6 * 3600
            AND trip_distance > 0 AND trip_distance <= 100
            AND total_amount > 0)) / count(*), 2) AS pct_descartados
    FROM viajes_anio
    WHERE mes <= 8
    GROUP BY tipo, anio
)
SELECT
    t.tipo, t.anio, t.viajes_con_fecha_valida, l.viajes_utiles, l.viajes_por_dia,
    t.pct_tarifa_flexible, t.pct_tarjeta, t.pct_efectivo,
    l.pct_con_cargo_congestion, t.pct_descartados
FROM todos t
JOIN limpios l USING (tipo, anio)
ORDER BY t.tipo, t.anio;
