-- Benchmark Q6: suma de una sola columna.
-- Mide el mejor caso de un formato en columnas: leer una columna de unas 20.
SELECT count(*) AS viajes, round(sum(total_amount), 2) AS total_pagado
FROM src;
