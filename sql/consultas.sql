-- consultas.sql — Consultas de negocio del SIG de Bob's Coffee
-- Requiere schema.sql + seed.sql. Fecha de corte fija para que los resultados sean reproducibles.
USE bobs_coffee_final;
SET @fecha_corte = '2026-11-14';
SET @dias_ventana = 14;

-- C1. Alerta de stock mínimo (RF06, RF07): insumos en o bajo el umbral
SELECT nombre, unidad_base,
       ROUND(stock_actual, 0) AS stock_actual,
       ROUND(stock_minimo, 0) AS stock_minimo,
       ROUND(stock_actual - stock_minimo, 0) AS holgura
FROM v_stock_actual
ORDER BY (stock_actual / stock_minimo);

-- C2. Sugerencia de reposición (RF08): consumo medio de los últimos 14 días,
--     plazo del proveedor habitual y pedidos en tránsito.
WITH consumo AS (
    SELECT id_insumo, -SUM(variacion_cantidad_base) / @dias_ventana AS consumo_diario
    FROM movimiento_inventario
    WHERE tipo_movimiento IN ('CONSUMO', 'MERMA')
      AND fecha_hora >  DATE_SUB(@fecha_corte, INTERVAL @dias_ventana DAY)
      AND fecha_hora <  DATE_ADD(@fecha_corte, INTERVAL 1 DAY)
    GROUP BY id_insumo
),
plazo AS (                      -- proveedor habitual = menor plazo distinto de 0 (0 = compra de urgencia)
    SELECT id_insumo, MIN(plazo_entrega_dias) AS lead_dias
    FROM insumo_proveedor WHERE plazo_entrega_dias > 0
    GROUP BY id_insumo
),
transito AS (
    SELECT d.id_insumo,
           SUM(d.cantidad_solicitada_base - COALESCE(r.recibido, 0)) AS en_transito
    FROM detalle_orden d
    JOIN orden_compra o ON o.id_orden = d.id_orden
    LEFT JOIN (SELECT id_detalle, SUM(cantidad_recibida_base) AS recibido
               FROM detalle_recepcion GROUP BY id_detalle) r ON r.id_detalle = d.id_detalle
    WHERE o.estado IN ('EMITIDA', 'PARCIAL')
    GROUP BY d.id_insumo
)
SELECT s.nombre, s.unidad_base,
       ROUND(s.stock_actual, 0) AS stock,
       ROUND(COALESCE(t.en_transito, 0), 0) AS en_transito,
       ROUND(c.consumo_diario, 0) AS consumo_diario,
       p.lead_dias,
       ROUND((s.stock_actual + COALESCE(t.en_transito, 0)) / c.consumo_diario, 1) AS dias_cobertura,
       ROUND(s.stock_minimo + c.consumo_diario * p.lead_dias, 0) AS punto_reorden,
       CASE WHEN s.stock_actual + COALESCE(t.en_transito, 0)
                 <= s.stock_minimo + c.consumo_diario * p.lead_dias
            THEN ROUND(s.stock_minimo + c.consumo_diario * (p.lead_dias + 4)
                       - s.stock_actual - COALESCE(t.en_transito, 0), 0)
            ELSE 0 END AS sugerido_pedir   -- cobertura objetivo: plazo + 4 días
FROM v_stock_actual s
JOIN consumo c ON c.id_insumo = s.id_insumo
JOIN plazo p   ON p.id_insumo = s.id_insumo
LEFT JOIN transito t ON t.id_insumo = s.id_insumo
ORDER BY sugerido_pedir > 0 DESC, s.nombre;

-- C3. Compras de urgencia: participación y sobrecosto vs. precio habitual (KPI de costo)
WITH precio_habitual AS (
    SELECT d.id_insumo, SUM(d.cantidad_solicitada_base * d.precio_unitario_base)
                        / SUM(d.cantidad_solicitada_base) AS precio_prom
    FROM detalle_orden d JOIN orden_compra o ON o.id_orden = d.id_orden
    WHERE o.es_urgente = 0 AND o.estado <> 'CANCELADA'
    GROUP BY d.id_insumo
)
SELECT DATE_FORMAT(o.fecha_emision, '%Y-%m') AS mes,
       COUNT(DISTINCT o.id_orden) AS ordenes,
       COUNT(DISTINCT CASE WHEN o.es_urgente = 1 THEN o.id_orden END) AS urgentes,
       ROUND(100 * COUNT(DISTINCT CASE WHEN o.es_urgente = 1 THEN o.id_orden END)
             / COUNT(DISTINCT o.id_orden), 1) AS pct_urgentes,
       ROUND(SUM(CASE WHEN o.es_urgente = 1
                      THEN d.cantidad_solicitada_base * (d.precio_unitario_base - ph.precio_prom) END), 0)
             AS sobrecosto_clp
FROM orden_compra o
JOIN detalle_orden d ON d.id_orden = o.id_orden
JOIN precio_habitual ph ON ph.id_insumo = d.id_insumo
WHERE o.estado <> 'CANCELADA'
GROUP BY mes
ORDER BY mes;

-- C4. Exactitud de inventario por conteo físico (KPI de error)
SELECT i.nombre,
       COUNT(*) AS conteos,
       SUM(dc.cantidad_fisica_base <> dc.cantidad_teorica_antes_base) AS conteos_con_diferencia,
       ROUND(SUM(dc.cantidad_fisica_base - dc.cantidad_teorica_antes_base), 0) AS diferencia_neta,
       ROUND(100 * AVG(ABS(dc.cantidad_fisica_base - dc.cantidad_teorica_antes_base)
                       / NULLIF(dc.cantidad_teorica_antes_base, 0)), 1) AS error_medio_pct
