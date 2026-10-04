-- 5.7 Cambios de esquema entre anios.
-- Objetivo: ver que columnas existen en cada anio y con que tipo fisico de
-- Parquet, para decidir si las consultas necesitan ajustes. Solo se muestran
-- las columnas que no estan en todos los archivos de su tipo, o que cambian de
-- tipo entre anios.
-- Fuente: data/raw/*/*/*.parquet (solo el esquema).
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo,
        CAST(regexp_extract(file_name, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio,
        file_name,
        name AS columna,
        type AS tipo_parquet
    FROM parquet_schema('/workspace/data/raw/*/*/*.parquet')
    WHERE name <> 'schema'
),
archivos AS (
    SELECT tipo, anio, count(DISTINCT file_name) AS total_archivos
    FROM esquema
    GROUP BY ALL
)
SELECT
    e.tipo, e.columna, e.anio, e.tipo_parquet,
    count(DISTINCT e.file_name) AS archivos_con_la_columna,
    a.total_archivos AS archivos_del_anio
FROM esquema e
JOIN archivos a USING (tipo, anio)
GROUP BY e.tipo, e.columna, e.anio, e.tipo_parquet, a.total_archivos
HAVING count(DISTINCT e.file_name) < a.total_archivos
    OR e.columna IN (
        SELECT columna FROM esquema GROUP BY tipo, columna
        HAVING count(DISTINCT anio) < (SELECT count(DISTINCT anio) FROM esquema)
            OR count(DISTINCT tipo_parquet) > 1)
ORDER BY e.tipo, e.columna, e.anio;
