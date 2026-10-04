-- P2 (resumen). Las tres horas con mas viajes por tipo de taxi y tipo de dia.
-- Fuente: vista viajes_limpios (Parquet de 2026).
WITH por_hora AS (
    SELECT
        tipo,
        CASE WHEN dia_semana >= 6 THEN 'fin de semana' ELSE 'entre semana' END AS tipo_dia,
        hora,
        count(*) AS viajes
    FROM viajes_limpios
    GROUP BY ALL
)
SELECT
    tipo, tipo_dia, hora, viajes,
    round(100.0 * viajes / sum(viajes) OVER (PARTITION BY tipo, tipo_dia), 2) AS pct,
    row_number() OVER (PARTITION BY tipo, tipo_dia ORDER BY viajes DESC) AS posicion
FROM por_hora
QUALIFY posicion <= 3
ORDER BY tipo, tipo_dia, posicion;