FROM detalle_conteo dc
JOIN insumo i ON i.id_insumo = dc.id_insumo
GROUP BY i.id_insumo, i.nombre
ORDER BY error_medio_pct DESC;

-- C5. Merma valorizada por insumo y motivo (KPI de merma)
WITH precio AS (
    SELECT d.id_insumo, SUM(d.cantidad_solicitada_base * d.precio_unitario_base)
                        / SUM(d.cantidad_solicitada_base) AS precio_prom
    FROM detalle_orden d JOIN orden_compra o ON o.id_orden = d.id_orden
    WHERE o.estado <> 'CANCELADA'
    GROUP BY d.id_insumo
)
SELECT i.nombre, m.motivo,
       COUNT(*) AS registros,
       ROUND(-SUM(m.variacion_cantidad_base), 0) AS cantidad,
       i.unidad_base,
       ROUND(-SUM(m.variacion_cantidad_base) * p.precio_prom, 0) AS costo_clp
FROM movimiento_inventario m
JOIN insumo i ON i.id_insumo = m.id_insumo
JOIN precio p ON p.id_insumo = m.id_insumo
WHERE m.tipo_movimiento = 'MERMA'
GROUP BY i.nombre, m.motivo, i.unidad_base, p.precio_prom
ORDER BY costo_clp DESC;

-- C6. Cumplimiento de proveedores (órdenes no urgentes): cantidad, calidad y plazo, por línea de orden
WITH linea AS (
    SELECT o.id_orden, o.id_proveedor, d.id_detalle, d.cantidad_solicitada_base AS solicitada,
           SUM(dr.cantidad_recibida_base) AS recibida,
           SUM(dr.cantidad_aceptada_base) AS aceptada,
           DATEDIFF(MIN(r.fecha_hora_recepcion), o.fecha_emision) AS dias_primera_entrega,
           ip.plazo_entrega_dias
    FROM orden_compra o
    JOIN detalle_orden d       ON d.id_orden = o.id_orden
    JOIN detalle_recepcion dr  ON dr.id_detalle = d.id_detalle
    JOIN recepcion r           ON r.id_recepcion = dr.id_recepcion
    JOIN insumo_proveedor ip   ON ip.id_insumo = d.id_insumo AND ip.id_proveedor = o.id_proveedor
    WHERE o.es_urgente = 0
    GROUP BY o.id_orden, o.id_proveedor, d.id_detalle, d.cantidad_solicitada_base,
             o.fecha_emision, ip.plazo_entrega_dias
)
SELECT pr.nombre AS proveedor,
       COUNT(DISTINCT l.id_orden) AS ordenes,
       ROUND(100 * AVG(l.recibida >= l.solicitada), 1) AS pct_lineas_completas,
       ROUND(100 * SUM(l.recibida) / SUM(l.solicitada), 1) AS pct_cantidad_recibida,
       ROUND(100 * SUM(l.aceptada) / SUM(l.recibida), 1) AS pct_aceptado,
       ROUND(AVG(l.dias_primera_entrega - l.plazo_entrega_dias), 2) AS atraso_medio_dias,
       SUM(l.dias_primera_entrega > l.plazo_entrega_dias) AS lineas_atrasadas
FROM linea l
JOIN proveedor pr ON pr.id_proveedor = l.id_proveedor
GROUP BY pr.nombre
ORDER BY atraso_medio_dias DESC;

-- C7. Kardex trazable de un insumo (RF06, RF09): saldo acumulado y responsable
SELECT * FROM (
    SELECT m.fecha_hora, m.tipo_movimiento, u.nombre AS usuario,
           ROUND(m.variacion_cantidad_base, 0) AS variacion,
           ROUND(SUM(m.variacion_cantidad_base)
                 OVER (ORDER BY m.fecha_hora, m.id_movimiento), 0) AS saldo,
           m.motivo
    FROM movimiento_inventario m
    JOIN usuario u ON u.id_usuario = m.id_usuario
    WHERE m.id_insumo = 6                          -- Palta Hass
) k
WHERE k.fecha_hora >= '2026-11-09'                 -- última semana
ORDER BY k.fecha_hora;

-- C8. Órdenes abiertas atrasadas a la fecha de corte (alimenta la alerta n8n y explica compras urgentes)
SELECT o.id_orden, pr.nombre AS proveedor, i.nombre AS insumo, o.fecha_emision, o.estado,
       ip.plazo_entrega_dias,
       DATE_ADD(o.fecha_emision, INTERVAL ip.plazo_entrega_dias DAY) AS fecha_comprometida,
       DATEDIFF(@fecha_corte, DATE_ADD(o.fecha_emision, INTERVAL ip.plazo_entrega_dias DAY)) AS dias_atraso,
       ROUND(d.cantidad_solicitada_base - COALESCE(SUM(dr.cantidad_recibida_base), 0), 0) AS pendiente,
       i.unidad_base
FROM orden_compra o
JOIN proveedor pr ON pr.id_proveedor = o.id_proveedor
JOIN detalle_orden d ON d.id_orden = o.id_orden
JOIN insumo i ON i.id_insumo = d.id_insumo
JOIN insumo_proveedor ip ON ip.id_insumo = d.id_insumo AND ip.id_proveedor = o.id_proveedor
LEFT JOIN detalle_recepcion dr ON dr.id_detalle = d.id_detalle
WHERE o.estado IN ('EMITIDA', 'PARCIAL')
GROUP BY o.id_orden, pr.nombre, i.nombre, o.fecha_emision, o.estado, ip.plazo_entrega_dias,
         d.cantidad_solicitada_base, i.unidad_base
HAVING dias_atraso > 0
ORDER BY dias_atraso DESC;
