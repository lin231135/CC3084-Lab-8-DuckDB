-- 3.1 Cantidad de archivos disponibles.
-- Objetivo: contar los Parquet por tipo de taxi y ver el rango de meses.
-- Fuente: data/raw/*/2026/*.parquet (glob() solo lista archivos, no los lee).
SELECT
    coalesce(regexp_extract(file, '(yellow|green)_tripdata', 1), 'total') AS tipo,
    count(*) AS archivos,
    min(regexp_extract(file, '(\d{4}-\d{2})', 1)) AS primer_mes,
    max(regexp_extract(file, '(\d{4}-\d{2})', 1)) AS ultimo_mes
FROM glob('/workspace/data/raw/*/2026/*.parquet')
GROUP BY ROLLUP (regexp_extract(file, '(yellow|green)_tripdata', 1))
ORDER BY tipo;
