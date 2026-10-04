-- 3.7 Efecto de las reglas de limpieza candidatas.
-- Objetivo: medir cuantos viajes se descartarian al aplicar reglas simples de
-- calidad, para decidir si conviene filtrarlos en los analisis siguientes.
-- Reglas: pickup dentro del anio del archivo, duracion entre 1 minuto y 6 horas,
-- distancia mayor a 0 y menor o igual a 100 millas, total mayor a 0.
-- Fuente: vista viajes (00_vista_viajes.sql).
WITH evaluados AS (
    SELECT
        tipo,
        pickup >= make_date(anio_archivo, 1, 1) AND pickup < make_date(anio_archivo + 1, 1, 1) AS fecha_ok,
        epoch(dropoff - pickup) BETWEEN 60 AND 6 * 3600 AS duracion_ok,
        trip_distance > 0 AND trip_distance <= 100 AS distancia_ok,
        total_amount > 0 AS monto_ok
    FROM viajes
)
SELECT
    tipo,
    count(*) AS viajes,
    count(*) FILTER (WHERE fecha_ok AND duracion_ok AND distancia_ok AND monto_ok) AS utilizables,
    count(*) FILTER (WHERE NOT (fecha_ok AND duracion_ok AND distancia_ok AND monto_ok)) AS descartados,
    round(100.0 * count(*) FILTER (WHERE NOT (fecha_ok AND duracion_ok AND distancia_ok AND monto_ok))
          / count(*), 2) AS pct_descartado,
    count(*) FILTER (WHERE NOT fecha_ok) AS falla_fecha,
    count(*) FILTER (WHERE NOT duracion_ok) AS falla_duracion,
    count(*) FILTER (WHERE NOT distancia_ok) AS falla_distancia,
    count(*) FILTER (WHERE NOT monto_ok) AS falla_monto
FROM evaluados
GROUP BY tipo
ORDER BY tipo;
