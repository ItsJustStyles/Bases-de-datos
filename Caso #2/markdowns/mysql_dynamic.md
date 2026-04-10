- Database engine: MySQL 8.4
- Database name: dynamic_brands_db
- Context: Sistema de retail digital impulsado por IA. Gestiona sitios de e-commerce con marca blanca (white label) en distintos países de Latam, recibiendo demanda del consumidor final y coordinando las órdenes de productos hacia Etheria Global para su despacho desde el HUB en Nicaragua.

# Tables

## Countries

- country_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del país

- country_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del país donde opera o puede operar una tienda (ej: Colombia, Perú, México)

- iso_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: codigo que identifica a un pais, ej: (CRC, NIC, USA)

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda local (ej: CRC, NIO, USD)

- currency_symbol
  - tipo: VARCHAR(5)
  - pk: no
  - descripcion: símbolo de la moneda local (ej: $)

- tax_rate_percent
  - tipo: DECIMAL(5, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: porcentaje de impuesto al consumidor final aplicable en el país (IVA, IGV, etc.)

- regulatory_notes
  - tipo: TEXT
  - pk: no
  - descripcion: notas sobre requisitos legales o sanitarios para la venta de productos de salud y belleza en el país

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el país está activo para apertura de nuevas tiendas

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Brands

- brand_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la marca blanca generada por la IA

- brand_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial de la marca blanca

- brand_focus
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: enfoque o nicho de mercado de la marca (ej: cosmética natural, nutrición deportiva)

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si la marca está activa y en uso

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Websites

- website_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del sitio web de e-commerce

- brand_id
  - tipo: INT UNSIGNED (FK -> Brands.brand_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: marca blanca asociada al sitio web

- country_id
  - tipo: INT UNSIGNED (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país donde opera este sitio web

- site_url
  - tipo: VARCHAR(500)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: URL del sitio web de e-commerce desplegado

- marketing_focus
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: enfoque de marketing particular de este sitio 

- launch_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha en que el sitio fue desplegado

- close_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha en que el sitio fue cerrado (NULL si está activo)

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Product_catalog

- catalog_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto en el catálogo de Dynamic Brands

- etheria_individual_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID del producto individual en Etheria Global

- brand_id
  - tipo: INT UNSIGNED (FK -> Brands.brand_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: marca blanca bajo la que se vende este producto

- branded_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial del producto bajo la marca blanca

- branded_description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción de marketing generada por la IA para este producto bajo esta marca

- branded_image_url
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL de la imagen del producto con el etiquetado de la marca blanca

- category_label
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: nombre de categoría usado en el sitio 

- health_claims
  - tipo: TEXT
  - pk: no
  - descripcion: propiedades medicinales y beneficios de salud comunicados al consumidor, adaptados por país y marca

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está activo en catálogo

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Website_products

- website_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la relación entre un sitio web y un producto del catálogo

- website_id
  - tipo: INT UNSIGNED (FK -> Websites.website_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: sitio web donde se publica el producto

- catalog_product_id
  - tipo: INT UNSIGNED (FK -> Product_catalog.catalog_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto del catálogo publicado en el sitio

- sale_price_local
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL, CHECK (sale_price_local > 0)
  - descripcion: precio de venta del producto en la moneda local del país del sitio

- is_featured
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si el producto es destacado en el sitio

- stock_display
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: unidades disponibles en el sitio para mostrar al comprador (depende del stock de etheria)

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está activo y visible en el sitio

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Customers

- customer_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del cliente

- first_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del cliente

- last_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: apellido del cliente

- email
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: correo electrónico del cliente

- phone
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: teléfono de contacto del cliente

- country_id
  - tipo: INT UNSIGNED (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de residencia del cliente

- shipping_address
  - tipo: VARCHAR(300)
  - pk: no
  - descripcion: dirección de envío principal del cliente

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Orders

- order_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la orden de compra del cliente

- customer_id
  - tipo: INT UNSIGNED (FK -> Customers.customer_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cliente que realizó la orden

- website_id
  - tipo: INT UNSIGNED (FK -> Websites.website_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: sitio web en el que se realizó la compra

- order_date
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora en que se realizó la orden

- total_amount_local
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: monto total de la orden en la moneda local del país del sitio

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda en que se realizó la venta

- exchange_rate_to_usd
  - tipo: DECIMAL(18, 6)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de cambio vigente al momento de la venta 

- total_amount_usd
  - tipo: DECIMAL(14, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: monto total de la orden convertido a USD al momento de la venta

- shipping_address
  - tipo: VARCHAR(300)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: dirección de entrega específica para esta orden

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'CONFIRMADA', 'EN_PREPARACION', 'ENVIADA', 'ENTREGADA', 'CANCELADA', 'REEMBOLSADA'))
  - descripcion: estado actual de la orden

- etheria_dispatch_order_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID de la orden de despacho en Etheria Global (depende de etheria)

- courier_tracking_code
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: código de rastreo asignado por el courier service externo

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Order_items

- order_item_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del ítem dentro de una orden

- order_id
  - tipo: INT UNSIGNED (FK -> Orders.order_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: orden a la que pertenece este ítem

- website_product_id
  - tipo: INT UNSIGNED (FK -> Website_products.website_product_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto publicado en el sitio que fue comprado

- quantity
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, CHECK (quantity > 0)
  - descripcion: cantidad de unidades compradas

- unit_price_local
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: precio unitario en moneda local al momento de la compra 

- subtotal_local
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: subtotal del ítem en moneda local 

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Shipping_records

- shipping_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de envío

- order_id
  - tipo: INT UNSIGNED (FK -> Orders.order_id)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: orden asociada al envío

- courier_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del courier service externo responsable del envío (tercero)

- tracking_code
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: código de rastreo del envío asignado por el courier

- shipping_cost_local
  - tipo: DECIMAL(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo del envío cobrado al cliente en moneda local

- estimated_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de entrega al cliente final

- actual_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha real de entrega al cliente final

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'RETIRADO_HUB', 'EN_TRANSITO', 'EN_ADUANA', 'ENTREGADO', 'FALLIDO'))
  - descripcion: estado actual del envío

- destination_country_id
  - tipo: INT UNSIGNED (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de destino del envío

- health_permit_number
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número del permiso sanitario requerido para la importación en el país destino

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Exchange_rates

- exchange_rate_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador del registro de tipo de cambio

- country_id
  - tipo: INT UNSIGNED (FK -> Countries.country_id)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país cuya moneda local se está registrando

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda (ej: CRC, NIO, USD)

- rate_to_usd
  - tipo: DECIMAL(18, 6)
  - pk: no
  - restriccion: NOT NULL, CHECK (rate_to_usd > 0)
  - descripcion: tasa de conversión de la moneda local a USD

- rate_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que aplica esta tasa de cambio

- source
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: fuente de la tasa (ej: Banco Central)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Process_log

- log_id
  - tipo: BIGINT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del evento de log

- sp_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del stored procedure que generó el log

- action_description
  - tipo: TEXT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del paso ejecutado o el error ocurrido

- affected_table
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: tabla afectada por la operación registrada

- affected_record_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del registro afectado en la tabla destino

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR'))
  - descripcion: nivel del evento registrado

- error_detail
  - tipo: TEXT
  - pk: no
  - descripcion: detalle técnico del error capturado en el bloque DECLARE HANDLER (mensaje de condición MySQL)

- executed_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se ejecutó el paso registrado

- db_user
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: DEFAULT (CURRENT_USER())
  - descripcion: usuario de base de datos que ejecutó el SP