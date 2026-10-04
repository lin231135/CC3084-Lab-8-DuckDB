-- P12. Cuales son los pares origen y destino mas frecuentes?
-- Las 5 rutas con mas viajes por tipo, con el nombre de la zona de origen y de
-- destino. Un origen igual al destino es un viaje dentro de la misma zona.
-- Fuente: vista viajes_limpios y vista zonas (CSV de zonas de la TLC).
SELECT
    v.tipo,
    row_number() OVER (PARTITION BY v.tipo ORDER BY count(*) DESC) AS posicion,
    zo.zona AS origen,
    zd.zona AS destino,
    count(*) AS viajes,
    round(quantile_cont(v.trip_distance, 0.5), 2) AS mediana_millas,
    round(quantile_cont(v.total_amount, 0.5), 2) AS mediana_total
FROM viajes_limpios v
LEFT JOIN zonas zo ON v.PULocationID = zo.LocationID
LEFT JOIN zonas zd ON v.DOLocationID = zd.LocationID
GROUP BY v.tipo, zo.zona, zd.zona
QUALIFY posicion <= 5
ORDER BY v.tipo, posicion;
