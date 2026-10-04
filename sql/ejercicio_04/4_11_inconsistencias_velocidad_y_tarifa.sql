-- P11. Hay viajes cuyos valores son incoherentes entre si aunque cada uno
-- parezca razonable por separado?
-- Se cruzan variables: velocidad implicita (distancia entre duracion), tarifa
-- por milla y propina frente a tarifa. Se parte de los viajes que ya pasaron la
-- limpieza basica, asi que lo que sale aqui sobrevivio a las reglas de 3.7a.
-- Fuente: vista viajes_limpios (Parquet de 2026).
SELECT
    tipo,
    count(*) AS viajes,
    count(*) FILTER (WHERE velocidad_mph > 80) AS velocidad_mayor_80_mph,
    count(*) FILTER (WHERE velocidad_mph < 1) AS velocidad_menor_1_mph,
    count(*) FILTER (WHERE fare_amount / trip_distance > 50) AS tarifa_mayor_50_por_milla,
    count(*) FILTER (WHERE tip_amount > fare_amount AND fare_amount > 0) AS propina_mayor_que_tarifa,
    count(*) FILTER (WHERE tip_amount > 100) AS propina_mayor_100,
    round(max(velocidad_mph), 1) AS velocidad_maxima_mph
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo;
