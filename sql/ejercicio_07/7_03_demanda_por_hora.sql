-- Indicador 3. Demanda por hora del dia.
-- Pregunta: a que horas se concentra la demanda y es distinta entre semana y
-- fin de semana, en amarillos y en verdes? Se usa el porcentaje de los viajes de
-- cada tipo y tipo de dia, para comparar curvas de volumen muy distinto.
-- Visualizacion: lineas, cuatro series (tipo y tipo de dia).
WITH por_hora AS (
    SELECT
        tipo || CASE WHEN dia_semana >= 6 THEN ' fin de semana' ELSE ' entre semana' END AS serie,
        hora,
        count(*) AS viajes
    FROM viajes_limpios
    GROUP BY 1, 2
)
SELECT
    hora,
    serie,
    round(100.0 * viajes / sum(viajes) OVER (PARTITION BY serie), 2) AS pct_viajes
FROM por_hora
ORDER BY serie, hora;
