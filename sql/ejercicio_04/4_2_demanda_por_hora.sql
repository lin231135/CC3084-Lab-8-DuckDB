-- P2. A que horas se concentra la demanda y cambia entre semana y fin de semana?
-- pct es el porcentaje de los viajes de ese tipo y tipo de dia que ocurre en
-- esa hora, para poder comparar curvas de volumen muy distinto.
-- Fuente: vista viajes_limpios (Parquet de 2026).
WITH por_hora AS (
    SELECT
        tipo,
        CASE WHEN dia_semana >= 6 THEN 'fin de semana' ELSE 'entre semana' END AS tipo_dia,
        hora,
        count(*) AS viajes
    FROM viajes_limpios
    GROUP BY 1, 2, 3
)
SELECT
    tipo, tipo_dia, hora, viajes,
    round(100.0 * viajes / sum(viajes) OVER (PARTITION BY tipo, tipo_dia), 2) AS pct
FROM por_hora
ORDER BY tipo, tipo_dia, hora;
