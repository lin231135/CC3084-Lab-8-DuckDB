-- Vista de apoyo: une amarillos y verdes con nombres de columna comunes.
-- No copia datos: es solo una consulta guardada sobre los Parquet, que se
-- vuelve a leer cada vez que se usa la vista. Los viajes se distinguen por tipo.
--
-- Lee todos los anios que haya en data/raw (yellow/*/ y green/*/), de modo que
-- un anio nuevo entra sin tocar esta vista. Para analizar solo algunos anios se
-- define antes la variable de sesion anios; si no se define, se usan todos:
--     SET VARIABLE anios = [2026];
--     SET VARIABLE anios = [2024, 2026];
--
-- Fuente: data/raw/yellow/*/*.parquet y data/raw/green/*/*.parquet
CREATE OR REPLACE VIEW viajes AS
SELECT *
FROM (
    SELECT
        'yellow' AS tipo,
        filename AS archivo,
        regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
        CAST(regexp_extract(filename, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio_archivo,
        tpep_pickup_datetime AS pickup,
        tpep_dropoff_datetime AS dropoff,
        * EXCLUDE (filename, tpep_pickup_datetime, tpep_dropoff_datetime)
    FROM read_parquet('/workspace/data/raw/yellow/*/*.parquet',
                      union_by_name = true, filename = true)
    UNION ALL BY NAME
    SELECT
        'green' AS tipo,
        filename AS archivo,
        regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
        CAST(regexp_extract(filename, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio_archivo,
        lpep_pickup_datetime AS pickup,
        lpep_dropoff_datetime AS dropoff,
        * EXCLUDE (filename, lpep_pickup_datetime, lpep_dropoff_datetime)
    FROM read_parquet('/workspace/data/raw/green/*/*.parquet',
                      union_by_name = true, filename = true)
)
WHERE getvariable('anios') IS NULL
   OR list_contains(getvariable('anios'), anio_archivo);
