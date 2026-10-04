-- Vistas de apoyo para el analisis exploratorio. Ninguna copia datos, solo
-- guardan consultas sobre los Parquet y el CSV de zonas.
-- Requiere la vista viajes (sql/ejercicio_03/00_vista_viajes.sql).

-- Nombres de las zonas de la TLC (LocationID a barrio y zona).
-- Fuente: data/raw/zonas/taxi_zone_lookup.csv
CREATE OR REPLACE VIEW zonas AS
SELECT LocationID, Borough AS barrio, Zone AS zona, service_zone
FROM read_csv('/workspace/data/raw/zonas/taxi_zone_lookup.csv');

-- Viajes que pasan las reglas de limpieza definidas en la consulta 3_7a:
-- pickup dentro del anio del archivo, duracion entre 1 minuto y 6 horas,
-- distancia mayor a 0 y hasta 100 millas, total mayor a 0.
-- Agrega columnas derivadas que usan varias consultas.
CREATE OR REPLACE VIEW viajes_limpios AS
SELECT
    *,
    epoch(dropoff - pickup) / 60 AS duracion_min,
    trip_distance / (epoch(dropoff - pickup) / 3600) AS velocidad_mph,
    hour(pickup) AS hora,
    isodow(pickup) AS dia_semana
FROM viajes
WHERE pickup >= make_date(anio_archivo, 1, 1) AND pickup < make_date(anio_archivo + 1, 1, 1)
  AND epoch(dropoff - pickup) BETWEEN 60 AND 6 * 3600
  AND trip_distance > 0 AND trip_distance <= 100
  AND total_amount > 0;
