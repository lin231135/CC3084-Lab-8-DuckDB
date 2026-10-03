-- 3.6 Calidad: valores nulos y pasajeros fuera de rango.
-- Objetivo: medir los nulos en las columnas que los tienen y comprobar si
-- ocurren juntos en las mismas filas (todos_nulos_juntos).
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) AS viajes,
    count(*) FILTER (WHERE passenger_count IS NULL) AS pasajeros_nulo,
    count(*) FILTER (WHERE RatecodeID IS NULL) AS ratecode_nulo,
    count(*) FILTER (WHERE store_and_fwd_flag IS NULL) AS flag_nulo,
    count(*) FILTER (WHERE payment_type IS NULL OR payment_type = 0) AS pago_nulo_o_cero,
    count(*) FILTER (WHERE passenger_count IS NULL AND RatecodeID IS NULL
                       AND store_and_fwd_flag IS NULL
                       AND coalesce(payment_type, 0) = 0) AS todos_nulos_juntos,
    count(*) FILTER (WHERE passenger_count = 0) AS pasajeros_cero,
    count(*) FILTER (WHERE passenger_count > 6) AS pasajeros_mayor_a_6
FROM viajes
GROUP BY tipo
ORDER BY tipo;
