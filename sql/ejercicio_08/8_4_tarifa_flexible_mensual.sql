-- 8.5 y 8.6 Tarifa flexible (Flex Fare), mes a mes en los tres anios.
-- Objetivo: ubicar en que momento crece la proporcion de viajes de tarifa
-- flexible y si lo hace de golpe o de forma gradual. En amarillos viene como
-- payment_type 0 y en verdes como nulo, por eso se juntan con coalesce.
-- Fuente: vista viajes_anio (sql/ejercicio_07/00_vistas_tablero.sql).
SELECT
    tipo,
    strftime(make_date(anio, mes, 1), '%Y-%m') AS mes,
    count(*) AS viajes,
    round(100.0 * count(*) FILTER (WHERE coalesce(payment_type, 0) = 0) / count(*), 1) AS pct_tarifa_flexible
FROM viajes_anio
GROUP BY tipo, anio, mes
ORDER BY tipo, mes;
