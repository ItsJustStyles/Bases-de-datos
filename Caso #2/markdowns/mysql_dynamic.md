- Database engine: MySQL 8.4
- Database name: dynamic_brands_db
- Context: Sistema de retail digital impulsado por IA. Gestiona sitios de e-commerce con marca blanca (white label) en distintos países de Latam, recibiendo demanda del consumidor final y coordinando las órdenes de productos hacia Etheria Global para su despacho desde el HUB en Nicaragua.

# Tables

## Countries

- countryId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del país

- countryName
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del país donde opera o puede operar una tienda (ej: Colombia, Perú, México)

- isoCode
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 que identifica al país (ej: CRC, NIC, USA)

- isActive
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el país está activo para apertura de nuevas tiendas

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Currencies

- currencyId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la moneda

- currencyCode
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 4217 de la moneda (ej: CRC, NIO, USD)

- currencySymbol
  - tipo: VARCHAR(5)
  - pk: no
  - descripcion: símbolo visual de la moneda (ej: ₡, C$, $)

- currencyName
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre completo de la moneda (ej: Colón costarricense)

- countryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país al que pertenece esta moneda

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## CountryTaxes

- countryTaxId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de impuesto por país

- countryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país al que aplica este registro de impuesto

- taxRatePercent
  - tipo: DECIMAL(5, 2)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0.00
  - descripcion: porcentaje de impuesto al consumidor final aplicable (IVA, IGV, etc.)

- regulatoryNotes
  - tipo: TEXT
  - pk: no
  - descripcion: notas sobre requisitos legales o sanitarios para la venta de productos de salud y belleza en el país

- validFrom
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha desde la cual aplica este registro de impuesto

- validTo
  - tipo: DATE
  - pk: no
  - descripcion: fecha hasta la cual aplica este registro (NULL si está vigente)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Regions

- regionId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del estado, provincia o región administrativa

- countryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país al que pertenece la región

- regionName
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la región, provincia o estado (ej: San José, Antioquia)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Cities

- cityId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la ciudad

