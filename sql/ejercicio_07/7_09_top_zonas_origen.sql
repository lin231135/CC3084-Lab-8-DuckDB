-- Indicador 9. Las 10 zonas con mas viajes de recogida.
-- Pregunta: de donde salen la mayoria de los viajes y aportan igual amarillos y
-- verdes? Las zonas se ordenan por el total de ambos tipos.
-- Visualizacion: barras horizontales apiladas por tipo.
WITH por_zona AS (
    SELECT z.zona, v.tipo AS serie, count(*) AS viajes
    FROM viajes_limpios v
    JOIN zonas z ON v.PULocationID = z.LocationID
    GROUP BY z.zona, v.tipo
),
top10 AS (
    SELECT zona FROM por_zona GROUP BY zona ORDER BY sum(viajes) DESC, zona LIMIT 10
)
SELECT p.zona, p.serie, p.viajes
FROM por_zona p
JOIN top10 USING (zona)
ORDER BY p.zona, p.serie;
