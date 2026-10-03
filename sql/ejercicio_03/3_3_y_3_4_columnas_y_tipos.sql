-- 3.3 y 3.4 Columnas presentes y tipos de datos, amarillos contra verdes.
-- Objetivo: comparar los esquemas. Las columnas de fecha se llaman distinto
-- (tpep_ contra lpep_), asi que se normaliza el nombre para alinearlas.
-- union_by_name = true une los archivos por nombre, porque algunas columnas
-- no existen en todos los meses.
-- Fuente: yellow/2026/*.parquet y green/2026/*.parquet.
WITH y AS (
    SELECT regexp_replace(column_name, '^tpep_', 'xpep_') AS columna,
           column_name AS nombre_yellow, column_type AS tipo_yellow
    FROM (DESCRIBE SELECT * FROM read_parquet(
        '/workspace/data/raw/yellow/2026/*.parquet', union_by_name = true))
),
g AS (
    SELECT regexp_replace(column_name, '^lpep_', 'xpep_') AS columna,
           column_name AS nombre_green, column_type AS tipo_green
    FROM (DESCRIBE SELECT * FROM read_parquet(
        '/workspace/data/raw/green/2026/*.parquet', union_by_name = true))
)
SELECT
    coalesce(y.columna, g.columna) AS columna,
    y.nombre_yellow, y.tipo_yellow,
    g.nombre_green, g.tipo_green,
    CASE WHEN y.columna IS NULL THEN 'solo green'
         WHEN g.columna IS NULL THEN 'solo yellow'
         WHEN y.tipo_yellow <> g.tipo_green THEN 'tipos distintos'
         ELSE 'en ambos' END AS presencia
FROM y FULL OUTER JOIN g ON y.columna = g.columna
ORDER BY presencia, columna;
