-- 3.6 Calidad: posibles viajes duplicados.
-- Objetivo: estimar cuantas filas repiten exactamente el mismo viaje segun un
-- conjunto de columnas que lo identifica. Es una estimacion, porque dos viajes
-- distintos podrian coincidir en todas estas columnas. Tarda unos 40 segundos.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) AS viajes,
    count(*) - count(DISTINCT (pickup, dropoff, PULocationID, DOLocationID,
                               total_amount, trip_distance, VendorID)) AS filas_repetidas
FROM viajes
GROUP BY tipo
ORDER BY tipo;
