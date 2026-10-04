-- Indicador 4. Viajes por dia de la semana, como indice.
-- Pregunta: que dias de la semana tienen mas viajes y se comportan igual
-- amarillos y verdes? Se calcula el promedio de viajes por fecha de cada dia de
-- la semana y se expresa como indice, donde 100 es el promedio de la semana de
-- ese tipo, para que los dos tipos se puedan comparar pese a su escala.
-- Visualizacion: barras agrupadas por tipo.
WITH por_dia AS (
    SELECT
        tipo,
        dia_semana,
        count(*) * 1.0 / count(DISTINCT fecha) AS viajes_por_fecha
    FROM viajes_limpios
    GROUP BY tipo, dia_semana
)
SELECT
    CASE dia_semana WHEN 1 THEN '1 lun' WHEN 2 THEN '2 mar' WHEN 3 THEN '3 mie'
         WHEN 4 THEN '4 jue' WHEN 5 THEN '5 vie' WHEN 6 THEN '6 sab' ELSE '7 dom' END AS dia,
    tipo AS serie,
    round(100.0 * viajes_por_fecha / avg(viajes_por_fecha) OVER (PARTITION BY tipo), 1) AS indice_semanal
FROM por_dia
ORDER BY dia_semana, tipo;
