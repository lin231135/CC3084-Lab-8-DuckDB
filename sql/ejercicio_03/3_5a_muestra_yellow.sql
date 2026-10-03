-- 3.5 Muestra de registros de taxis amarillos.
-- Objetivo: ver como lucen los datos reales. La muestra es reproducible: toma
-- las filas cuyo hash cae en una clase fija, en lugar de un muestreo aleatorio
-- que cambiaria en cada corrida.
-- Fuente: data/raw/yellow/2026/*.parquet.
SELECT *
FROM read_parquet('/workspace/data/raw/yellow/2026/*.parquet', union_by_name = true)
WHERE hash(tpep_pickup_datetime, PULocationID, DOLocationID, total_amount) % 4000000 = 0
ORDER BY tpep_pickup_datetime;
