-- 3.2 Cantidad de registros segun la metadata del pie de pagina de Parquet.
-- Objetivo: obtener el mismo total sin leer los datos y compararlo con 3.2a.
-- Fuente: data/raw/*/2026/*.parquet (solo se lee el footer de cada archivo).
SELECT
    coalesce(regexp_extract(file_name, '(yellow|green)_tripdata', 1), 'total') AS tipo,
    count(*) AS archivos,
    sum(num_rows) AS viajes,
    sum(num_row_groups) AS grupos_de_filas
FROM parquet_file_metadata('/workspace/data/raw/*/2026/*.parquet')
GROUP BY ROLLUP (regexp_extract(file_name, '(yellow|green)_tripdata', 1))
ORDER BY tipo;
