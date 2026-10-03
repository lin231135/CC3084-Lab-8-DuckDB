-- 3.6 Calidad: columna request_source, que solo existe en algunos meses.
-- Objetivo: ver desde que mes aparece y que valores toma, porque en los meses
-- sin la columna el valor queda nulo al unir los archivos por nombre.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    mes_archivo,
    coalesce(request_source, '(nulo)') AS request_source,
    count(*) AS viajes
FROM viajes
WHERE mes_archivo >= '2026-05'
GROUP BY ALL
ORDER BY tipo, mes_archivo, viajes DESC;
