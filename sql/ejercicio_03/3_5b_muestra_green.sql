-- 3.5 Muestra de registros de taxis verdes (misma tecnica que 3.5a).
-- Fuente: data/raw/green/2026/*.parquet.
SELECT *
FROM read_parquet('/workspace/data/raw/green/2026/*.parquet', union_by_name = true)
WHERE hash(lpep_pickup_datetime, PULocationID, DOLocationID, total_amount) % 40000 = 0
ORDER BY lpep_pickup_datetime;
