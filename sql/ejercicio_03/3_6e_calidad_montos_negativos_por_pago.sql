-- 3.6 Calidad: a que tipo de pago pertenecen los montos negativos.
-- Objetivo: saber si los totales negativos son errores o devoluciones. Si se
-- concentran en payment_type 3 (sin cargo) y 4 (disputa), no son errores.
-- Codigos segun el diccionario de datos de la TLC: 0 Flex Fare, 1 tarjeta,
-- 2 efectivo, 3 sin cargo, 4 disputa, 5 desconocido, 6 viaje anulado.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    payment_type,
    count(*) AS viajes,
    count(*) FILTER (WHERE total_amount < 0) AS total_negativo,
    round(100.0 * count(*) FILTER (WHERE total_amount < 0) / count(*), 1) AS pct_negativo,
    round(avg(total_amount), 2) AS total_promedio
FROM viajes
GROUP BY tipo, payment_type
ORDER BY tipo, payment_type;
