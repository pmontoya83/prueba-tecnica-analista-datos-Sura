-- =====================================================================
--Pregunta 2.2 (15 puntos) — Construcción de consulta avanzada
--El equipo necesita cada semana los 15 clientes que más atención prioritaria requieren para planear visitas.
--Construya la consulta SQL usando las tablas del contexto.
-- =====================================================================

Use Prueba_Tecnica_Sura;


WITH casos_recientes AS (
    
    SELECT
        c.id_cliente,
        c.nombre,
        c.clase_riesgo,
        COUNT(ca.id_caso)                                            AS casos_90d,
        SUM(CASE WHEN ca.tipo = 'grave' THEN 1 ELSE 0 END)           AS casos_graves_90d,
        SUM(ca.costo)                                                AS costo_90d
    FROM clientes c
    LEFT JOIN casos ca
        ON ca.id_cliente = c.id_cliente
       AND ca.fecha_ocurrencia >= DATEADD(day, -90, CAST(GETDATE() AS DATE))
    WHERE c.estado = 'activo'
    GROUP BY c.id_cliente, c.nombre, c.clase_riesgo
),

casos_periodo_anterior AS (
   
    SELECT
        id_cliente,
        COUNT(id_caso) AS casos_periodo_anterior
    FROM casos
    WHERE fecha_ocurrencia >= DATEADD(day, -180, CAST(GETDATE() AS DATE))
      AND fecha_ocurrencia <  DATEADD(day, -90,  CAST(GETDATE() AS DATE))
    GROUP BY id_cliente
),

ultima_prevencion AS (
    
    SELECT
        id_cliente,
        MAX(fecha) AS fecha_ultima_prevencion
    FROM prevencion
    GROUP BY id_cliente
)

SELECT TOP 15
    r.id_cliente,
    r.nombre,
    r.clase_riesgo,
    r.casos_90d,
    r.casos_graves_90d,
    r.costo_90d,
    COALESCE(p.casos_periodo_anterior, 0) AS casos_periodo_anterior,
    DATEDIFF(
        day,
        COALESCE(up.fecha_ultima_prevencion, DATEADD(year, -5, CAST(GETDATE() AS DATE))),
        CAST(GETDATE() AS DATE)
    ) AS dias_sin_prevencion,
    ROUND(
        (r.clase_riesgo * 10)
        + (r.casos_graves_90d * 8)
        + (CASE WHEN r.casos_90d > COALESCE(p.casos_periodo_anterior, 0) THEN 10 ELSE 0 END)
        + (CASE WHEN DATEDIFF(
                        day,
                        COALESCE(up.fecha_ultima_prevencion, DATEADD(year, -5, CAST(GETDATE() AS DATE))),
                        CAST(GETDATE() AS DATE)
                    ) > 90 THEN 10 ELSE 0 END)
    , 1) AS score_prioridad
FROM casos_recientes r
LEFT JOIN casos_periodo_anterior p ON p.id_cliente = r.id_cliente
LEFT JOIN ultima_prevencion up ON up.id_cliente = r.id_cliente
ORDER BY score_prioridad DESC;


