-- 5.5 Verificar que los archivos de 2024 fueron incorporados.
-- Objetivo: contar archivos y registros por tipo y anio sin cargar datos. Los
-- registros salen del pie de pagina de cada Parquet, asi que es inmediato.
-- Fuente: data/raw/*/*/*.parquet (solo la metadata de cada archivo).
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo,
    CAST(regexp_extract(file_name, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio,
    count(*) AS archivos,
    min(regexp_extract(file_name, '(\d{4}-\d{2})', 1)) AS primer_mes,
    max(regexp_extract(file_name, '(\d{4}-\d{2})', 1)) AS ultimo_mes,
    sum(num_rows) AS viajes
FROM parquet_file_metadata('/workspace/data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo, anio;
