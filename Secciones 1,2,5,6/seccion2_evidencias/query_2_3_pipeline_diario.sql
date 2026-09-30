-- =====================================================================
--Pregunta 2.3 (15 puntos) — Pipeline de datos
--Construya una consulta SQL base para un pipeline diario que alimenta el tablero ejecutivo. Debe calcular para cada
--cliente activo, a corte del día anterior:
--· Total de casos del mes en curso y variación vs el mes anterior
--· Tasa de incidencia: (casos del mes / trabajadores activos) * 100
--· Actividades de prevención realizadas en los últimos 30 días
--· Clasificación: 'crítico' si tasa > 5, 'moderado' si entre 2 y 5, 'bajo' si menor a 2
-- =====================================================================

Use Prueba_Tecnica_Sura;


WITH corte AS (
    
    SELECT DATEADD(day, -1, CAST(GETDATE() AS DATE)) AS fecha_corte
),

mes_actual AS (
    SELECT
        c.id_cliente,
        COUNT(ca.id_caso) AS casos_mes_actual
    FROM clientes c
    CROSS JOIN corte
    LEFT JOIN casos ca
        ON ca.id_cliente = c.id_cliente
       AND ca.fecha_ocurrencia >= DATEFROMPARTS(YEAR(corte.fecha_corte), MONTH(corte.fecha_corte), 1)
       AND ca.fecha_ocurrencia <= corte.fecha_corte
    WHERE c.estado = 'activo'
    GROUP BY c.id_cliente
),

mes_anterior AS (
    SELECT
        c.id_cliente,
        COUNT(ca.id_caso) AS casos_mes_anterior
    FROM clientes c
    CROSS JOIN corte
    LEFT JOIN casos ca
        ON ca.id_cliente = c.id_cliente
       AND ca.fecha_ocurrencia >= DATEFROMPARTS(YEAR(DATEADD(month,-1,corte.fecha_corte)), MONTH(DATEADD(month,-1,corte.fecha_corte)), 1)
       AND ca.fecha_ocurrencia <  DATEFROMPARTS(YEAR(corte.fecha_corte), MONTH(corte.fecha_corte), 1)
    WHERE c.estado = 'activo'
    GROUP BY c.id_cliente
),

trabajadores_activos AS (
  
    SELECT
        f.id_cliente,
        f.trabajadores_activos
    FROM facturacion f
    WHERE f.periodo = (
        SELECT MAX(f2.periodo)
        FROM facturacion f2
        WHERE f2.id_cliente = f.id_cliente
    )
),

prevencion_30d AS (
    SELECT
        p.id_cliente,
        COUNT(p.id_actividad) AS actividades_prevencion_30d
    FROM prevencion p
    CROSS JOIN corte
    WHERE p.fecha >= DATEADD(day, -30, corte.fecha_corte)
      AND p.fecha <= corte.fecha_corte
    GROUP BY p.id_cliente
)

SELECT
    c.id_cliente,
    c.nombre,
    corte.fecha_corte,
    COALESCE(ma.casos_mes_actual, 0) AS casos_mes_actual,
    COALESCE(ma.casos_mes_actual, 0) - COALESCE(man.casos_mes_anterior, 0) AS variacion_vs_mes_anterior,
    ta.trabajadores_activos,
    ROUND(
        COALESCE(ma.casos_mes_actual, 0) * 100.0 / NULLIF(ta.trabajadores_activos, 0)
    , 2) AS tasa_incidencia,
    COALESCE(p30.actividades_prevencion_30d, 0) AS actividades_prevencion_30d,
    CASE
        WHEN COALESCE(ma.casos_mes_actual, 0) * 100.0 / NULLIF(ta.trabajadores_activos, 0) > 5   THEN 'crítico'
        WHEN COALESCE(ma.casos_mes_actual, 0) * 100.0 / NULLIF(ta.trabajadores_activos, 0) >= 2   THEN 'moderado'
        ELSE 'bajo'
    END AS clasificacion
FROM clientes c
CROSS JOIN corte
LEFT JOIN mes_actual ma          ON ma.id_cliente = c.id_cliente
LEFT JOIN mes_anterior man       ON man.id_cliente = c.id_cliente
LEFT JOIN trabajadores_activos ta ON ta.id_cliente = c.id_cliente
LEFT JOIN prevencion_30d p30     ON p30.id_cliente = c.id_cliente
WHERE c.estado = 'activo';


