-- Fuente normalizada de viajes: une amarillos y verdes con nombres comunes.
-- Es la misma definicion para las dos estrategias del benchmark: sobre Parquet
-- se usa como vista (lee solo los archivos del volumen que se esta midiendo) y
-- sobre la tabla se usa para llenarla (INSERT por mes). Asi las dos comparan
-- exactamente las mismas columnas y tipos.
--
-- scripts/benchmark_parquet_vs_tabla.py reemplaza los marcadores por listas de
-- archivos:  $ARCHIVOS_YELLOW$  y  $ARCHIVOS_GREEN$  (listas de rutas Parquet).
SELECT
    'yellow' AS tipo,
    CAST(regexp_extract(filename, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio_archivo,
    regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
    tpep_pickup_datetime AS pickup,
    tpep_dropoff_datetime AS dropoff,
    * EXCLUDE (filename, tpep_pickup_datetime, tpep_dropoff_datetime)
FROM read_parquet($ARCHIVOS_YELLOW$, union_by_name = true, filename = true)
UNION ALL BY NAME
SELECT
    'green' AS tipo,
    CAST(regexp_extract(filename, 'tripdata_(\d{4})', 1) AS INTEGER) AS anio_archivo,
    regexp_extract(filename, '(\d{4}-\d{2})', 1) AS mes_archivo,
    lpep_pickup_datetime AS pickup,
    lpep_dropoff_datetime AS dropoff,
    * EXCLUDE (filename, lpep_pickup_datetime, lpep_dropoff_datetime)
FROM read_parquet($ARCHIVOS_GREEN$, union_by_name = true, filename = true)
