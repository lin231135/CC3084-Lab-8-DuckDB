-- P8. Como pagan los pasajeros y como cambia la propina segun el tipo de pago?
-- Se usa la vista viajes completa y no la limpia, porque los montos negativos
-- (disputas y viajes sin cargo) y los pagos tipo 0 son parte de la respuesta.
-- Codigos segun el diccionario de la TLC: 0 Flex Fare, 1 tarjeta, 2 efectivo,
-- 3 sin cargo, 4 disputa, 5 desconocido, 6 viaje anulado.
-- Fuente: vista viajes (Parquet de 2026).
SELECT
    tipo,
    coalesce(CAST(payment_type AS VARCHAR), '(nulo)') AS payment_type,
    CASE payment_type WHEN 0 THEN 'Flex Fare' WHEN 1 THEN 'tarjeta' WHEN 2 THEN 'efectivo'
         WHEN 3 THEN 'sin cargo' WHEN 4 THEN 'disputa' WHEN 5 THEN 'desconocido'
         WHEN 6 THEN 'anulado' ELSE 'nulo (Flex Fare en verdes)' END AS metodo,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct_del_tipo,
    round(avg(total_amount), 2) AS total_promedio,
    round(avg(tip_amount), 2) AS propina_promedio,
    round(100.0 * count(*) FILTER (WHERE tip_amount > 0) / count(*), 1) AS pct_con_propina
FROM viajes
GROUP BY tipo, payment_type
ORDER BY tipo, viajes DESC;
