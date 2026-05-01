-- ============================================================
--  Data Warehouse — Etheria Global + Dynamic Brands
--  Engine  : PostgreSQL (mismo contenedor data_warehouse)
--  Esquema : dw + etl
--  Ejecutar: conectado a la DB "warehouse"
-- ============================================================

-- ── Crear esquemas ──────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS etl;

-- ============================================================
--  DIMENSIÓN FECHA
--  Se llena con generate_series al final del script
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_fecha (
    fecha_sk        SERIAL      PRIMARY KEY,
    fecha           DATE        NOT NULL UNIQUE,
    anio            SMALLINT    NOT NULL,
    trimestre       SMALLINT    NOT NULL,   -- 1..4
    mes             SMALLINT    NOT NULL,   -- 1..12
    nombre_mes      VARCHAR(15) NOT NULL,
    semana_iso      SMALLINT    NOT NULL,
    dia_mes         SMALLINT    NOT NULL,
    dia_semana      SMALLINT    NOT NULL,   -- 1=Lunes..7=Domingo
    nombre_dia      VARCHAR(12) NOT NULL,
    es_fin_semana   BOOLEAN     NOT NULL DEFAULT FALSE
);

-- Poblar dim_fecha 2020-01-01 → 2030-12-31
INSERT INTO dw.dim_fecha (
    fecha, anio, trimestre, mes, nombre_mes,
    semana_iso, dia_mes, dia_semana, nombre_dia, es_fin_semana
)
SELECT
    d::DATE,
    EXTRACT(YEAR  FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    TO_CHAR(d, 'TMMonth'),
    EXTRACT(ISOYEAR FROM d)::SMALLINT,  -- semana ISO
    EXTRACT(DAY   FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d)::SMALLINT,
    TO_CHAR(d, 'TMDay'),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day') AS d
ON CONFLICT (fecha) DO NOTHING;

-- ============================================================
--  DIMENSIÓN PAÍS
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_pais (
    pais_sk         SERIAL      PRIMARY KEY,
    iso_code        CHAR(3)     NOT NULL UNIQUE,
    country_name    VARCHAR(100) NOT NULL,
    etl_loaded_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Fila "Desconocido" para FKs no resueltas
INSERT INTO dw.dim_pais (pais_sk, iso_code, country_name)
VALUES (-1, 'UNK', 'Desconocido')
ON CONFLICT DO NOTHING;

-- ============================================================
--  DIMENSIÓN PRODUCTO  (SCD Tipo 2)
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_producto (
    producto_sk         SERIAL          PRIMARY KEY,
    etheria_product_id  INTEGER         NOT NULL,
    product_name        VARCHAR(150)    NOT NULL,
    category_name       VARCHAR(100),
    base_unit           VARCHAR(20),
    unit_weight_kg      DECIMAL(10,4),
    unit_volume_m3      DECIMAL(10,6),
    -- Lado Dynamic Brands
    branded_name        VARCHAR(150),
    category_label      VARCHAR(100),
    -- Precio vigente Etheria → Dynamic (USD)
    sale_price_usd      DECIMAL(12,4),
    -- SCD Tipo 2
    valid_from          DATE            NOT NULL DEFAULT CURRENT_DATE,
    valid_to            DATE,
    is_current          BOOLEAN         NOT NULL DEFAULT TRUE,
    etl_loaded_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_producto (producto_sk, etheria_product_id, product_name, is_current)
VALUES (-1, -1, 'Desconocido', TRUE)
ON CONFLICT DO NOTHING;

-- ============================================================
--  DIMENSIÓN CLIENTE  (SCD Tipo 2)
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_cliente (
    cliente_sk          SERIAL          PRIMARY KEY,
    dynamic_cust_id     INTEGER         NOT NULL,
    full_name           VARCHAR(160)    NOT NULL,
    email               VARCHAR(150),
    pais_sk             INTEGER         REFERENCES dw.dim_pais(pais_sk),
    valid_from          DATE            NOT NULL DEFAULT CURRENT_DATE,
    valid_to            DATE,
    is_current          BOOLEAN         NOT NULL DEFAULT TRUE,
    etl_loaded_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_cliente (cliente_sk, dynamic_cust_id, full_name, is_current)
VALUES (-1, -1, 'Desconocido', TRUE)
ON CONFLICT DO NOTHING;

-- ============================================================
--  DIMENSIÓN PROVEEDOR
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_proveedor (
    proveedor_sk            SERIAL          PRIMARY KEY,
    etheria_supplier_id     INTEGER         NOT NULL UNIQUE,
    supplier_name           VARCHAR(150)    NOT NULL,
    pais_sk                 INTEGER         REFERENCES dw.dim_pais(pais_sk),
    is_active               BOOLEAN,
    etl_loaded_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_proveedor (proveedor_sk, etheria_supplier_id, supplier_name)
VALUES (-1, -1, 'Desconocido')
ON CONFLICT DO NOTHING;

-- ============================================================
--  DIMENSIÓN MARCA
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_marca (
    marca_sk            SERIAL          PRIMARY KEY,
    dynamic_brand_id    INTEGER         NOT NULL UNIQUE,
    brand_name          VARCHAR(150)    NOT NULL,
    brand_focus         VARCHAR(100),
    etl_loaded_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_marca (marca_sk, dynamic_brand_id, brand_name)
VALUES (-1, -1, 'Desconocido')
ON CONFLICT DO NOTHING;

-- ============================================================
--  DIMENSIÓN COURIER
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.dim_courier (
    courier_sk          SERIAL          PRIMARY KEY,
    dynamic_courier_id  INTEGER         NOT NULL UNIQUE,
    courier_name        VARCHAR(100)    NOT NULL,
    is_active           BOOLEAN,
    etl_loaded_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_courier (courier_sk, dynamic_courier_id, courier_name)
VALUES (-1, -1, 'Desconocido')
ON CONFLICT DO NOTHING;

-- ============================================================
--  FACT VENTAS
--  Granularidad: 1 fila por ítem de orden
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.fact_ventas (
    venta_sk                BIGSERIAL   PRIMARY KEY,
    -- Dimensiones
    fecha_sk                INTEGER     NOT NULL REFERENCES dw.dim_fecha(fecha_sk),
    producto_sk             INTEGER     NOT NULL REFERENCES dw.dim_producto(producto_sk),
    cliente_sk              INTEGER     NOT NULL REFERENCES dw.dim_cliente(cliente_sk),
    pais_sk                 INTEGER     NOT NULL REFERENCES dw.dim_pais(pais_sk),
    marca_sk                INTEGER     NOT NULL REFERENCES dw.dim_marca(marca_sk),
    courier_sk              INTEGER     REFERENCES dw.dim_courier(courier_sk),
    -- IDs origen (drill-back)
    dynamic_order_id        INTEGER     NOT NULL,
    dynamic_order_item_id   INTEGER     NOT NULL,
    -- Métricas
    quantity                INTEGER     NOT NULL,
    unit_price_local        DECIMAL(14,2) NOT NULL,
    subtotal_local          DECIMAL(14,2) NOT NULL,
    currency_code           CHAR(3)     NOT NULL,
    exchange_rate_usd       DECIMAL(18,6) NOT NULL,
    subtotal_usd            DECIMAL(14,4) NOT NULL,
    costo_etheria_usd       DECIMAL(12,4),
    margen_bruto_usd        DECIMAL(14,4),
    shipping_cost_usd       DECIMAL(12,4) DEFAULT 0,
    -- Estado
    order_status            VARCHAR(30),
    shipping_status         VARCHAR(30),
    estimated_delivery      DATE,
    actual_delivery         DATE,
    etl_loaded_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (dynamic_order_item_id)          -- idempotencia
);

-- ============================================================
--  FACT INVENTARIO
--  Granularidad: 1 fila por movimiento en el HUB de Etheria
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.fact_inventario (
    inv_sk              BIGSERIAL   PRIMARY KEY,
    fecha_sk            INTEGER     NOT NULL REFERENCES dw.dim_fecha(fecha_sk),
    producto_sk         INTEGER     NOT NULL REFERENCES dw.dim_producto(producto_sk),
    movement_type       VARCHAR(20) NOT NULL,   -- ENTRADA / SALIDA / AJUSTE
    quantity            DECIMAL(12,3) NOT NULL,
    cost_per_unit_usd   DECIMAL(12,4) NOT NULL,
    total_cost_usd      DECIMAL(14,4) NOT NULL,
    etheria_hub_id      INTEGER,
    etheria_dispatch_id INTEGER,
    etl_loaded_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (etheria_hub_id)                     -- idempotencia
);

-- ============================================================
--  FACT COMPRAS
--  Granularidad: 1 fila por BulkPurchase de Etheria
-- ============================================================
CREATE TABLE IF NOT EXISTS dw.fact_compras (
    compra_sk           BIGSERIAL   PRIMARY KEY,
    fecha_sk            INTEGER     NOT NULL REFERENCES dw.dim_fecha(fecha_sk),
    producto_sk         INTEGER     NOT NULL REFERENCES dw.dim_producto(producto_sk),
    proveedor_sk        INTEGER     NOT NULL REFERENCES dw.dim_proveedor(proveedor_sk),
    pais_origen_sk      INTEGER     NOT NULL REFERENCES dw.dim_pais(pais_sk),
    quantity_bulk       DECIMAL(10,3) NOT NULL,
    price_bulk_usd      DECIMAL(12,2) NOT NULL,
    import_duty_usd     DECIMAL(12,2) NOT NULL DEFAULT 0,
    freight_cost_usd    DECIMAL(12,2) NOT NULL DEFAULT 0,
    permit_cost_usd     DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_landed_usd    DECIMAL(14,2) NOT NULL,
    bulk_status         VARCHAR(30),
    etheria_bulk_id     INTEGER     NOT NULL,
    etl_loaded_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (etheria_bulk_id)                    -- idempotencia
);

-- ============================================================
--  TABLA AUDIT LOG (esquema etl)
-- ============================================================
CREATE TABLE IF NOT EXISTS etl.audit_log (
    log_id          BIGSERIAL   PRIMARY KEY,
    dag_name        VARCHAR(100) NOT NULL,
    task_name       VARCHAR(100),
    rows_extracted  INTEGER,
    rows_inserted   INTEGER,
    rows_updated    INTEGER,
    rows_rejected   INTEGER,
    run_start       TIMESTAMP   NOT NULL,
    run_end         TIMESTAMP,
    duration_secs   INTEGER,
    status          VARCHAR(20) NOT NULL
        CHECK (status IN ('RUNNING','SUCCESS','WARNING','ERROR')),
    error_message   TEXT,
    created_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  ÍNDICES para rendimiento en consultas BI
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_fv_fecha    ON dw.fact_ventas(fecha_sk);
CREATE INDEX IF NOT EXISTS idx_fv_producto ON dw.fact_ventas(producto_sk);
CREATE INDEX IF NOT EXISTS idx_fv_cliente  ON dw.fact_ventas(cliente_sk);
CREATE INDEX IF NOT EXISTS idx_fv_marca    ON dw.fact_ventas(marca_sk);
CREATE INDEX IF NOT EXISTS idx_fv_pais     ON dw.fact_ventas(pais_sk);
CREATE INDEX IF NOT EXISTS idx_fi_fecha    ON dw.fact_inventario(fecha_sk);
CREATE INDEX IF NOT EXISTS idx_fi_producto ON dw.fact_inventario(producto_sk);
CREATE INDEX IF NOT EXISTS idx_fc_fecha    ON dw.fact_compras(fecha_sk);
CREATE INDEX IF NOT EXISTS idx_fc_prod     ON dw.fact_compras(producto_sk);

-- ============================================================
--  FIN DEL SCRIPT — conectar Metabase al contenedor
--  dwh_central  host: data_warehouse  port: 5432  db: warehouse
--  user: analytics_user  pass: dwh_password
-- ============================================================
