-- 3.2 Cantidad de registros disponibles (conteo real sobre los datos).
-- Objetivo: contar viajes por tipo de taxi y mes de archivo.
-- Fuente: yellow/2026/*.parquet y green/2026/*.parquet con filename = true.
SELECT
    regexp_extract(filename, '(yellow|green)_tripdata', 1) AS tipo,
    regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
    count(*) AS viajes
FROM read_parquet('/workspace/data/raw/*/2026/*.parquet',
                  union_by_name = true, filename = true)
GROUP BY ALL
ORDER BY tipo, mes_archivo;
