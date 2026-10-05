-- 8.5 y 8.6 Peso de los aeropuertos en los viajes, mismos meses.
-- Objetivo: ver si la proporcion de viajes que salen de un aeropuerto (zonas 1
-- EWR, 132 JFK y 138 LaGuardia) y la que paga el recargo de aeropuerto
-- (solo existe en amarillos) cambian entre 2024, 2025 y 2026, con enero a
-- agosto de cada anio.
-- Fuente: vista viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql).
SELECT
    tipo,
    anio,
    count(*) AS viajes,
    round(100.0 * count(*) FILTER (WHERE PULocationID IN (1, 132, 138)) / count(*), 2) AS pct_salen_de_aeropuerto,
    round(100.0 * count(*) FILTER (WHERE Airport_fee > 0)
          / nullif(count(*) FILTER (WHERE Airport_fee IS NOT NULL), 0), 2) AS pct_con_recargo_aeropuerto
FROM viajes_limpios
WHERE mes <= 8
GROUP BY tipo, anio
ORDER BY tipo, anio;
