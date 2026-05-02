--  Pregunta: ¿Cuál es la rentabilidad real de una categoría si el costo es en USD y la venta en Pesos Colombianos o Soles Peruanos?
--  Tabla agrupada + filtro variable en category_name.
--   Eje Y: margen_real_pct.
SELECT
    p.category_name  AS categoria,
    pa.country_name  AS pais,
    fv.currency_code AS moneda_venta,

    -- Volumen
    SUM(fv.quantity) AS unidades,

    -- Ingresos en moneda local (como facturado al cliente)
    SUM(fv.subtotal_local) AS ingresos_local,

    -- Ingresos convertidos a USD (usando el tipo de cambio capturado en el ETL)
    ROUND(SUM(fv.subtotal_usd)::NUMERIC, 2)  AS ingresos_usd,

    -- Costo de importación desde Etheria (ya en USD)
    ROUND(SUM(fv.costo_etheria_usd)::NUMERIC, 2)  AS costo_producto_usd,

    -- Costo de envio (USD)
    ROUND(SUM(fv.shipping_cost_usd)::NUMERIC, 2)  AS costo_envio_usd,

    -- Costo total = producto + envío
    ROUND((SUM(fv.costo_etheria_usd) + SUM(fv.shipping_cost_usd))::NUMERIC, 2) AS costo_total_usd,

    -- Margen bruto = ingresos USD − costo total
    ROUND((SUM(fv.subtotal_usd) - SUM(fv.costo_etheria_usd) - SUM(fv.shipping_cost_usd))::NUMERIC, 2)  AS margen_bruto_usd,

    -- Margen % sobre ingresos
    ROUND(100.0 * (SUM(fv.subtotal_usd) - SUM(fv.costo_etheria_usd) - SUM(fv.shipping_cost_usd)) / NULLIF(SUM(fv.subtotal_usd), 0), 1)                                                       AS margen_real_pct,

    -- Tipo de cambio promedio del periodo (referencia)
    ROUND(AVG(fv.exchange_rate_usd)::NUMERIC, 4) AS tipo_cambio_prom

FROM dw.fact_ventas fv
JOIN dw.dim_producto p  ON fv.producto_sk  = p.producto_sk
JOIN dw.dim_pais     pa ON fv.pais_sk      = pa.pais_sk
JOIN dw.dim_fecha    f  ON fv.fecha_sk     = f.fecha_sk
WHERE p.is_current      = TRUE
  AND p.producto_sk     > 0
  -- Si no sale ninguna es porque no hay de estas monedas
  AND fv.currency_code IN ('COP', 'PEN', 'USD')
  AND p.category_name = {{categoria}}
  AND f.anio = 2026
GROUP BY p.category_name, pa.country_name, fv.currency_code
ORDER BY margen_real_pct DESC NULLS LAST;


--  Pregunta: ¿Qué marca generada por IA es más efectiva
--  comparada con los costos de importación?
--
--  Barra agrupada.
--    Eje X: brand_name
--    Eje Y (barras): ingresos_usd / costo_importacion_usd / margen_usd
--    Segunda Y: roi_sobre_importacion_pct (linea)
WITH compras_por_marca AS (
    -- Costo de importación acumulado por producto
    SELECT
        fc.producto_sk,
        SUM(fc.total_landed_usd) AS costo_landed_usd,
        SUM(fc.import_duty_usd)  AS aranceles_usd,
        SUM(fc.freight_cost_usd) AS flete_usd,
        SUM(fc.permit_cost_usd)  AS permisos_usd
    FROM dw.fact_compras fc
    GROUP BY fc.producto_sk
),
ventas_por_marca AS (
    SELECT
        fv.marca_sk,
        fv.producto_sk,
        SUM(fv.subtotal_usd)  AS ingresos_usd,
        SUM(fv.margen_bruto_usd) AS margen_usd,
        SUM(fv.shipping_cost_usd) AS envio_usd,
        COUNT(DISTINCT fv.dynamic_order_id) AS num_ordenes
    FROM dw.fact_ventas fv
    GROUP BY fv.marca_sk, fv.producto_sk
)
SELECT
    m.brand_name,
    m.brand_focus,
    -- Volumen
    SUM(v.num_ordenes)                                         AS total_ordenes,
    -- Financiero
    ROUND(SUM(v.ingresos_usd)::NUMERIC, 2)                    AS ingresos_usd,
    ROUND(SUM(c.costo_landed_usd)::NUMERIC, 2)                AS costo_importacion_usd,
    ROUND(SUM(c.aranceles_usd)::NUMERIC, 2)                   AS aranceles_usd,
    ROUND(SUM(c.flete_usd)::NUMERIC, 2)                       AS flete_usd,
    ROUND(SUM(c.permisos_usd)::NUMERIC, 2)                    AS permisos_usd,
    ROUND(SUM(v.envio_usd)::NUMERIC, 2)                       AS costo_envio_local_usd,
    ROUND(SUM(v.margen_usd)::NUMERIC, 2)                      AS margen_bruto_usd,

    -- Margen neto = margen bruto − envío local (el costo producto ya está en margen_bruto)
    ROUND((SUM(v.margen_usd) - SUM(v.envio_usd))::NUMERIC, 2) AS margen_neto_usd,

    -- ROI sobre la inversión de importación: cuántos $ genera cada $ importado
    ROUND(
        (SUM(v.ingresos_usd) - SUM(c.costo_landed_usd))
        / NULLIF(SUM(c.costo_landed_usd), 0) * 100, 1) AS roi_sobre_importacion_pct,

    -- Margen neto % sobre ingresos
    ROUND(100.0 * (SUM(v.margen_usd) - SUM(v.envio_usd))/ NULLIF(SUM(v.ingresos_usd), 0), 1) AS margen_neto_pct

