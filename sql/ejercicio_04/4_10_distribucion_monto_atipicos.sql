-- P10. Como se distribuye el total pagado y cuanto pesan los valores atipicos?
-- Se marca como atipico un total por encima de Q3 + 1.5 * IQR, que es la regla
-- usual del diagrama de caja, y se mide que parte de los viajes y del ingreso
-- representan. Los cuantiles se piden en una sola llamada para no agotar memoria.
-- Fuente: vista viajes_limpios (Parquet de 2026).
WITH cuantiles AS (
    SELECT tipo, quantile_cont(total_amount, [0.25, 0.50, 0.75, 0.99]) AS q
    FROM viajes_limpios
    GROUP BY tipo
),
limites AS (
    SELECT
        tipo,
        q[1] AS q1, q[2] AS mediana, q[3] AS q3, q[4] AS p99,
        q[3] + 1.5 * (q[3] - q[1]) AS limite_atipico
    FROM cuantiles
)
SELECT
    l.tipo,
    round(l.q1, 2) AS q1,
    round(l.mediana, 2) AS mediana,
    round(l.q3, 2) AS q3,
    round(l.p99, 2) AS p99,
    round(l.limite_atipico, 2) AS limite_atipico,
    count(*) AS viajes,
    count(*) FILTER (WHERE v.total_amount > l.limite_atipico) AS atipicos,
    round(100.0 * count(*) FILTER (WHERE v.total_amount > l.limite_atipico) / count(*), 2) AS pct_viajes_atipicos,
    round(100.0 * sum(v.total_amount) FILTER (WHERE v.total_amount > l.limite_atipico)
          / sum(v.total_amount), 2) AS pct_ingreso_atipicos,
    round(avg(v.total_amount), 2) AS promedio,
    round(max(v.total_amount), 2) AS maximo
FROM viajes_limpios v
JOIN limites l USING (tipo)
GROUP BY l.tipo, l.q1, l.mediana, l.q3, l.p99, l.limite_atipico
ORDER BY l.tipo;
