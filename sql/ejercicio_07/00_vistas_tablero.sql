-- Vistas del tablero. Se crean dentro de data/processed/taxis.duckdb, sobre la
-- tabla materializada viajes que construye scripts/benchmark_parquet_vs_tabla.py,
-- porque Metabase se conecta a esa base en modo solo lectura y no puede crear
-- objetos. Se aplican con scripts/preparar_vistas_tablero.py.

-- Viajes cuya fecha de recogida cae dentro del anio de su archivo, con columnas
-- derivadas. Es la base de los indicadores de pagos, donde los viajes con monto
-- negativo o tarifa flexible son parte de lo que se quiere medir.
CREATE OR REPLACE VIEW viajes_anio AS
SELECT
    *,
    year(pickup) AS anio,
    month(pickup) AS mes,
    hour(pickup) AS hora,
    isodow(pickup) AS dia_semana,
    CAST(pickup AS DATE) AS fecha
FROM viajes
WHERE pickup >= make_date(anio_archivo, 1, 1)
  AND pickup < make_date(anio_archivo + 1, 1, 1);

-- Ademas pasan las reglas de limpieza de la consulta 3.7a: duracion entre 1
-- minuto y 6 horas, distancia mayor a 0 y hasta 100 millas, total mayor a 0.
CREATE OR REPLACE VIEW viajes_limpios AS
SELECT
    *,
    epoch(dropoff - pickup) / 60 AS duracion_min,
    trip_distance / (epoch(dropoff - pickup) / 3600) AS velocidad_mph
FROM viajes_anio
WHERE epoch(dropoff - pickup) BETWEEN 60 AND 6 * 3600
  AND trip_distance > 0 AND trip_distance <= 100
  AND total_amount > 0;