FROM ventas_por_marca v
JOIN dw.dim_marca m ON v.marca_sk = m.marca_sk
LEFT JOIN compras_por_marca c ON v.producto_sk = c.producto_sk
WHERE m.marca_sk > 0
GROUP BY m.brand_name, m.brand_focus
ORDER BY roi_sobre_importacion_pct DESC NULLS LAST;


--  Pregunta: ¿Cuál es el margen por país considerando los
--  gastos de envío y permisos de importación?
--  Mapa de calor (Metabase world map) con iso_code + tabla de detalle debajo.
--  Campo para mapa: iso_code → valor: margen_neto_pct (hay q cambiar el iso code a 2 letras para hacer esto)
WITH permisos_por_pais AS (
    -- Los permisos de importacion viven en fact_compras + dim_pais (pais origen)
    -- Los asociamos al producto para luego cruzar con ventas por pais destino
    SELECT
        fc.producto_sk,
        SUM(fc.permit_cost_usd)  AS permisos_usd,
        SUM(fc.import_duty_usd)  AS aranceles_usd,
        SUM(fc.total_landed_usd) AS costo_total_importacion
    FROM dw.fact_compras fc
    GROUP BY fc.producto_sk
)
SELECT
    pa.country_name,
    pa.iso_code,

    -- Volumen
    COUNT(DISTINCT fv.dynamic_order_id) AS num_ordenes,
    SUM(fv.quantity) AS unidades_vendidas,

    -- Ingresos
    ROUND(SUM(fv.subtotal_usd)::NUMERIC, 2) AS ingresos_usd,

    -- Costos desagregados
    ROUND(SUM(fv.costo_etheria_usd)::NUMERIC, 2) AS costo_producto_usd,
    ROUND(SUM(fv.shipping_cost_usd)::NUMERIC, 2) AS costo_envio_usd,

    -- Permisos e impuestos prorrateados por país destino
    -- (distribuido proporcional a las unidades vendidas en ese país
    --  respecto al total de unidades vendidas)
    ROUND(
        SUM(fv.quantity::NUMERIC/ NULLIF(tot.total_qty, 0) * COALESCE(pp.permisos_usd, 0))::NUMERIC, 2)                                         AS permisos_prorrateados_usd,

    ROUND(
        SUM(
            fv.quantity::NUMERIC/ NULLIF(tot.total_qty, 0)* COALESCE(pp.aranceles_usd, 0))::NUMERIC, 2) AS aranceles_prorrateados_usd,

    -- Margen bruto (sin considerar envío ni permisos)
    ROUND(SUM(fv.margen_bruto_usd)::NUMERIC, 2) AS margen_bruto_usd,

    -- Margen operativo = ingresos − producto − envío − permisos − aranceles
    ROUND(
        (SUM(fv.subtotal_usd)- SUM(fv.costo_etheria_usd)- SUM(fv.shipping_cost_usd)- SUM(fv.quantity::NUMERIC / NULLIF(tot.total_qty, 0) * COALESCE(pp.permisos_usd, 0))
         - SUM(fv.quantity::NUMERIC / NULLIF(tot.total_qty, 0) * COALESCE(pp.aranceles_usd, 0)))::NUMERIC, 2)                                         AS margen_operativo_usd,

    -- Margen % operativo
    ROUND(100.0 * (SUM(fv.subtotal_usd)- SUM(fv.costo_etheria_usd) - SUM(fv.shipping_cost_usd)- SUM(fv.quantity::NUMERIC / NULLIF(tot.total_qty, 0) * COALESCE(pp.permisos_usd, 0))
         - SUM(fv.quantity::NUMERIC / NULLIF(tot.total_qty, 0) * COALESCE(pp.aranceles_usd, 0))) / NULLIF(SUM(fv.subtotal_usd), 0), 1)                                                       AS margen_neto_pct,

    -- Moneda predominante en ese país
    MODE() WITHIN GROUP (ORDER BY fv.currency_code) AS moneda_principal

