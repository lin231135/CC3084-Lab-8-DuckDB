-- 3.6 Calidad: duracion de los viajes.
-- Objetivo: contar viajes con duracion imposible o absurda (bajada antes de la
-- subida, duracion cero, mas de 6 horas) y ver la mediana y el percentil 99 de
-- la duracion en minutos de los viajes con duracion positiva.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) FILTER (WHERE dropoff < pickup) AS bajada_antes_de_subida,
    count(*) FILTER (WHERE dropoff = pickup) AS duracion_cero,
    count(*) FILTER (WHERE epoch(dropoff - pickup) > 6 * 3600) AS mas_de_6_horas,
    count(*) FILTER (WHERE epoch(dropoff - pickup) > 24 * 3600) AS mas_de_24_horas,
    round(quantile_cont(epoch(dropoff - pickup) / 60, 0.50)
          FILTER (WHERE dropoff > pickup), 1) AS mediana_min,
    round(quantile_cont(epoch(dropoff - pickup) / 60, 0.99)
          FILTER (WHERE dropoff > pickup), 1) AS p99_min
FROM viajes
GROUP BY tipo
ORDER BY tipo;
