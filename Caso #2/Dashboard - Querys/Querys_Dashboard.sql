--Tasa de entrega a tiempo por courier - Circular
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
--Top 10 productos por ingresos USD (mes actual) - Barra Eje y ingresos_usd
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
--Ingresos por país y marca (trimestre) - mapa 
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
--Rotación de inventario mensual - tabla
SELECT
    f.anio, f.mes,
    p.product_name,
    SUM(CASE WHEN fi.movement_type='ENTRADA' THEN fi.quantity ELSE 0 END) AS entradas,
    SUM(CASE WHEN fi.movement_type='SALIDA' THEN fi.quantity ELSE 0 END) AS salidas,
    SUM(CASE WHEN fi.movement_type='AJUSTE' THEN fi.quantity ELSE 0 END) AS ajustes,
    SUM(CASE 
        WHEN fi.movement_type='ENTRADA' THEN fi.quantity 
        WHEN fi.movement_type='SALIDA' THEN -fi.quantity 
        ELSE fi.quantity 
    END) AS balance_neto
FROM dw.fact_inventario fi
JOIN dw.dim_producto p ON fi.producto_sk = p.producto_sk
JOIN dw.dim_fecha f ON fi.fecha_sk = f.fecha_sk
WHERE p.is_current = TRUE
  AND p.producto_sk > 0 
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
    COALESCE(v.ingresos_ventas_usd, 0) AS ingresos_ventas_usd,
    (COALESCE(v.ingresos_ventas_usd, 0) - COALESCE(c.costo_importacion_usd, 0)) AS utilidad_bruta_usd
FROM dw.dim_producto p
LEFT JOIN compras_agg c ON p.producto_sk = c.producto_sk
LEFT JOIN ventas_agg v ON p.producto_sk = v.producto_sk
WHERE p.is_current = TRUE 
  AND p.producto_sk > 0 
ORDER BY utilidad_bruta_usd DESC;