FROM dw.fact_ventas fv
JOIN dw.dim_pais pa ON fv.pais_sk = pa.pais_sk
-- Total de unidades por producto (para prorrateo)
JOIN (
    SELECT producto_sk, SUM(quantity) AS total_qty
    FROM dw.fact_ventas
    GROUP BY producto_sk
) tot ON fv.producto_sk = tot.producto_sk
LEFT JOIN permisos_por_pais pp ON fv.producto_sk = pp.producto_sk
WHERE pa.pais_sk > 0
GROUP BY pa.country_name, pa.iso_code
ORDER BY margen_neto_pct DESC NULLS LAST;



--  Complemento de la respuesta a la pregunta 3: version de serie de tiempo para ver
--  tendencias de rentabilidad por país mes a mes.
--  Línea, X = periodo, Y = margen_neto_pct,
--  series = country_name.
SELECT
    f.anio,
    f.mes,
    TO_CHAR(DATE_TRUNC('month', f.fecha), 'YYYY-MM') AS periodo,
    pa.country_name,
    pa.iso_code,
    ROUND(SUM(fv.subtotal_usd)::NUMERIC, 2) AS ingresos_usd,
    ROUND(SUM(fv.costo_etheria_usd)::NUMERIC, 2) AS costo_producto_usd,
    ROUND(SUM(fv.shipping_cost_usd)::NUMERIC, 2) AS costo_envio_usd,
    ROUND(SUM(fv.margen_bruto_usd)::NUMERIC, 2) AS margen_bruto_usd,
    ROUND((SUM(fv.subtotal_usd) - SUM(fv.costo_etheria_usd) - SUM(fv.shipping_cost_usd))::NUMERIC, 2)                                      AS margen_neto_usd,
    ROUND(100.0 * (SUM(fv.subtotal_usd) - SUM(fv.costo_etheria_usd) - SUM(fv.shipping_cost_usd))/ NULLIF(SUM(fv.subtotal_usd), 0), 1)                                                   AS margen_neto_pct
FROM dw.fact_ventas fv
JOIN dw.dim_pais pa ON fv.pais_sk  = pa.pais_sk
JOIN dw.dim_fecha f ON fv.fecha_sk = f.fecha_sk
WHERE pa.pais_sk > 0
  AND fv.costo_etheria_usd IS NOT NULL
GROUP BY f.anio, f.mes, f.fecha, pa.country_name, pa.iso_code
ORDER BY f.anio, f.mes, pa.country_name;



--  Una fila con los principales números del periodo.
--  6 metricas individuales (el que dice number en el meta base)
--  Usar una por tarjeta, todas apuntando a este mismo query con distinto campo seleccionado.
SELECT
    -- Ingresos
    ROUND(SUM(fv.subtotal_usd)::NUMERIC, 2) AS ingresos_totales_usd,

    -- Costo total (producto + envío)
    ROUND((SUM(fv.costo_etheria_usd) + SUM(fv.shipping_cost_usd))::NUMERIC, 2) AS costos_totales_usd,

    -- Margen bruto (como calculado en ETL, antes de envío)
    ROUND(SUM(fv.margen_bruto_usd)::NUMERIC, 2) AS margen_bruto_usd,

    -- Margen neto (restando envío)
    ROUND((SUM(fv.margen_bruto_usd) - SUM(fv.shipping_cost_usd))::NUMERIC, 2) AS margen_neto_usd,

    -- Margen neto %
    ROUND(100.0 * (SUM(fv.margen_bruto_usd) - SUM(fv.shipping_cost_usd))/ NULLIF(SUM(fv.subtotal_usd), 0), 1)                                                          AS margen_neto_pct,

    -- Órdenes y unidades
    COUNT(DISTINCT fv.dynamic_order_id) AS total_ordenes,
    SUM(fv.quantity) AS unidades_vendidas,

    -- Ticket promedio en USD
    ROUND(SUM(fv.subtotal_usd) / NULLIF(COUNT(DISTINCT fv.dynamic_order_id), 0)::NUMERIC, 2)                                                AS ticket_promedio_usd

FROM dw.fact_ventas fv
JOIN dw.dim_fecha f ON fv.fecha_sk = f.fecha_sk
WHERE f.anio = 2026
  AND fv.producto_sk > 0;


--  queries que teniamos antes

