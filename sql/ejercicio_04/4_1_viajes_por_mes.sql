-- P1. Como evoluciona el volumen de viajes por mes y tipo de taxi?
-- Los meses tienen distinta cantidad de dias, asi que ademas del total se
-- calcula el promedio de viajes por dia, que es lo comparable entre meses.
-- Fuente: vista viajes_limpios (Parquet de 2026).
SELECT
    tipo,
    strftime(pickup, '%Y-%m') AS mes,
    count(*) AS viajes,
    count(DISTINCT CAST(pickup AS DATE)) AS dias,
    round(count(*) * 1.0 / count(DISTINCT CAST(pickup AS DATE))) AS viajes_por_dia
FROM viajes_limpios
GROUP BY ALL
ORDER BY tipo, mes;
