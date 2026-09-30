/* =====================================================================
   02_query_2_1_corregida.sql
   Versión corregida
   ===================================================================== */

Use Prueba_Tecnica_Sura;

--query de la prueba
WITH base AS (
SELECT
c.id_cliente, c.nombre, c.clase_riesgo,
COUNT(ca.id_caso) AS total_casos,
SUM(CASE WHEN ca.dias_ausencia > 15
THEN 1 ELSE 0 END) AS casos_graves,
SUM(ca.costo) AS costo_total,
AVG(f.trabajadores_activos) AS trabajadores_prom
FROM clientes c
LEFT JOIN casos ca ON c.id_cliente = ca.id_cliente
AND ca.fecha_ocurrencia >= DATEADD(month,-12,CURRENT_DATE)
LEFT JOIN facturacion f ON c.id_cliente = f.id_cliente
AND f.periodo >= DATEADD(month,-6,CURRENT_DATE)
WHERE c.estado = 'activo'
GROUP BY c.id_cliente, c.nombre, c.clase_riesgo
)
SELECT *,
ROUND(casos_graves*100.0/NULLIF(total_casos,0),1) AS pct_graves,
ROUND(costo_total/NULLIF(trabajadores_prom,0),0) AS costo_x_trab,
DENSE_RANK() OVER (PARTITION BY clase_riesgo
ORDER BY costo_total DESC) AS ranking_clase
FROM base WHERE total_casos > 0 ORDER BY costo_total DESC



--Query Corregido

WITH casos_agg AS (
    SELECT
        id_cliente,
        COUNT(id_caso) AS total_casos,
        SUM(CASE WHEN dias_ausencia > 15 THEN 1 ELSE 0 END) AS casos_graves,
        SUM(costo) AS costo_total
    FROM casos
    WHERE fecha_ocurrencia >= DATEADD(month, -12, CAST(GETDATE() AS DATE))
    GROUP BY id_cliente
),
facturacion_agg AS (
    SELECT id_cliente, AVG(trabajadores_activos * 1.0) AS trabajadores_prom
    FROM facturacion
    WHERE periodo >= DATEADD(month, -6, CAST(GETDATE() AS DATE))
    GROUP BY id_cliente
)
SELECT
    c.id_cliente, c.nombre, c.clase_riesgo,
    COALESCE(ca.total_casos, 0)   AS total_casos,
    COALESCE(ca.casos_graves, 0)  AS casos_graves,
    COALESCE(ca.costo_total, 0)   AS costo_total,
    f.trabajadores_prom,
    ROUND(COALESCE(ca.casos_graves, 0) * 100.0 / NULLIF(ca.total_casos, 0), 1) AS pct_graves,
    ROUND(COALESCE(ca.costo_total, 0) / NULLIF(f.trabajadores_prom, 0), 0)     AS costo_x_trab,
    DENSE_RANK() OVER (PARTITION BY c.clase_riesgo ORDER BY COALESCE(ca.costo_total, 0) DESC) AS ranking_clase
FROM clientes c
LEFT JOIN casos_agg ca ON ca.id_cliente = c.id_cliente
LEFT JOIN facturacion_agg f ON f.id_cliente = c.id_cliente
WHERE c.estado = 'activo' AND COALESCE(ca.total_casos, 0) > 0
ORDER BY costo_total DESC;