- regionId
  - tipo: INT UNSIGNED (FK -> Regions.regionId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: región administrativa a la que pertenece la ciudad

- cityName
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la ciudad o cantón (ej: Medellín, Desamparados)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Addresses

- addressId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la dirección

- cityId
  - tipo: INT UNSIGNED (FK -> Cities.cityId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ciudad a la que pertenece esta dirección

- addressLine1
  - tipo: VARCHAR(200)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: línea principal de la dirección (calle, número, barrio)

- addressLine2
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: información adicional de la dirección (apartamento, edificio, señas)

- postalCode
  - tipo: VARCHAR(20)
  - pk: no
  - descripcion: código postal de la dirección

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Brands

- brandId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la marca blanca generada por la IA

- brandName
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial de la marca blanca

- brandFocus
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: enfoque o nicho de mercado de la marca (ej: cosmética natural, nutrición deportiva)

- isActive
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si la marca está activa y en uso

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Websites

- websiteId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del sitio web de e-commerce

- brandId
  - tipo: INT UNSIGNED (FK -> Brands.brandId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: marca blanca asociada al sitio web

- countryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país donde opera este sitio web

- siteUrl
  - tipo: VARCHAR(500)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: URL del sitio web de e-commerce desplegado

- marketingFocus
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: enfoque de marketing particular de este sitio

- siteConfig
  - tipo: JSON
  - pk: no
  - descripcion: configuración visual del sitio web generada por la IA (paleta de colores, tipografías, URLs de imágenes, logos y demás estilos)

- launchDate
  - tipo: DATE
  - pk: no
  - descripcion: fecha en que el sitio fue desplegado

- closeDate
  - tipo: DATE
  - pk: no
  - descripcion: fecha en que el sitio fue cerrado (NULL si está activo)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## ProductCatalog

- catalogProductId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto en el catálogo de Dynamic Brands

- etheriaProductId
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID del producto individual en Etheria Global (referencia lógica entre sistemas)

- brandId
  - tipo: INT UNSIGNED (FK -> Brands.brandId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: marca blanca bajo la que se vende este producto

- websiteId
  - tipo: INT UNSIGNED (FK -> Websites.websiteId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: sitio web al que pertenece este producto de catálogo

- brandedName
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial del producto bajo la marca blanca

- brandedDescription
  - tipo: TEXT
  - pk: no
  - descripcion: descripción de marketing generada por la IA para este producto bajo esta marca

- brandedImageUrl
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL de la imagen del producto con el etiquetado de la marca blanca

- categoryLabel
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: nombre de categoría usado en el sitio

- healthClaims
  - tipo: TEXT
  - pk: no
  - descripcion: propiedades medicinales y beneficios de salud comunicados al consumidor, adaptados por país y marca

- isActive
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está activo en catálogo

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## WebsiteProducts

- websiteProductId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la relación entre un sitio web y un producto del catálogo

- websiteId
  - tipo: INT UNSIGNED (FK -> Websites.websiteId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: sitio web donde se publica el producto

- catalogProductId
  - tipo: INT UNSIGNED (FK -> ProductCatalog.catalogProductId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto del catálogo publicado en el sitio

- isFeatured
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si el producto es destacado en el sitio

- isActive
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está activo y visible en el sitio

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## WebsiteProductPrices

- priceId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de precio

- websiteProductId
  - tipo: INT UNSIGNED (FK -> WebsiteProducts.websiteProductId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto en el sitio al que aplica este precio

- salePriceLocal
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL, CHECK (salePriceLocal > 0)
  - descripcion: precio de venta del producto en la moneda local del país del sitio

- currencyId
  - tipo: INT UNSIGNED (FK -> Currencies.currencyId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: moneda en la que está expresado el precio

- validFrom
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha desde la que aplica este precio

- validTo
  - tipo: DATE
  - pk: no
  - descripcion: fecha hasta la que aplica este precio (NULL si es el precio vigente)

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## InventoryDisplay

- inventoryDisplayId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de inventario visible por sitio y producto

- websiteProductId
  - tipo: INT UNSIGNED (FK -> WebsiteProducts.websiteProductId)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: producto publicado en el sitio al que corresponde este inventario

- stockDisplay
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: unidades disponibles a mostrar al comprador (sincronizado desde Etheria)

- lastSyncedAt
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora de la última sincronización con Etheria Global

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación del registro

## Customers

- customerId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del cliente

- firstName
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del cliente

- lastName
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: apellido del cliente

- email
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: correo electrónico del cliente, usado también como login

- passwordHash
  - tipo: VARCHAR(255)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: hash de la contraseña del cliente (bcrypt u otro algoritmo seguro)

- phone
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: teléfono de contacto del cliente

- countryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de residencia del cliente

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## CustomerAddresses

- customerAddressId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la dirección de envío del cliente

- customerId
  - tipo: INT UNSIGNED (FK -> Customers.customerId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cliente propietario de esta dirección

- addressId
  - tipo: INT UNSIGNED (FK -> Addresses.addressId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: dirección asociada al cliente

- alias
  - tipo: VARCHAR(60)
  - pk: no
  - descripcion: nombre identificador de la dirección para el cliente (ej: Casa, Trabajo)

- isDefault
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si esta es la dirección de envío predeterminada del cliente

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## Orders

- orderId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la orden de compra del cliente

- customerId
  - tipo: INT UNSIGNED (FK -> Customers.customerId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cliente que realizó la orden

- websiteId
  - tipo: INT UNSIGNED (FK -> Websites.websiteId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: sitio web en el que se realizó la compra

- customerAddressId
  - tipo: INT UNSIGNED (FK -> CustomerAddresses.customerAddressId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: dirección de envío seleccionada por el cliente para esta orden

- orderDate
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora en que se realizó la orden

- totalAmountLocal
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: monto total de la orden en la moneda local del país del sitio

- currencyId
  - tipo: INT UNSIGNED (FK -> Currencies.currencyId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: moneda en la que se realizó la venta

- exchangeRateId
  - tipo: INT UNSIGNED (FK -> ExchangeRates.exchangeRateId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de cambio vigente al momento de la venta

- exchangeRateSnapshot
  - tipo: DECIMAL(18, 6)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: valor exacto del tipo de cambio al momento de la venta (snapshot para trazabilidad)

- totalAmountUsd
  - tipo: DECIMAL(14, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: monto total de la orden convertido a USD al momento de la venta

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'CONFIRMADA', 'EN_PREPARACION', 'ENVIADA', 'ENTREGADA', 'CANCELADA', 'REEMBOLSADA'))
  - descripcion: estado actual de la orden

- etheriaDispatchOrderId
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID de la orden de despacho en Etheria Global (referencia lógica entre sistemas)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## OrderItems

- orderItemId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del ítem dentro de una orden

- orderId
  - tipo: INT UNSIGNED (FK -> Orders.orderId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: orden a la que pertenece este ítem

- websiteProductId
  - tipo: INT UNSIGNED (FK -> WebsiteProducts.websiteProductId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto publicado en el sitio que fue comprado

- quantity
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, CHECK (quantity > 0)
  - descripcion: cantidad de unidades compradas

- unitPriceLocal
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: precio unitario en moneda local al momento de la compra (snapshot)

- subtotalLocal
  - tipo: DECIMAL(14, 2)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: subtotal del ítem en moneda local (quantity * unitPriceLocal)

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Couriers

- courierId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del courier service

- courierName
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del courier service externo (ej: DHL, FedEx, Correos de Costa Rica)

- contactEmail
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: correo electrónico de contacto del courier

- contactPhone
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: teléfono de contacto del courier

- trackingUrlTemplate
  - tipo: VARCHAR(300)
  - pk: no
  - descripcion: plantilla de URL para rastreo de paquetes (ej: https://courier.com/track/{code})

- isActive
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el courier está activo y disponible para uso

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## ShippingRecords

- shippingId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de envío

- orderId
  - tipo: INT UNSIGNED (FK -> Orders.orderId)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: orden asociada al envío

- courierId
  - tipo: INT UNSIGNED (FK -> Couriers.courierId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: courier service responsable del envío

- trackingCode
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: código de rastreo del envío asignado por el courier

- shippingCostLocal
  - tipo: DECIMAL(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo del envío cobrado al cliente en moneda local

- currencyId
  - tipo: INT UNSIGNED (FK -> Currencies.currencyId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: moneda en la que está expresado el costo del envío

- exchangeRateId
  - tipo: INT UNSIGNED (FK -> ExchangeRates.exchangeRateId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de cambio vigente al momento de registrar el costo del envío

- exchangeRateSnapshot
  - tipo: DECIMAL(18, 6)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: valor exacto del tipo de cambio al momento del registro (snapshot para trazabilidad)

- estimatedDeliveryDate
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de entrega al cliente final

- actualDeliveryDate
  - tipo: DATE
  - pk: no
  - descripcion: fecha real de entrega al cliente final

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'RETIRADO_HUB', 'EN_TRANSITO', 'EN_ADUANA', 'ENTREGADO', 'FALLIDO'))
  - descripcion: estado actual del envío

- destinationCountryId
  - tipo: INT UNSIGNED (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de destino del envío

- healthPermitNumber
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número del permiso sanitario requerido para la importación en el país destino

- isDeleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updatedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

## ExchangeRates

- exchangeRateId
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador del registro de tipo de cambio

- currencyId
  - tipo: INT UNSIGNED (FK -> Currencies.currencyId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: moneda local cuya tasa se está registrando

- rateToUsd
  - tipo: DECIMAL(18, 6)
  - pk: no
  - restriccion: NOT NULL, CHECK (rateToUsd > 0)
  - descripcion: tasa de conversión de la moneda local a USD (1 moneda local = X USD)

- rateDate
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que aplica esta tasa de cambio

- source
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: fuente de la tasa (ej: Banco Central de Costa Rica)

- createdAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## ProcessLog

- logId
  - tipo: BIGINT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del evento de log

- eventSource
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: origen del evento registrado (ej: nombre del trigger, job, módulo de aplicación o proceso)

- eventType
  - tipo: VARCHAR(60)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: categoría o tipo de operación registrada (ej: INSERT, UPDATE, SYNC, PAYMENT)

- affectedTable
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: tabla afectada por la operación registrada

- affectedRecordId
  - tipo: BIGINT UNSIGNED
  - pk: no
  - descripcion: ID del registro afectado en la tabla destino

- description
  - tipo: TEXT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del evento ocurrido o del error capturado

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR'))
  - descripcion: nivel de severidad del evento registrado

- errorDetail
  - tipo: TEXT
  - pk: no
  - descripcion: detalle técnico del error (stack trace, mensaje de condición MySQL u otro contexto de fallo)

- executedAt
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que ocurrió el evento

- dbUser
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: DEFAULT (CURRENT_USER())
  - descripcion: usuario de base de datos que originó el evento