-- Benchmark Q1: conteo de viajes por tipo y mes de archivo.
-- Mide una agregacion simple con muy pocas columnas (tipo y mes).
SELECT tipo, mes_archivo, count(*) AS viajes
FROM src
GROUP BY tipo, mes_archivo
ORDER BY tipo, mes_archivo;
