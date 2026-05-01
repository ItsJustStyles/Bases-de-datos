-- ============================================================
--  Dynamic Brands DB — DDL Script
--  Engine : MySQL 8.4
--  Created: 2026-04-22
-- ============================================================

CREATE DATABASE IF NOT EXISTS dynamic_brands_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE dynamic_brands_db;

-- ============================================================
--  1. GEOGRAFÍA BASE
-- ============================================================

CREATE TABLE Countries (
    countryId   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    countryName VARCHAR(100)    NOT NULL,
    isoCode     CHAR(3)         NOT NULL,
    isActive    TINYINT(1)      NOT NULL DEFAULT 1,
    isDeleted   TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (countryId),
    UNIQUE KEY uq_countries_name    (countryName),
    UNIQUE KEY uq_countries_isocode (isoCode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE Regions (
    regionId    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    countryId   INT UNSIGNED    NOT NULL,
    regionName  VARCHAR(100)    NOT NULL,
    isDeleted   TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (regionId),
    CONSTRAINT fk_regions_country
        FOREIGN KEY (countryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE Cities (
    cityId      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    regionId    INT UNSIGNED    NOT NULL,
    cityName    VARCHAR(100)    NOT NULL,
    isDeleted   TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cityId),
    CONSTRAINT fk_cities_region
        FOREIGN KEY (regionId) REFERENCES Regions(regionId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE Addresses (
    addressId       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    cityId          INT UNSIGNED    NOT NULL,
    addressLine1    VARCHAR(200)    NOT NULL,
    addressLine2    VARCHAR(200)    NULL DEFAULT NULL,
    postalCode      VARCHAR(20)     NULL DEFAULT NULL,
    isDeleted       TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (addressId),
    CONSTRAINT fk_addresses_city
        FOREIGN KEY (cityId) REFERENCES Cities(cityId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  2. MONEDAS E IMPUESTOS
-- ============================================================

CREATE TABLE Currencies (
    currencyId      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    currencyCode    CHAR(3)         NOT NULL,
    currencySymbol  VARCHAR(5)      NULL DEFAULT NULL,
    currencyName    VARCHAR(80)     NOT NULL,
    countryId       INT UNSIGNED    NOT NULL,
    isDeleted       TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (currencyId),
    UNIQUE KEY uq_currencies_code (currencyCode),
    CONSTRAINT fk_currencies_country
        FOREIGN KEY (countryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE CountryTaxes (
    countryTaxId        INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    countryId           INT UNSIGNED    NOT NULL,
    taxRatePercent      DECIMAL(5, 2)   NOT NULL DEFAULT 0.00,
    regulatoryNotes     TEXT            NULL DEFAULT NULL,
    validFrom           DATE            NOT NULL,
    validTo             DATE            NULL DEFAULT NULL,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (countryTaxId),
    CONSTRAINT fk_countrytaxes_country
        FOREIGN KEY (countryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  3. MARCAS Y SITIOS WEB (WHITE LABEL)
-- ============================================================

CREATE TABLE Brands (
    brandId     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brandName   VARCHAR(150)    NOT NULL,
    brandFocus  VARCHAR(100)    NOT NULL,
    isActive    TINYINT(1)      NOT NULL DEFAULT 1,
    isDeleted   TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (brandId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE Websites (
    websiteId       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brandId         INT UNSIGNED    NOT NULL,
    countryId       INT UNSIGNED    NOT NULL,
    siteUrl         VARCHAR(500)    NULL DEFAULT NULL,
    marketingFocus  VARCHAR(200)    NULL DEFAULT NULL,
    siteConfig      JSON            NULL DEFAULT NULL,
    launchDate      DATE            NULL DEFAULT NULL,
    closeDate       DATE            NULL DEFAULT NULL,
    isDeleted       TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (websiteId),
    UNIQUE KEY uq_websites_url (siteUrl),
    CONSTRAINT fk_websites_brand
        FOREIGN KEY (brandId) REFERENCES Brands(brandId),
    CONSTRAINT fk_websites_country
        FOREIGN KEY (countryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  4. CATÁLOGO DE PRODUCTOS
-- ============================================================

-- [CAMBIO] Se agregó websiteId con FK a Websites.
--          El catálogo ahora tiene relación formal con el sitio
--          al que pertenece cada producto, además de la marca.
CREATE TABLE ProductCatalog (
    catalogProductId    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    etheriaProductId    INT UNSIGNED    NOT NULL,
    brandId             INT UNSIGNED    NOT NULL,
    websiteId           INT UNSIGNED    NOT NULL,
    brandedName         VARCHAR(150)    NOT NULL,
    brandedDescription  TEXT            NULL DEFAULT NULL,
    brandedImageUrl     VARCHAR(500)    NULL DEFAULT NULL,
    categoryLabel       VARCHAR(100)    NULL DEFAULT NULL,
    healthClaims        TEXT            NULL DEFAULT NULL,
    isActive            TINYINT(1)      NOT NULL DEFAULT 1,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (catalogProductId),
    CONSTRAINT fk_productcatalog_brand
        FOREIGN KEY (brandId) REFERENCES Brands(brandId),
    CONSTRAINT fk_productcatalog_website
        FOREIGN KEY (websiteId) REFERENCES Websites(websiteId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

-- [CAMBIO] Se eliminó el campo stockDisplay de esta tabla.
--          El inventario visible se gestiona ahora en InventoryDisplay.
CREATE TABLE WebsiteProducts (
    websiteProductId    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    websiteId           INT UNSIGNED    NOT NULL,
    catalogProductId    INT UNSIGNED    NOT NULL,
    isFeatured          TINYINT(1)      NOT NULL DEFAULT 0,
    isActive            TINYINT(1)      NOT NULL DEFAULT 1,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (websiteProductId),
    CONSTRAINT fk_websiteproducts_website
        FOREIGN KEY (websiteId) REFERENCES Websites(websiteId),
    CONSTRAINT fk_websiteproducts_catalog
        FOREIGN KEY (catalogProductId) REFERENCES ProductCatalog(catalogProductId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE WebsiteProductPrices (
    priceId             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    websiteProductId    INT UNSIGNED    NOT NULL,
    salePriceLocal      DECIMAL(14, 2)  NOT NULL,
    currencyId          INT UNSIGNED    NOT NULL,
    validFrom           DATE            NOT NULL,
    validTo             DATE            NULL DEFAULT NULL,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (priceId),
    CONSTRAINT chk_prices_sale          CHECK (salePriceLocal > 0),
    CONSTRAINT fk_prices_websiteproduct
        FOREIGN KEY (websiteProductId) REFERENCES WebsiteProducts(websiteProductId),
    CONSTRAINT fk_prices_currency
        FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

-- [NUEVO] Tabla de inventario visible por producto/sitio.
--         Reemplaza el campo stockDisplay que estaba en WebsiteProducts.
--         Agrega trazabilidad de la última sincronización con Etheria.
CREATE TABLE InventoryDisplay (
    inventoryDisplayId  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    websiteProductId    INT UNSIGNED    NOT NULL,
    stockDisplay        INT UNSIGNED    NOT NULL DEFAULT 0,
    lastSyncedAt        TIMESTAMP       NULL DEFAULT NULL,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (inventoryDisplayId),
    UNIQUE KEY uq_inventorydisplay_product (websiteProductId),
    CONSTRAINT fk_inventorydisplay_websiteproduct
        FOREIGN KEY (websiteProductId) REFERENCES WebsiteProducts(websiteProductId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  5. CLIENTES Y DIRECCIONES DE ENVÍO
-- ============================================================

CREATE TABLE Customers (
    customerId      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    firstName       VARCHAR(80)     NOT NULL,
    lastName        VARCHAR(80)     NOT NULL,
    email           VARCHAR(150)    NOT NULL,
    passwordHash    VARCHAR(255)    NOT NULL,
    phone           VARCHAR(30)     NOT NULL,
    countryId       INT UNSIGNED    NOT NULL,
    isDeleted       TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customerId),
    UNIQUE KEY uq_customers_email (email),
    CONSTRAINT fk_customers_country
        FOREIGN KEY (countryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE CustomerAddresses (
    customerAddressId   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customerId          INT UNSIGNED    NOT NULL,
    addressId           INT UNSIGNED    NOT NULL,
    alias               VARCHAR(60)     NULL DEFAULT NULL,
    isDefault           TINYINT(1)      NOT NULL DEFAULT 0,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customerAddressId),
    CONSTRAINT fk_custaddr_customer
        FOREIGN KEY (customerId) REFERENCES Customers(customerId),
    CONSTRAINT fk_custaddr_address
        FOREIGN KEY (addressId) REFERENCES Addresses(addressId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  6. TIPOS DE CAMBIO
-- ============================================================

CREATE TABLE ExchangeRates (
    exchangeRateId  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    currencyId      INT UNSIGNED    NOT NULL,
    rateToUsd       DECIMAL(18, 6)  NOT NULL,
    rateDate        DATE            NOT NULL,
    source          VARCHAR(100)    NULL DEFAULT NULL,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (exchangeRateId),
    CONSTRAINT chk_exchangerates_rate   CHECK (rateToUsd > 0),
    CONSTRAINT fk_exchangerates_currency
        FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  7. ÓRDENES DE COMPRA
-- ============================================================

CREATE TABLE Orders (
    orderId                 INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customerId              INT UNSIGNED    NOT NULL,
    websiteId               INT UNSIGNED    NOT NULL,
    customerAddressId       INT UNSIGNED    NOT NULL,
    orderDate               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    totalAmountLocal        DECIMAL(14, 2)  NOT NULL,
    currencyId              INT UNSIGNED    NOT NULL,
    exchangeRateId          INT UNSIGNED    NOT NULL,
    exchangeRateSnapshot    DECIMAL(18, 6)  NOT NULL,
    totalAmountUsd          DECIMAL(14, 4)  NOT NULL,
    status                  VARCHAR(30)     NOT NULL DEFAULT 'PENDIENTE',
    etheriaDispatchOrderId  INT UNSIGNED    NULL DEFAULT NULL,
    isDeleted               TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (orderId),
    CONSTRAINT chk_orders_status CHECK (status IN (
        'PENDIENTE', 'CONFIRMADA', 'EN_PREPARACION',
        'ENVIADA', 'ENTREGADA', 'CANCELADA', 'REEMBOLSADA'
    )),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customerId) REFERENCES Customers(customerId),
    CONSTRAINT fk_orders_website
        FOREIGN KEY (websiteId) REFERENCES Websites(websiteId),
    CONSTRAINT fk_orders_custaddr
        FOREIGN KEY (customerAddressId) REFERENCES CustomerAddresses(customerAddressId),
    CONSTRAINT fk_orders_currency
        FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId),
    CONSTRAINT fk_orders_exchangerate
        FOREIGN KEY (exchangeRateId) REFERENCES ExchangeRates(exchangeRateId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE OrderItems (
    orderItemId         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    orderId             INT UNSIGNED    NOT NULL,
    websiteProductId    INT UNSIGNED    NOT NULL,
    quantity            INT UNSIGNED    NOT NULL,
    unitPriceLocal      DECIMAL(14, 2)  NOT NULL,
    subtotalLocal       DECIMAL(14, 2)  NOT NULL,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (orderItemId),
    CONSTRAINT chk_orderitems_qty   CHECK (quantity > 0),
    CONSTRAINT fk_orderitems_order
        FOREIGN KEY (orderId) REFERENCES Orders(orderId),
    CONSTRAINT fk_orderitems_product
        FOREIGN KEY (websiteProductId) REFERENCES WebsiteProducts(websiteProductId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  8. ENVÍOS (SHIPPING)
-- ============================================================

CREATE TABLE Couriers (
    courierId           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    courierName         VARCHAR(100)    NOT NULL,
    contactEmail        VARCHAR(150)    NULL DEFAULT NULL,
    contactPhone        VARCHAR(30)     NULL DEFAULT NULL,
    trackingUrlTemplate VARCHAR(300)    NULL DEFAULT NULL,
    isActive            TINYINT(1)      NOT NULL DEFAULT 1,
    isDeleted           TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (courierId),
    UNIQUE KEY uq_couriers_name (courierName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

-- [CAMBIO] Se agregaron exchangeRateId (FK) y exchangeRateSnapshot.
--          El costo del envío tiene moneda local, por lo que requiere
--          el tipo de cambio vigente y su snapshot para trazabilidad.
CREATE TABLE ShippingRecords (
    shippingId              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    orderId                 INT UNSIGNED    NOT NULL,
    courierId               INT UNSIGNED    NOT NULL,
    trackingCode            VARCHAR(100)    NULL DEFAULT NULL,
    shippingCostLocal       DECIMAL(12, 2)  NOT NULL DEFAULT 0.00,
    currencyId              INT UNSIGNED    NOT NULL,
    exchangeRateId          INT UNSIGNED    NOT NULL,
    exchangeRateSnapshot    DECIMAL(18, 6)  NOT NULL,
    estimatedDeliveryDate   DATE            NULL DEFAULT NULL,
    actualDeliveryDate      DATE            NULL DEFAULT NULL,
    status                  VARCHAR(30)     NOT NULL DEFAULT 'PENDIENTE',
    destinationCountryId    INT UNSIGNED    NOT NULL,
    healthPermitNumber      VARCHAR(100)    NULL DEFAULT NULL,
    isDeleted               TINYINT(1)      NOT NULL DEFAULT 0,
    createdAt               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (shippingId),
    UNIQUE KEY uq_shipping_order        (orderId),
    UNIQUE KEY uq_shipping_trackingcode (trackingCode),
    CONSTRAINT chk_shipping_status CHECK (status IN (
        'PENDIENTE', 'RETIRADO_HUB', 'EN_TRANSITO',
        'EN_ADUANA', 'ENTREGADO', 'FALLIDO'
    )),
    CONSTRAINT fk_shipping_order
        FOREIGN KEY (orderId) REFERENCES Orders(orderId),
    CONSTRAINT fk_shipping_courier
        FOREIGN KEY (courierId) REFERENCES Couriers(courierId),
    CONSTRAINT fk_shipping_currency
        FOREIGN KEY (currencyId) REFERENCES Currencies(currencyId),
    CONSTRAINT fk_shipping_exchangerate
        FOREIGN KEY (exchangeRateId) REFERENCES ExchangeRates(exchangeRateId),
    CONSTRAINT fk_shipping_destcountry
        FOREIGN KEY (destinationCountryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  9. LOG DE PROCESOS
-- ============================================================

CREATE TABLE ProcessLog (
    logId            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    eventSource      VARCHAR(150)    NOT NULL,
    eventType        VARCHAR(60)     NOT NULL,
    affectedTable    VARCHAR(100)    NULL DEFAULT NULL,
    affectedRecordId BIGINT UNSIGNED NULL DEFAULT NULL,
    description      TEXT            NOT NULL,
    status           VARCHAR(20)     NOT NULL,
    errorDetail      TEXT            NULL DEFAULT NULL,
    executedAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dbUser           VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),
    PRIMARY KEY (logId),
    CONSTRAINT chk_processlog_status CHECK (status IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  ÍNDICES RECOMENDADOS
-- ============================================================

-- Geografía
CREATE INDEX idx_regions_country           ON Regions(countryId);
CREATE INDEX idx_cities_region             ON Cities(regionId);
CREATE INDEX idx_addresses_city            ON Addresses(cityId);

-- Monedas / Impuestos
CREATE INDEX idx_currencies_country        ON Currencies(countryId);
CREATE INDEX idx_countrytaxes_country      ON CountryTaxes(countryId);
CREATE INDEX idx_countrytaxes_validfrom    ON CountryTaxes(validFrom);
CREATE INDEX idx_exchangerates_currency    ON ExchangeRates(currencyId);
CREATE INDEX idx_exchangerates_date        ON ExchangeRates(rateDate);

-- Marcas y sitios
CREATE INDEX idx_websites_brand            ON Websites(brandId);
CREATE INDEX idx_websites_country          ON Websites(countryId);

-- Catálogo
CREATE INDEX idx_productcatalog_brand      ON ProductCatalog(brandId);
CREATE INDEX idx_productcatalog_website    ON ProductCatalog(websiteId);
CREATE INDEX idx_productcatalog_etheria    ON ProductCatalog(etheriaProductId);
CREATE INDEX idx_websiteproducts_website   ON WebsiteProducts(websiteId);
CREATE INDEX idx_websiteproducts_catalog   ON WebsiteProducts(catalogProductId);
CREATE INDEX idx_prices_websiteproduct     ON WebsiteProductPrices(websiteProductId);
CREATE INDEX idx_prices_validfrom          ON WebsiteProductPrices(validFrom);

-- Inventario display
CREATE INDEX idx_inventorydisplay_synced   ON InventoryDisplay(lastSyncedAt);

-- Clientes
CREATE INDEX idx_customers_country         ON Customers(countryId);
CREATE INDEX idx_custaddr_customer         ON CustomerAddresses(customerId);
CREATE INDEX idx_custaddr_address          ON CustomerAddresses(addressId);

-- Órdenes
CREATE INDEX idx_orders_customer           ON Orders(customerId);
CREATE INDEX idx_orders_website            ON Orders(websiteId);
CREATE INDEX idx_orders_status             ON Orders(status);
CREATE INDEX idx_orders_date               ON Orders(orderDate);
CREATE INDEX idx_orderitems_order          ON OrderItems(orderId);
CREATE INDEX idx_orderitems_product        ON OrderItems(websiteProductId);

-- Envíos
CREATE INDEX idx_shipping_courier          ON ShippingRecords(courierId);
CREATE INDEX idx_shipping_status           ON ShippingRecords(status);
CREATE INDEX idx_shipping_destcountry      ON ShippingRecords(destinationCountryId);
CREATE INDEX idx_shipping_exchangerate     ON ShippingRecords(exchangeRateId);

-- Log
CREATE INDEX idx_processlog_status         ON ProcessLog(status);
CREATE INDEX idx_processlog_source         ON ProcessLog(eventSource);
CREATE INDEX idx_processlog_table          ON ProcessLog(affectedTable);
CREATE INDEX idx_processlog_executedat     ON ProcessLog(executedAt);