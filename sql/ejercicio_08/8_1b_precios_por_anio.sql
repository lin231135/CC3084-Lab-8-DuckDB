-- 8.5 Evolucion por anio: lo que paga un pasajero, mismos meses.
-- Objetivo: comparar la mediana de la tarifa del taximetro, del total pagado y
-- de la distancia entre 2024, 2025 y 2026, con enero a agosto de cada anio.
-- Tres medianas exactas en una sola consulta caben en la memoria del contenedor;
-- con mas columnas hay que repartirlas en consultas distintas.
-- Fuente: vista viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql).
SELECT
    tipo,
    anio,
    round(quantile_cont(fare_amount, 0.5), 2) AS tarifa_mediana,
    round(quantile_cont(total_amount, 0.5), 2) AS total_mediano,
    round(quantile_cont(trip_distance, 0.5), 2) AS distancia_mediana_millas
FROM viajes_limpios
WHERE mes <= 8
GROUP BY tipo, anio
ORDER BY tipo, anio;
