- Database engine: PostgreSQL 18
- Database name: etheria_global_db
- Context: Sistema encargado de una cadena de suministro. Donde se importan productos naturales y curativos exóticos de todo el mundo (bebidas, alimentos, cosmética dermatológica, capilar, aromaterapia, jabones y aceites esenciales).

# Tables

## Countries

- countryId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del país

- countryName
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del país de origen del proveedor o producto

- isoCode
  - tipo: char(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 que identifica al país (ej: CRC, NIC, USA)

- isDeleted
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

## GeographicRegions

- geographicRegionId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la región geográfica mundial

- regionName
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la región geográfica (ej: América Central, Sudamérica, Asia Oriental)

- isDeleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## CountryRegions

- countryRegionId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la relación país-región geográfica

- countryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país asociado a la región

- geographicRegionId
  - tipo: integer (FK -> GeographicRegions.geographicRegionId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: región geográfica a la que pertenece el país

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Currencies

- currencyId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la moneda

- currencyCode
  - tipo: char(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 4217 de la moneda (ej: CRC, NIO, USD)

- currencySymbol
  - tipo: varchar(5)
  - pk: no
  - descripcion: símbolo visual de la moneda (ej: ₡, C$, $)

- currencyName
  - tipo: varchar(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre completo de la moneda (ej: Dólar estadounidense)

- countryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país al que pertenece esta moneda

- isDeleted
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

## AdminRegions

- adminRegionId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la región administrativa (estado, provincia, departamento)

- countryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país al que pertenece la región administrativa

- regionName
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la región administrativa (ej: Antioquia, San José, Jalisco)

- isDeleted
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

## Cities

- cityId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la ciudad

- adminRegionId
  - tipo: integer (FK -> AdminRegions.adminRegionId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: región administrativa a la que pertenece la ciudad

- cityName
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la ciudad o municipio

- isDeleted
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

## Addresses

- addressId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la dirección física

- cityId
  - tipo: integer (FK -> Cities.cityId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ciudad a la que pertenece esta dirección

- addressLine1
  - tipo: varchar(200)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: línea principal de la dirección (calle, número, barrio)

- addressLine2
  - tipo: varchar(200)
  - pk: no
  - descripcion: información adicional de la dirección (oficina, bodega, señas)

- postalCode
  - tipo: varchar(20)
  - pk: no
  - descripcion: código postal de la dirección

- isDeleted
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

## Persons

- personId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la persona (contacto de proveedor, usuario interno u otro rol)

- firstName
  - tipo: varchar(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la persona

- lastName
  - tipo: varchar(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: apellido de la persona

- email
  - tipo: varchar(150)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: correo electrónico de la persona

- phone
  - tipo: varchar(30)
  - pk: no
  - descripcion: teléfono de contacto de la persona

- isDeleted
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

- supplierId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del proveedor

- supplierName
  - tipo: varchar(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre o razón social del proveedor

- primaryContactId
  - tipo: integer (FK -> Persons.personId)
  - pk: no
  - descripcion: persona que actúa como contacto principal del proveedor

- countryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de origen del proveedor

- addressId
  - tipo: integer (FK -> Addresses.addressId)
  - pk: no
  - descripcion: dirección física del proveedor

- isActive
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si el proveedor está activo o fue deshabilitado

- isDeleted
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

## ProductCategories

- categoryId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la categoría de producto

- categoryName
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la categoría del producto (ej: Cosmética Capilar, Aromaterapia)

- categoryDescription
  - tipo: varchar(200)
  - pk: no
  - descripcion: descripción detallada de la categoría

- isDeleted
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

- unitId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la unidad de medida

- unitName
  - tipo: varchar(20)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la unidad de medida (ej: kg, L, ml, unidades)

- isDeleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## Products

- productId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del producto individual

- productName
  - tipo: varchar(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre genérico del producto

- categoryId
  - tipo: integer (FK -> ProductCategories.categoryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: categoría a la que pertenece el producto

- baseUnitId
  - tipo: integer (FK -> MeasurementUnits.unitId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: unidad de medida base en la que se vende o empaca el producto individualmente

- unitVolumeM3
  - tipo: decimal(10, 6)
  - pk: no
  - descripcion: volumen que ocupa una unidad individual del producto en metros cúbicos

- unitWeightKg
  - tipo: decimal(10, 4)
  - pk: no
  - descripcion: peso de una unidad individual del producto en kilogramos

- isDeleted
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

## ProductCharacteristics

- characteristicId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la característica del producto

- productId
  - tipo: integer (FK -> Products.productId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto al que pertenece esta característica

- characteristicType
  - tipo: varchar(50)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de característica (ej: aroma, ingrediente, beneficio, textura, color)

- characteristicValue
  - tipo: varchar(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: valor de la característica (ej: lavanda, vitamina C, hidratante)

- isDeleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## BulkPurchases

- bulkId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del lote de compra a granel

- productId
  - tipo: integer (FK -> Products.productId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto individual que compone este lote

- supplierId
  - tipo: integer (FK -> Suppliers.supplierId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: proveedor al que se le compró el lote

- quantityBulk
  - tipo: decimal(10, 3)
  - pk: no
  - restriccion: NOT NULL, CHECK (quantityBulk > 0)
  - descripcion: cantidad total del lote en la unidad de medida indicada

- unitId
  - tipo: integer (FK -> MeasurementUnits.unitId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: unidad de medida en la que está expresada la cantidad del lote

- priceBulkUsd
  - tipo: decimal(12, 2)
  - pk: no
  - restriccion: NOT NULL, CHECK (priceBulkUsd >= 0)
  - descripcion: precio total del lote en dólares (USD)

- originCountryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país de origen de este lote de productos

- weightKg
  - tipo: decimal(10, 3)
  - pk: no
  - restriccion: CHECK (weightKg > 0)
  - descripcion: peso total del lote en kilogramos

- volumeM3
  - tipo: decimal(10, 4)
  - pk: no
  - restriccion: CHECK (volumeM3 > 0)
  - descripcion: volumen total que ocupa el lote en metros cúbicos

- arrivalDate
  - tipo: timestamp
  - pk: no
  - descripcion: fecha y hora en la que llegó el lote al HUB de Nicaragua

- status
  - tipo: varchar(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'EN_TRANSITO', CHECK (status IN ('EN_TRANSITO', 'RECIBIDO', 'EN_ALMACEN', 'DESPACHADO', 'CANCELADO'))
  - descripcion: estado actual del lote en la cadena de suministro

- importDutyUsd
  - tipo: decimal(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: monto pagado en aranceles de importación en dólares (USD)

- freightCostUsd
  - tipo: decimal(12, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo de flete internacional del lote en dólares (USD)

- isDeleted
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

## PermitTypes

- permitTypeId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del tipo de permiso de importación

- permitTypeName
  - tipo: varchar(80)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del tipo de permiso (ej: Sanitario, Fitosanitario, Aduanero, INVIMA)

- permitTypeDescription
  - tipo: varchar(200)
  - pk: no
  - descripcion: descripción del alcance o propósito de este tipo de permiso

- isDeleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## ImportPermits

- importPermitId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del permiso de importación aplicado a un lote

- bulkId
  - tipo: integer (FK -> BulkPurchases.bulkId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: lote al que aplica este permiso

- permitTypeId
  - tipo: integer (FK -> PermitTypes.permitTypeId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de permiso aplicado

- permitNumber
  - tipo: varchar(80)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: número o código oficial del permiso emitido por la entidad reguladora

- issuingAuthority
  - tipo: varchar(150)
  - pk: no
  - descripcion: nombre de la entidad que emitió el permiso

- issueDate
  - tipo: date
  - pk: no
  - descripcion: fecha de emisión del permiso

- expiryDate
  - tipo: date
  - pk: no
  - descripcion: fecha de vencimiento del permiso

- permitCostUsd
  - tipo: decimal(10, 2)
  - pk: no
  - restriccion: DEFAULT 0.00
  - descripcion: costo pagado para obtener el permiso en dólares (USD)

- isDeleted
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

## InventoryHub

- inventoryHubId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del movimiento de inventario en el HUB de Nicaragua

- productId
  - tipo: integer (FK -> Products.productId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto al que corresponde este movimiento de inventario

- bulkId
  - tipo: integer (FK -> BulkPurchases.bulkId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: lote de origen de las unidades registradas en este movimiento

- movementType
  - tipo: varchar(20)
  - pk: no
  - restriccion: NOT NULL, CHECK (movementType IN ('ENTRADA', 'SALIDA', 'AJUSTE'))
  - descripcion: tipo de movimiento de inventario

- quantity
  - tipo: decimal(12, 3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cantidad de unidades del movimiento. Positiva para entradas, negativa para salidas o ajustes de descuento

- costPerUnitUsd
  - tipo: decimal(12, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario del producto en USD al momento del movimiento (incluye flete y aranceles prorrateados)

- referenceId
  - tipo: integer
  - pk: no
  - descripcion: ID del documento que origina el movimiento (ej: dispatch_order_id en salidas, bulk_id en entradas)

- notes
  - tipo: varchar(200)
  - pk: no
  - descripcion: observaciones adicionales sobre el movimiento (ej: ajuste por conteo físico)

- isDeleted
  - tipo: boolean
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: borrado lógico del registro

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora en que se registró el movimiento

## DispatchOrders

- dispatchOrderId
  - tipo: serial
  - pk: si
  - descripcion: identificador único de la orden de despacho generada por solicitud de Dynamic Brands

- externalOrderNumber
  - tipo: varchar(60)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: número de orden legible para referencia cruzada con Dynamic Brands (no es la PK del otro sistema)

- productId
  - tipo: integer (FK -> Products.productId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: producto individual a despachar

- quantityDispatched
  - tipo: decimal(12, 3)
  - pk: no
  - restriccion: NOT NULL, CHECK (quantityDispatched > 0)
  - descripcion: cantidad de unidades despachadas hacia el país de destino

- dispatchDate
  - tipo: timestamp
  - pk: no
  - descripcion: fecha y hora en que se ejecutó el despacho

- destinationCountryId
  - tipo: integer (FK -> Countries.countryId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país destino final del despacho

- status
  - tipo: varchar(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK (status IN ('PENDIENTE', 'EN_ETIQUETADO', 'LISTO_COURIER', 'ENTREGADO_COURIER', 'CANCELADO'))
  - descripcion: estado actual de la orden de despacho

- unitCostUsd
  - tipo: decimal(12, 4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario del producto en USD al momento del despacho (snapshot para trazabilidad)

- isDeleted
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

## ExchangeRates

- exchangeRateId
  - tipo: serial
  - pk: si
  - descripcion: identificador único del registro de tipo de cambio

- currencyId
  - tipo: integer (FK -> Currencies.currencyId)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: moneda local cuya tasa se está registrando

- rateToUsd
  - tipo: decimal(18, 6)
  - pk: no
  - restriccion: NOT NULL, CHECK (rateToUsd > 0)
  - descripcion: tasa de conversión de la moneda local a USD (1 unidad de moneda local = X USD)

- rateDate
  - tipo: date
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que aplica esta tasa de cambio

- source
  - tipo: varchar(100)
  - pk: no
  - descripcion: fuente de la tasa (ej: Banco Central de Nicaragua)

- createdAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

## ProcessLog

- logId
  - tipo: bigserial
  - pk: si
  - descripcion: identificador único del evento de log

- eventSource
  - tipo: varchar(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: origen del evento registrado (ej: nombre del trigger, función, job o módulo de aplicación)

- eventType
  - tipo: varchar(60)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: categoría o tipo de operación registrada (ej: INSERT, UPDATE, DISPATCH, SYNC)

- affectedTable
  - tipo: varchar(100)
  - pk: no
  - descripcion: tabla afectada por la operación registrada

- affectedRecordId
  - tipo: bigint
  - pk: no
  - descripcion: ID del registro afectado en la tabla destino

- description
  - tipo: text
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del evento ocurrido o del error capturado

- status
  - tipo: varchar(20)
  - pk: no
  - restriccion: NOT NULL, CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR'))
  - descripcion: nivel de severidad del evento registrado

- errorDetail
  - tipo: text
  - pk: no
  - descripcion: detalle técnico del error (SQLERRM, stack trace u otro contexto de fallo)

- executedAt
  - tipo: timestamp
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que ocurrió el evento

- dbUser
  - tipo: varchar(100)
  - pk: no
  - restriccion: DEFAULT current_user
  - descripcion: usuario de base de datos que originó el evento
