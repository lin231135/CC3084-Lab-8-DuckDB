-- 3.6 Calidad: peso de los nulos de pasajeros por mes y tipo.
-- Objetivo: ver si el problema de nulos es de un mes puntual o constante.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    mes_archivo,
    count(*) AS viajes,
    count(*) FILTER (WHERE passenger_count IS NULL) AS pasajeros_nulo,
    round(100.0 * count(*) FILTER (WHERE passenger_count IS NULL) / count(*), 1) AS pct_nulo
FROM viajes
GROUP BY tipo, mes_archivo
ORDER BY tipo, mes_archivo;
