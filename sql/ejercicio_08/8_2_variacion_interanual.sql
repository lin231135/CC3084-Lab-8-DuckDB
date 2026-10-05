-- 8.5 y 8.6 Variacion interanual mes a mes.
-- Objetivo: ver, para cada mes del calendario, cuanto cambia el volumen diario y
-- el total mediano respecto al mismo mes del anio anterior. Comparar el mismo mes
-- quita el efecto de la temporada. Los meses de 2024 no tienen anio anterior en
-- los datos, asi que quedan vacios.
-- Fuente: vista viajes_limpios (sql/ejercicio_07/00_vistas_tablero.sql).
WITH mensual AS (
    SELECT
        tipo, anio, mes,
        count(*) * 1.0 / count(DISTINCT fecha) AS viajes_por_dia,
        quantile_cont(total_amount, 0.5) AS total_mediano
    FROM viajes_limpios
    GROUP BY tipo, anio, mes
)
SELECT
    tipo, anio, mes,
    round(viajes_por_dia) AS viajes_por_dia,
    round(100.0 * (viajes_por_dia / lag(viajes_por_dia) OVER w - 1), 1) AS var_viajes_pct,
    round(total_mediano, 2) AS total_mediano,
    round(100.0 * (total_mediano / lag(total_mediano) OVER w - 1), 1) AS var_total_pct
FROM mensual
WINDOW w AS (PARTITION BY tipo, mes ORDER BY anio)
ORDER BY tipo, anio, mes;
