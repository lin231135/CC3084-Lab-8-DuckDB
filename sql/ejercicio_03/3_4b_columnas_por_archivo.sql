-- 3.4 Consistencia del esquema entre meses.
-- Objetivo: ver en cuantos archivos aparece cada columna y con que tipo fisico
-- de Parquet, para detectar cambios de esquema entre meses. Solo se muestran
-- las columnas que no estan en los 8 archivos de su tipo.
-- Fuente: data/raw/*/2026/*.parquet (solo el esquema, no los datos).
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo,
    name AS columna,
    type AS tipo_parquet,
    count(DISTINCT file_name) AS archivos_con_la_columna,
    min(regexp_extract(file_name, '(\d{4}-\d{2})', 1)) AS desde_mes
FROM parquet_schema('/workspace/data/raw/*/2026/*.parquet')
WHERE name <> 'schema'
GROUP BY ALL
HAVING count(DISTINCT file_name) < 8
ORDER BY tipo, columna;
