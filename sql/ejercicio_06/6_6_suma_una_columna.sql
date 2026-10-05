-- Benchmark Q6: suma de una sola columna.
-- Mide el mejor caso de un formato en columnas: leer una columna de unas 20.
-- Se suma en centavos enteros y no en decimales: la suma de decimales en paralelo
-- depende del orden en que se junten los resultados parciales, y con 121 millones
-- de filas las dos estrategias daban resultados que diferian en el ultimo decimal.
SELECT
    count(*) AS viajes,
    sum(CAST(round(total_amount * 100) AS BIGINT)) / 100.0 AS total_pagado
FROM src;