-- Tasa de entrega a tiempo por courier — Gráfico circular
SELECT 
    c.courier_name,
    COUNT(*) AS total_envios,
    SUM(CASE 
        WHEN fv.actual_delivery <= fv.estimated_delivery THEN 1 
        ELSE 0 
    END) AS entregados_a_tiempo,
    ROUND(100.0 * SUM(CASE 
        WHEN fv.actual_delivery <= fv.estimated_delivery THEN 1 
        ELSE 0 
    END) / COUNT(*), 1) AS pct_a_tiempo
FROM dw.fact_ventas fv
JOIN dw.dim_courier c ON fv.courier_sk = c.courier_sk
WHERE fv.actual_delivery IS NOT NULL
GROUP BY c.courier_name
ORDER BY pct_a_tiempo DESC;

-- Top 10 productos por ingresos USD (mes actual) — Barra, eje Y: ingresos_usd
SELECT
    ROW_NUMBER() OVER(ORDER BY SUM(fv.subtotal_usd) DESC) AS ranking,
    p.product_name,
    p.branded_name,
    SUM(fv.subtotal_usd) AS ingresos_usd,
    SUM(fv.margen_bruto_usd) AS margen_usd,
    SUM(fv.quantity) AS unidades_vendidas,
    ROUND(SUM(fv.margen_bruto_usd) / NULLIF(SUM(fv.subtotal_usd), 0) * 100, 1) AS margen_pct
FROM dw.fact_ventas fv
JOIN dw.dim_producto p ON fv.producto_sk = p.producto_sk
JOIN dw.dim_fecha f ON fv.fecha_sk = f.fecha_sk
WHERE f.anio = 2026 
  AND f.mes = 5
  AND p.producto_sk > 0 
GROUP BY p.product_name, p.branded_name
ORDER BY ingresos_usd DESC
LIMIT 10;

-- Ingresos por país y marca (trimestre) — Mapa
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(fv.subtotal_usd) DESC) AS indice,
    pa.country_name,
    pa.iso_code,
    m.brand_name,
    f.trimestre,
    f.anio,
    SUM(fv.subtotal_usd) AS ingresos_usd,
    COUNT(DISTINCT fv.dynamic_order_id) AS num_ordenes
FROM dw.fact_ventas fv
JOIN dw.dim_pais pa ON fv.pais_sk = pa.pais_sk
JOIN dw.dim_marca m ON fv.marca_sk = m.marca_sk
JOIN dw.dim_fecha f ON fv.fecha_sk = f.fecha_sk
WHERE f.anio = 2026
GROUP BY pa.country_name, pa.iso_code, m.brand_name, f.trimestre, f.anio
ORDER BY ingresos_usd DESC;

-- Rotación de inventario mensual — Tabla
SELECT
    f.anio, f.mes,
    p.product_name,
    SUM(CASE WHEN fi.movement_type='ENTRADA' THEN fi.quantity ELSE 0 END) AS entradas,
    SUM(CASE WHEN fi.movement_type='SALIDA'  THEN fi.quantity ELSE 0 END) AS salidas,
    SUM(CASE WHEN fi.movement_type='AJUSTE'  THEN fi.quantity ELSE 0 END) AS ajustes,
    SUM(CASE 
        WHEN fi.movement_type='ENTRADA' THEN  fi.quantity 
        WHEN fi.movement_type='SALIDA'  THEN -fi.quantity 
        ELSE fi.quantity 
    END) AS balance_neto
FROM dw.fact_inventario fi
JOIN dw.dim_producto p ON fi.producto_sk = p.producto_sk
JOIN dw.dim_fecha    f ON fi.fecha_sk    = f.fecha_sk
WHERE p.is_current   = TRUE
  AND p.producto_sk  > 0 
GROUP BY f.anio, f.mes, p.product_name
ORDER BY f.anio DESC, f.mes DESC, p.product_name;

-- Costo de importación vs ingresos por producto
WITH compras_agg AS (
    SELECT 
        producto_sk, 
        SUM(total_landed_usd) AS costo_importacion_usd
    FROM dw.fact_compras
    GROUP BY producto_sk
),
ventas_agg AS (
    SELECT 
        producto_sk, 
        SUM(subtotal_usd) AS ingresos_ventas_usd
    FROM dw.fact_ventas
    GROUP BY producto_sk
)
SELECT
    p.product_name,
    COALESCE(c.costo_importacion_usd, 0) AS costo_importacion_usd,
    COALESCE(v.ingresos_ventas_usd,   0) AS ingresos_ventas_usd,
    (COALESCE(v.ingresos_ventas_usd, 0) - COALESCE(c.costo_importacion_usd, 0)) AS utilidad_bruta_usd
FROM dw.dim_producto p
LEFT JOIN compras_agg c ON p.producto_sk = c.producto_sk
LEFT JOIN ventas_agg  v ON p.producto_sk = v.producto_sk
WHERE p.is_current   = TRUE 
  AND p.producto_sk  > 0 
ORDER BY utilidad_bruta_usd DESC;