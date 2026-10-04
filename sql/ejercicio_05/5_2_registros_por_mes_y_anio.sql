-- 5.6 Consultar 2024 y 2026 conjuntamente: viajes por mes.
-- Objetivo: ver, en una sola consulta sobre todos los archivos, el volumen de
-- cada mes de cada anio. Los meses se alinean en columnas para poder comparar
-- el mismo mes entre anios. Los meses sin archivo aparecen vacios.
-- Fuente: vista viajes (Parquet de todos los anios en data/raw).
PIVOT (
    SELECT tipo, anio_archivo AS anio, month(pickup) AS mes_del_viaje, count(*) AS viajes
    FROM viajes
    WHERE pickup >= make_date(anio_archivo, 1, 1)
      AND pickup < make_date(anio_archivo + 1, 1, 1)
    GROUP BY ALL
)
ON anio
USING sum(viajes)
ORDER BY tipo, mes_del_viaje;
