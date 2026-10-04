-- P6 (barrios). En que barrios se recogen los viajes de cada tipo de taxi?
-- Fuente: vista viajes_limpios y vista zonas (CSV de zonas de la TLC).
WITH por_barrio AS (
    SELECT
        v.tipo,
        coalesce(z.barrio, '(sin zona)') AS barrio,
        count(*) AS viajes
    FROM viajes_limpios v
    LEFT JOIN zonas z ON v.PULocationID = z.LocationID
    GROUP BY 1, 2
)
SELECT
    tipo, barrio, viajes,
    round(100.0 * viajes / sum(viajes) OVER (PARTITION BY tipo), 2) AS pct_del_tipo
FROM por_barrio
ORDER BY tipo, viajes DESC;
