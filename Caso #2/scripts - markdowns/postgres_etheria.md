-- ============================================================
--  Etheria Global DB — DDL Script
--  Engine : PostgreSQL 18
--  Created: 2026-04-22
-- ============================================================

-- ── Crear la base de datos (ejecutar conectado a postgres) ──
-- CREATE DATABASE etheria_global_db
--     ENCODING    'UTF8'
--     LC_COLLATE  'es_CR.UTF-8'
--     LC_CTYPE    'es_CR.UTF-8'
--     TEMPLATE    template0;

-- \c etheria_global_db

-- ============================================================
--  1. GEOGRAFÍA BASE
-- ============================================================

CREATE TABLE Countries (
    countryId   SERIAL          PRIMARY KEY,
    countryName VARCHAR(100)    NOT NULL UNIQUE,
    isoCode     CHAR(3)         NOT NULL UNIQUE,
    isDeleted   BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE GeographicRegions (
    geographicRegionId  SERIAL       PRIMARY KEY,
    regionName          VARCHAR(100) NOT NULL UNIQUE,
    isDeleted           BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE CountryRegions (
    countryRegionId     SERIAL    PRIMARY KEY,
    countryId           INTEGER   NOT NULL
        REFERENCES Countries(countryId),
    geographicRegionId  INTEGER   NOT NULL
        REFERENCES GeographicRegions(geographicRegionId),
    createdAt           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE AdminRegions (
    adminRegionId   SERIAL       PRIMARY KEY,
    countryId       INTEGER      NOT NULL
        REFERENCES Countries(countryId),
    regionName      VARCHAR(100) NOT NULL,
    isDeleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE Cities (
    cityId          SERIAL       PRIMARY KEY,
    adminRegionId   INTEGER      NOT NULL
        REFERENCES AdminRegions(adminRegionId),
    cityName        VARCHAR(100) NOT NULL,
    isDeleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE Addresses (
    addressId       SERIAL       PRIMARY KEY,
    cityId          INTEGER      NOT NULL
        REFERENCES Cities(cityId),
    addressLine1    VARCHAR(200) NOT NULL,
    addressLine2    VARCHAR(200),
    postalCode      VARCHAR(20),
    isDeleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  2. MONEDAS
-- ============================================================

CREATE TABLE Currencies (
    currencyId      SERIAL      PRIMARY KEY,
    currencyCode    CHAR(3)     NOT NULL UNIQUE,
    currencySymbol  VARCHAR(5),
    currencyName    VARCHAR(80) NOT NULL,
    countryId       INTEGER     NOT NULL
        REFERENCES Countries(countryId),
    isDeleted       BOOLEAN     NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  3. PERSONAS Y PROVEEDORES
-- ============================================================

CREATE TABLE Persons (
    personId    SERIAL       PRIMARY KEY,
    firstName   VARCHAR(80)  NOT NULL,
    lastName    VARCHAR(80)  NOT NULL,
    email       VARCHAR(150) UNIQUE,
    phone       VARCHAR(30),
    isDeleted   BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE Suppliers (
    supplierId          SERIAL       PRIMARY KEY,
    supplierName        VARCHAR(150) NOT NULL,
    primaryContactId    INTEGER
        REFERENCES Persons(personId),
    countryId           INTEGER      NOT NULL
        REFERENCES Countries(countryId),
    addressId           INTEGER
        REFERENCES Addresses(addressId),
    isActive            BOOLEAN      NOT NULL DEFAULT TRUE,
    isDeleted           BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  4. CATÁLOGO DE PRODUCTOS
-- ============================================================

CREATE TABLE ProductCategories (
    categoryId          SERIAL       PRIMARY KEY,
    categoryName        VARCHAR(100) NOT NULL UNIQUE,
    categoryDescription VARCHAR(200),
    isDeleted           BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE MeasurementUnits (
    unitId      SERIAL      PRIMARY KEY,
    unitName    VARCHAR(20) NOT NULL UNIQUE,
    isDeleted   BOOLEAN     NOT NULL DEFAULT FALSE,
    createdAt   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE Products (
    productId       SERIAL          PRIMARY KEY,
    productName     VARCHAR(150)    NOT NULL,
    categoryId      INTEGER         NOT NULL
        REFERENCES ProductCategories(categoryId),
    baseUnitId      INTEGER         NOT NULL
        REFERENCES MeasurementUnits(unitId),
    unitVolumeM3    DECIMAL(10, 6),
    unitWeightKg    DECIMAL(10, 4),
    isDeleted       BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

-- [NUEVO] Precios de venta de Etheria a Dynamic Brands por producto.
--         Soporta historial de precios mediante validFrom / validTo.
CREATE TABLE ProductPrices (
    productPriceId  SERIAL          PRIMARY KEY,
    productId       INTEGER         NOT NULL
        REFERENCES Products(productId),
    salePriceUsd    DECIMAL(12, 4)  NOT NULL
        CHECK (salePriceUsd > 0),
    validFrom       DATE            NOT NULL,
    validTo         DATE,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE ProductCharacteristics (
    characteristicId    SERIAL      PRIMARY KEY,
    productId           INTEGER     NOT NULL
        REFERENCES Products(productId),
    characteristicType  VARCHAR(50) NOT NULL,
    characteristicValue VARCHAR(100) NOT NULL,
    isDeleted           BOOLEAN     NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  5. COMPRAS A GRANEL (IMPORTACIONES)
-- ============================================================

CREATE TABLE BulkPurchases (
    bulkId          SERIAL          PRIMARY KEY,
    productId       INTEGER         NOT NULL
        REFERENCES Products(productId),
    supplierId      INTEGER         NOT NULL
        REFERENCES Suppliers(supplierId),
    quantityBulk    DECIMAL(10, 3)  NOT NULL
        CHECK (quantityBulk > 0),
    unitId          INTEGER         NOT NULL
        REFERENCES MeasurementUnits(unitId),
    priceBulkUsd    DECIMAL(12, 2)  NOT NULL
        CHECK (priceBulkUsd >= 0),
    originCountryId INTEGER         NOT NULL
        REFERENCES Countries(countryId),
    weightKg        DECIMAL(10, 3)
        CHECK (weightKg > 0),
    volumeM3        DECIMAL(10, 4)
        CHECK (volumeM3 > 0),
    arrivalDate     TIMESTAMP,
    status          VARCHAR(30)     NOT NULL DEFAULT 'EN_TRANSITO'
        CHECK (status IN ('EN_TRANSITO', 'RECIBIDO', 'EN_ALMACEN', 'DESPACHADO', 'CANCELADO')),
    importDutyUsd   DECIMAL(12, 2)  NOT NULL DEFAULT 0.00,
    freightCostUsd  DECIMAL(12, 2)  NOT NULL DEFAULT 0.00,
    isDeleted       BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  6. PERMISOS DE IMPORTACIÓN
-- ============================================================

CREATE TABLE PermitTypes (
    permitTypeId            SERIAL       PRIMARY KEY,
    permitTypeName          VARCHAR(80)  NOT NULL UNIQUE,
    permitTypeDescription   VARCHAR(200),
    isDeleted               BOOLEAN      NOT NULL DEFAULT FALSE,
    createdAt               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

CREATE TABLE ImportPermits (
    importPermitId      SERIAL          PRIMARY KEY,
    bulkId              INTEGER         NOT NULL
        REFERENCES BulkPurchases(bulkId),
    permitTypeId        INTEGER         NOT NULL
        REFERENCES PermitTypes(permitTypeId),
    permitNumber        VARCHAR(80)     UNIQUE,
    issuingAuthority    VARCHAR(150),
    issueDate           DATE,
    expiryDate          DATE,
    permitCostUsd       DECIMAL(10, 2)  NOT NULL DEFAULT 0.00,
    isDeleted           BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  7. ÓRDENES DE DESPACHO
--     (declarada antes de InventoryHub por la FK que ésta necesita)
-- ============================================================

-- [NOTA DE ORDEN] DispatchOrders se declara antes de InventoryHub
--                 porque InventoryHub referencia dispatchOrderId.
CREATE TABLE DispatchOrders (
    dispatchOrderId     SERIAL          PRIMARY KEY,
    externalOrderNumber VARCHAR(60)     UNIQUE,
    productId           INTEGER         NOT NULL
        REFERENCES Products(productId),
    quantityDispatched  DECIMAL(12, 3)  NOT NULL
        CHECK (quantityDispatched > 0),
    dispatchDate        TIMESTAMP,
    destinationCountryId INTEGER        NOT NULL
        REFERENCES Countries(countryId),
    status              VARCHAR(30)     NOT NULL DEFAULT 'PENDIENTE'
        CHECK (status IN ('PENDIENTE', 'EN_ETIQUETADO', 'LISTO_COURIER', 'ENTREGADO_COURIER', 'CANCELADO')),
    unitCostUsd         DECIMAL(12, 4)  NOT NULL,
    isDeleted           BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  8. INVENTARIO HUB (NICARAGUA)
-- ============================================================

-- [CAMBIO] Se reemplazó referenceId INTEGER genérico (sin FK ni tipo
--          definido) por dispatchOrderId con FK explícita a DispatchOrders.
--          Es NULL para movimientos de ENTRADA y AJUSTE.
CREATE TABLE InventoryHub (
    inventoryHubId  SERIAL          PRIMARY KEY,
    productId       INTEGER         NOT NULL
        REFERENCES Products(productId),
    bulkId          INTEGER         NOT NULL
        REFERENCES BulkPurchases(bulkId),
    movementType    VARCHAR(20)     NOT NULL
        CHECK (movementType IN ('ENTRADA', 'SALIDA', 'AJUSTE')),
    quantity        DECIMAL(12, 3)  NOT NULL,
    costPerUnitUsd  DECIMAL(12, 4)  NOT NULL,
    dispatchOrderId INTEGER
        REFERENCES DispatchOrders(dispatchOrderId),
    notes           VARCHAR(200),
    isDeleted       BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------

-- [NUEVO] Stock actual consolidado por producto en el HUB.
--         Evita recalcular el saldo sumando todos los movimientos.
--         Se actualiza con cada INSERT en InventoryHub (vía trigger).
CREATE TABLE InventoryStock (
    inventoryStockId    SERIAL          PRIMARY KEY,
    productId           INTEGER         NOT NULL UNIQUE
        REFERENCES Products(productId),
    stockQuantity       DECIMAL(12, 3)  NOT NULL DEFAULT 0
        CHECK (stockQuantity >= 0),
    lastMovementId      INTEGER
        REFERENCES InventoryHub(inventoryHubId),
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  9. TIPOS DE CAMBIO
-- ============================================================

CREATE TABLE ExchangeRates (
    exchangeRateId  SERIAL          PRIMARY KEY,
    currencyId      INTEGER         NOT NULL
        REFERENCES Currencies(currencyId),
    rateToUsd       DECIMAL(18, 6)  NOT NULL
        CHECK (rateToUsd > 0),
    rateDate        DATE            NOT NULL,
    source          VARCHAR(100),
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  10. LOG DE PROCESOS
-- ============================================================

CREATE TABLE ProcessLog (
    logId           BIGSERIAL    PRIMARY KEY,
    eventSource     VARCHAR(150) NOT NULL,
    eventType       VARCHAR(60)  NOT NULL,
    affectedTable   VARCHAR(100),
    affectedRecordId BIGINT,
    description     TEXT         NOT NULL,
    status          VARCHAR(20)  NOT NULL
        CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR')),
    errorDetail     TEXT,
    executedAt      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dbUser          VARCHAR(100) NOT NULL DEFAULT current_user
);

-- ============================================================
--  ÍNDICES RECOMENDADOS
-- ============================================================

-- Geografía
CREATE INDEX idx_countryregions_country   ON CountryRegions(countryId);
CREATE INDEX idx_countryregions_region    ON CountryRegions(geographicRegionId);
CREATE INDEX idx_adminregions_country     ON AdminRegions(countryId);
CREATE INDEX idx_cities_adminregion       ON Cities(adminRegionId);
CREATE INDEX idx_addresses_city           ON Addresses(cityId);

-- Proveedores
CREATE INDEX idx_suppliers_country        ON Suppliers(countryId);
CREATE INDEX idx_suppliers_contact        ON Suppliers(primaryContactId);

-- Productos
CREATE INDEX idx_products_category        ON Products(categoryId);
CREATE INDEX idx_products_unit            ON Products(baseUnitId);
CREATE INDEX idx_productprices_product    ON ProductPrices(productId);
CREATE INDEX idx_productprices_validfrom  ON ProductPrices(validFrom);
CREATE INDEX idx_productchar_product      ON ProductCharacteristics(productId);

-- Compras / inventario
CREATE INDEX idx_bulkpurchases_product    ON BulkPurchases(productId);
CREATE INDEX idx_bulkpurchases_supplier   ON BulkPurchases(supplierId);
CREATE INDEX idx_bulkpurchases_status     ON BulkPurchases(status);
CREATE INDEX idx_importpermits_bulk       ON ImportPermits(bulkId);
CREATE INDEX idx_inventoryhub_product     ON InventoryHub(productId);
CREATE INDEX idx_inventoryhub_bulk        ON InventoryHub(bulkId);
CREATE INDEX idx_inventoryhub_movement    ON InventoryHub(movementType);
CREATE INDEX idx_inventoryhub_dispatch    ON InventoryHub(dispatchOrderId);
CREATE INDEX idx_inventorystock_product   ON InventoryStock(productId);

-- Despachos
CREATE INDEX idx_dispatchorders_product   ON DispatchOrders(productId);
CREATE INDEX idx_dispatchorders_dest      ON DispatchOrders(destinationCountryId);
CREATE INDEX idx_dispatchorders_status    ON DispatchOrders(status);

-- Finanzas / log
CREATE INDEX idx_exchangerates_currency   ON ExchangeRates(currencyId);
CREATE INDEX idx_exchangerates_date       ON ExchangeRates(rateDate);
CREATE INDEX idx_processlog_status        ON ProcessLog(status);
CREATE INDEX idx_processlog_source        ON ProcessLog(eventSource);
CREATE INDEX idx_processlog_table         ON ProcessLog(affectedTable);