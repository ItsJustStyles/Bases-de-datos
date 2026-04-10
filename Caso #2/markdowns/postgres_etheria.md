- Database engine: PostgreSQL 18
- Database name: etheria_global_db
- Context: Sistema encargado de una cadena de suministro. Donde se importan productos naturales y curativos exóticos de todo el mundo (bebidas, alimentos, cosmética dermatológica, capilar, aromaterapia, jabones y aceites esenciales).

# Tables

## Countries

- country_id
  - tipo: serial
  - pk: si
  - descripcion: identificador único del país

- country_name
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del país de origen del proveedor o producto

- iso_code
  - tipo: char(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: codigo que identifica a un pais, ej: (CRC, NIC, USA)

- region
  - tipo: varchar(100)
  - pk: no
  - descripcion: región geográfica del país (ej: América Central, Sudamérica, Asia)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Suppliers

- supplier_id
  - tipo: serial
  - pk: si
  - descripcion: identificador único del proveedor

- supplier_name
  - tipo: varchar(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre o razón social del proveedor

- contact_name
  - tipo: varchar(100)
  - pk: no
  - descripcion: nombre del contacto principal del proveedor

- contact_email
  - tipo: varchar(150)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: correo electrónico del contacto del proveedor

- contact_phone
  - tipo: varchar(30)
  - pk: no
  - descripcion: teléfono del contacto del proveedor

- country_id
  - tipo: integer (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de origen del proveedor

- address
  - tipo: varchar(255)
  - pk: no
  - descripcion: dirección física del proveedor

- is_active
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si el proveedor está activo o fue deshabilitado

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Categories_products

- category_product_id
  - tipo: serial
  - pk: si
  - descripcion: identificador de las categorías de los productos

- category_name
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: el nombre de la categoría del producto

- category_description
  - tipo: varchar(200)
  - pk: no
  - descripcion: descripción detallada de la categoría

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## MeasurementUnits

- measurementUnitId
  - tipo: serial
  - pk: si
  - descripcion: indicador de las unidades de medida

- unitName
  - tipo: varchar(20)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la unidad de medida (ej: kg, L, ml, unidades)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Individual_product

- individual_product_id
  - tipo: serial
  - pk: si
  - descripcion: identificador de los productos individuales

- name
  - tipo: varchar(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre genérico del producto

- category_product_id
  - tipo: integer (FK -> Categories_products.category_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: categoría del producto

- base_unit_measurementUnitId
  - tipo: integer (FK -> MeasurementUnits.measurementUnitId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: unidad de medida base en la que se vende/empaca el producto individualmente

- unit_volume_m3
  - tipo: DECIMAL(10, 6)
  - pk: no
  - descripcion: volumen que ocupa una unidad individual del producto en metros cúbicos

- unit_weight_kg
  - tipo: DECIMAL(10, 4)
  - pk: no
  - descripcion: peso de una unidad individual del producto en kilogramos

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Characteristics_product

- characteristics_product_id
  - tipo: serial
  - pk: si
  - descripcion: identificador de las características de los productos

- individual_product_id
  - tipo: integer (FK -> Individual_product.individual_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: referencia al producto individual

- characteristic_type
  - tipo: varchar(50)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: el tipo de característica (ej: aroma, ingrediente, beneficio, textura, color)

- characteristic_value
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: el valor para el tipo de característica (ej: lavanda, vitamina C, hidratante)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Products_bulk

- products_bulk_id
  - tipo: serial
  - pk: si
  - descripcion: identificador del bulk de los productos

- individual_product_id
  - tipo: integer (FK -> Individual_product.individual_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: productos individuales que componen el bulk

- supplier_id
  - tipo: integer (FK -> Suppliers.supplier_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: a quien se le compró el bulk

- quantity_bulk
  - tipo: Decimal(10, 3)
  - pk: no
  - restriccion: NOT NULL, CHECK (quantity_bulk > 0)
  - descripcion: la cantidad granel del producto del bulk

- measurementUnitId
  - tipo: integer (FK -> MeasurementUnits.measurementUnitId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: la unidad en la que está el granel del producto

- price_bulk
  - tipo: Decimal(12, 2)
  - pk: no
  - restriccion: NOT NULL, CHECK (price_bulk >= 0)
  - descripcion: precio de un bulk de productos en dólares (USD)

- origin_country_id
  - tipo: integer (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de origen de un bulk de productos

- weight_bulk
  - tipo: Decimal(10, 3)
  - pk: no
  - restriccion: CHECK (weight_bulk > 0)
  - descripcion: el peso total del bulk en kilogramos

- volume_bulk
  - tipo: DECIMAL(10, 4)
  - pk: no
  - restriccion: CHECK (volume_bulk > 0)
  - descripcion: el volumen que ocupa el bulk en metros cúbicos

- arrival_date
  - tipo: Timestamp
  - pk: no
  - descripcion: fecha y hora en la que llegó el bulk al HUB de Nicaragua

- status
  - tipo: varchar(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'EN_TRANSITO', CHECK (status IN ('EN_TRANSITO', 'RECIBIDO', 'EN_ALMACEN', 'DESPACHADO', 'CANCELADO'))
  - descripcion: estado actual del bulk en la cadena de suministro

- import_duty_usd
  - tipo: Decimal(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: monto pagado en aranceles de importación en dólares (USD)

- freight_cost_usd
  - tipo: Decimal(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo de flete internacional del bulk en dólares (USD)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: indica si el registro fue borrado

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora en la que se registró el bulk

## Import_permits

- import_permit_id
  - tipo: serial
  - pk: si
  - descripcion: identificador único del permiso de importación

- products_bulk_id
  - tipo: integer (FK -> Products_bulk.products_bulk_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: bulk al que pertenece el permiso

- permit_type
  - tipo: varchar(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de permiso (ej: sanitario, fitosanitario, aduanero, INVIMA)

- permit_number
  - tipo: varchar(80)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: número o código oficial del permiso emitido por la entidad reguladora

- issuing_authority
  - tipo: varchar(150)
  - pk: no
  - descripcion: nombre de la entidad que emitió el permiso

- issue_date
  - tipo: date
  - pk: no
  - descripcion: fecha de emisión del permiso

- expiry_date
  - tipo: date
  - pk: no
  - descripcion: fecha de vencimiento del permiso

- permit_cost_usd
  - tipo: Decimal(10, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo pagado para obtener el permiso en dólares (USD)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Inventory_hub

- inventory_hub_id
  - tipo: serial
  - pk: si
  - descripcion: identificador del registro de inventario en el HUB de Nicaragua

- individual_product_id
  - tipo: integer (FK -> Individual_product.individual_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto individual registrado en inventario

- products_bulk_id
  - tipo: integer (FK -> Products_bulk.products_bulk_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: bulk del que provienen las unidades en inventario

- quantity_available
  - tipo: Decimal(12, 3)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK (quantity_available >= 0)
  - descripcion: cantidad de unidades disponibles en el HUB para despacho

- quantity_reserved
  - tipo: Decimal(12, 3)
  - pk: no
  - restriccion: DEFAULT 0, CHECK (quantity_reserved >= 0)
  - descripcion: cantidad de unidades reservadas para órdenes pendientes de Dynamic Brands

- cost_per_unit_usd
  - tipo: Decimal(12, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario calculado del producto en USD (incluye flete y aranceles prorrateados)

- last_restock_date
  - tipo: timestamp
  - pk: no
  - descripcion: fecha y hora del último reabastecimiento de este producto

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Dispatch_orders

- dispatch_order_id
  - tipo: serial
  - pk: si
  - descripcion: identificador de la orden de despacho generada por una solicitud de Dynamic Brands

- dynamic_brands_order_id
  - tipo: integer
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID de la orden originada en Dynamic Brands (llave foránea lógica para poder integrar la base de datos de dynamic brands)

- individual_product_id
  - tipo: integer (FK -> Individual_product.individual_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto individual a despachar

- inventory_hub_id
  - tipo: integer (FK -> Inventory_hub.inventory_hub_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: registro de inventario del que se descuenta el despacho

- quantity_dispatched
  - tipo: Decimal(12, 3)
  - pk: no
  - restriccion: NOT NULL, CHECK (quantity_dispatched > 0)
  - descripcion: cantidad de unidades despachadas al HUB de etiquetado

- dispatch_date
  - tipo: timestamp
  - pk: no
  - descripcion: fecha y hora en que se ejecutó el despacho

- destination_country_id
  - tipo: integer (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país destino final del despacho

- status
  - tipo: varchar(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'EN_ETIQUETADO', 'LISTO_COURIER', 'ENTREGADO_COURIER', 'CANCELADO'))
  - descripcion: estado actual de la orden de despacho

- unit_cost_usd
  - tipo: Decimal(12, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario del producto al momento del despacho en USD (snapshot para trazabilidad)

- is_deleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Exchange_rates

- exchange_rate_id
  - tipo: serial
  - pk: si
  - descripcion: identificador del registro de tipo de cambio

- country_id
  - tipo: integer (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país cuya moneda local se está registrando

- currency_code
  - tipo: char(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda (ej: CRC, NIO, USD)

- rate_to_usd
  - tipo: Decimal(18, 6)
  - pk: no
  - restriccion: NOT NULL, CHECK (rate_to_usd > 0)
  - descripcion: tasa de conversión de la moneda local a USD (1 moneda local = X USD)

- rate_date
  - tipo: date
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que aplica esta tasa de cambio

- source
  - tipo: varchar(100)
  - pk: no
  - descripcion: fuente de la tasa (ej: Banco Central)

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Process_log

- log_id
  - tipo: bigserial
  - pk: si
  - descripcion: identificador único del evento de log

- sp_name
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del stored procedure que generó el log

- action_description
  - tipo: varchar(255)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del paso ejecutado o el error ocurrido

- affected_table
  - tipo: varchar(100)
  - pk: no
  - descripcion: tabla afectada por la operación registrada

- affected_record_id
  - tipo: integer
  - pk: no
  - descripcion: ID del registro afectado en la tabla destino

- status
  - tipo: varchar(20)
  - pk: no
  - restriccion: NOT NULL, CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR'))
  - descripcion: nivel del evento registrado

- error_detail
  - tipo: text
  - pk: no
  - descripcion: detalle técnico del error capturado en el bloque EXCEPTION (SQLERRM)

- executed_at
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se ejecutó el paso registrado

- session_user_pg
  - tipo: varchar(100)
  - pk: no
  - restriccion: DEFAULT current_user
  - descripcion: usuario de base de datos que ejecutó el SP