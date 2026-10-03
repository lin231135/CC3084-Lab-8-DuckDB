-- 3.6 Calidad: fechas de recogida fuera de rango.
-- Objetivo: detectar viajes cuya fecha no corresponde al periodo de los
-- archivos (enero a agosto de 2026) o al mes del archivo donde vienen.
-- Fuente: vista viajes (00_vista_viajes.sql).
SELECT
    tipo,
    count(*) AS viajes,
    min(pickup) AS pickup_minimo,
    max(pickup) AS pickup_maximo,
    count(*) FILTER (WHERE pickup < DATE '2026-01-01'
                        OR pickup >= DATE '2026-09-01') AS fuera_de_2026_01_a_08,
    count(*) FILTER (WHERE strftime(pickup, '%Y-%m') <> mes_archivo) AS fuera_del_mes_del_archivo
FROM viajes
GROUP BY tipo
ORDER BY tipo;
