-- Indicador 6. Mezcla de metodos de pago por tipo y anio.
-- Pregunta: como pagan los pasajeros y cambia esa mezcla entre anios? Se usan
-- todos los viajes con fecha valida, porque la tarifa flexible, las disputas y
-- los montos negativos son parte de lo que se quiere medir.
-- Codigos segun el diccionario de la TLC: 0 Flex Fare, 1 tarjeta, 2 efectivo,
-- 3 sin cargo, 4 disputa, 5 desconocido, 6 anulado. En verdes la tarifa flexible
-- viene con payment_type nulo, por eso se junta con el 0.
-- Visualizacion: barras apiladas al 100%, una barra por tipo y anio.
SELECT
    tipo || ' ' || anio AS grupo,
    CASE coalesce(payment_type, 0) WHEN 0 THEN 'tarifa flexible' WHEN 1 THEN 'tarjeta'
         WHEN 2 THEN 'efectivo' ELSE 'otro' END AS metodo,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo, anio), 2) AS pct_viajes
FROM viajes_anio
GROUP BY tipo, anio, metodo
ORDER BY grupo, metodo;
