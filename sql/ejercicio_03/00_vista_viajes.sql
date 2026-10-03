-- Vista de apoyo: une amarillos y verdes de 2026 con nombres de columna comunes.
-- No copia datos: es solo una consulta guardada sobre los Parquet, que se
-- vuelve a leer cada vez que se usa la vista. Los viajes se distinguen por tipo.
-- Fuente: data/raw/yellow/2026/*.parquet y data/raw/green/2026/*.parquet
CREATE OR REPLACE VIEW viajes AS
SELECT
    'yellow' AS tipo,
    filename AS archivo,
    regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
    tpep_pickup_datetime AS pickup,
    tpep_dropoff_datetime AS dropoff,
    * EXCLUDE (filename, tpep_pickup_datetime, tpep_dropoff_datetime)
FROM read_parquet('/workspace/data/raw/yellow/2026/*.parquet',
                  union_by_name = true, filename = true)
UNION ALL BY NAME
SELECT
    'green' AS tipo,
    filename AS archivo,
    regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
    lpep_pickup_datetime AS pickup,
    lpep_dropoff_datetime AS dropoff,
    * EXCLUDE (filename, lpep_pickup_datetime, lpep_dropoff_datetime)
FROM read_parquet('/workspace/data/raw/green/2026/*.parquet',
                  union_by_name = true, filename = true);
