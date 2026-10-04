-- P3. Que dia de la semana tiene mas viajes?
-- Se usa el promedio de viajes por fecha, porque en 8 meses algunos dias de la
-- semana ocurren una vez mas que otros.
-- Fuente: vista viajes_limpios (Parquet de 2026).
SELECT
    tipo,
    dia_semana,
    CASE dia_semana WHEN 1 THEN 'lunes' WHEN 2 THEN 'martes' WHEN 3 THEN 'miercoles'
         WHEN 4 THEN 'jueves' WHEN 5 THEN 'viernes' WHEN 6 THEN 'sabado'
         ELSE 'domingo' END AS dia,
    count(*) AS viajes,
    count(DISTINCT CAST(pickup AS DATE)) AS fechas,
    round(count(*) * 1.0 / count(DISTINCT CAST(pickup AS DATE))) AS viajes_por_fecha
FROM viajes_limpios
GROUP BY ALL
ORDER BY tipo, dia_semana;
