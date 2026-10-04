-- 3.6 Calidad: fechas de recogida fuera de rango.
-- Objetivo: detectar viajes cuya fecha no corresponde al anio del archivo donde
-- vienen, o al mes de ese archivo.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) AS viajes,
    min(pickup) AS pickup_minimo,
    max(pickup) AS pickup_maximo,
    count(*) FILTER (WHERE pickup < make_date(anio_archivo, 1, 1)
                        OR pickup >= make_date(anio_archivo + 1, 1, 1)) AS fuera_del_anio_del_archivo,
    count(*) FILTER (WHERE strftime(pickup, '%Y-%m') <> mes_archivo) AS fuera_del_mes_del_archivo
FROM viajes
GROUP BY tipo
ORDER BY tipo;
