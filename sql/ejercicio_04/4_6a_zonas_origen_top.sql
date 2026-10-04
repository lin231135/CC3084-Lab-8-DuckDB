-- P6. Desde que zonas salen mas viajes, y es distinto entre amarillos y verdes?
-- Las 10 zonas de recogida con mas viajes por tipo, con su porcentaje del tipo.
-- Fuente: vista viajes_limpios y vista zonas (CSV de zonas de la TLC).
SELECT
    v.tipo,
    row_number() OVER (PARTITION BY v.tipo ORDER BY count(*) DESC) AS posicion,
    z.barrio,
    z.zona,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY v.tipo), 2) AS pct_del_tipo
FROM viajes_limpios v
LEFT JOIN zonas z ON v.PULocationID = z.LocationID
GROUP BY v.tipo, z.barrio, z.zona
QUALIFY posicion <= 10
ORDER BY v.tipo, posicion;
