-- Indicador 10. Velocidad mediana de los viajes, por mes, tipo y anio.
-- Pregunta: cambia con el tiempo la velocidad a la que se mueve el trafico?
-- Es un indicador indirecto de la congestion, calculado como distancia entre
-- duracion de cada viaje.
-- Visualizacion: lineas, una serie por tipo y anio.
SELECT
    mes,
    tipo || ' ' || anio AS serie,
    round(quantile_cont(velocidad_mph, 0.5), 2) AS velocidad_mediana_mph
FROM viajes_limpios
GROUP BY tipo, anio, mes
ORDER BY serie, mes;
