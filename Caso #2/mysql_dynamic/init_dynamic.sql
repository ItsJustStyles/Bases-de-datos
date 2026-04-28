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

CREATE TABLE ProductCatalog (
    catalogProductId    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    etheriaProductId    INT UNSIGNED    NOT NULL,
    brandId             INT UNSIGNED    NOT NULL,
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
        FOREIGN KEY (brandId) REFERENCES Brands(brandId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------

CREATE TABLE WebsiteProducts (
    websiteProductId    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    websiteId           INT UNSIGNED    NOT NULL,
    catalogProductId    INT UNSIGNED    NOT NULL,
    isFeatured          TINYINT(1)      NOT NULL DEFAULT 0,
    stockDisplay        INT UNSIGNED    NOT NULL DEFAULT 0,
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

CREATE TABLE ShippingRecords (
    shippingId              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    orderId                 INT UNSIGNED    NOT NULL,
    courierId               INT UNSIGNED    NOT NULL,
    trackingCode            VARCHAR(100)    NULL DEFAULT NULL,
    shippingCostLocal       DECIMAL(12, 2)  NOT NULL DEFAULT 0.00,
    currencyId              INT UNSIGNED    NOT NULL,
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
    CONSTRAINT fk_shipping_destcountry
        FOREIGN KEY (destinationCountryId) REFERENCES Countries(countryId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  9. LOG DE PROCESOS
-- ============================================================

CREATE TABLE ProcessLog (
    logId           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    eventSource     VARCHAR(150)    NOT NULL,
    eventType       VARCHAR(60)     NOT NULL,
    affectedTable   VARCHAR(100)    NULL DEFAULT NULL,
    affectedRecordId BIGINT UNSIGNED NULL DEFAULT NULL,
    description     TEXT            NOT NULL,
    status          VARCHAR(20)     NOT NULL,
    errorDetail     TEXT            NULL DEFAULT NULL,
    executedAt      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dbUser          VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),
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
CREATE INDEX idx_productcatalog_etheria    ON ProductCatalog(etheriaProductId);
CREATE INDEX idx_websiteproducts_website   ON WebsiteProducts(websiteId);
CREATE INDEX idx_websiteproducts_catalog   ON WebsiteProducts(catalogProductId);
CREATE INDEX idx_prices_websiteproduct     ON WebsiteProductPrices(websiteProductId);
CREATE INDEX idx_prices_validfrom          ON WebsiteProductPrices(validFrom);

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

-- Log
CREATE INDEX idx_processlog_status         ON ProcessLog(status);
CREATE INDEX idx_processlog_source         ON ProcessLog(eventSource);
CREATE INDEX idx_processlog_table          ON ProcessLog(affectedTable);
CREATE INDEX idx_processlog_executedat     ON ProcessLog(executedAt);

-- LLenado de tablas

-- ============================================================
-- SCRIPT DE POBLACIÓN DE DATOS - DYNAMIC BRANDS (MySQL)
-- ============================================================

USE dynamic_brands_db;

DELIMITER $$

CREATE PROCEDURE PopulateDynamicBrands()
BEGIN
    DECLARE v_country_cr_id INT UNSIGNED;
    DECLARE v_brand_id INT UNSIGNED;
    DECLARE v_website_id INT UNSIGNED;
    DECLARE v_catalog_id INT UNSIGNED;
    DECLARE v_web_prod_id INT UNSIGNED;
    DECLARE v_customer_id INT UNSIGNED;
    DECLARE v_order_id INT UNSIGNED;

    -- 1. GEOGRAFÍA BÁSICA
    INSERT IGNORE INTO Countries (countryName, isoCode) VALUES 
    ('Costa Rica', 'CRI'), ('Nicaragua', 'NIC'), ('Panamá', 'PAN');
    
    SELECT countryId INTO v_country_cr_id FROM Countries WHERE isoCode = 'CRI' LIMIT 1;

    INSERT IGNORE INTO Regions (countryId, regionName) VALUES 
    (v_country_cr_id, 'San José'), (v_country_cr_id, 'Alajuela');

    INSERT IGNORE INTO Cities (regionId, cityName) VALUES 
    (1, 'San Pedro'), (2, 'San Rafael');

    INSERT IGNORE INTO Addresses (cityId, addressLine1, postalCode) VALUES 
    (1, 'Oficinas Centrales Dynamic, Calle 2', '10101');

    -- 2. MONEDAS Y TASAS
    INSERT IGNORE INTO Currencies (currencyCode, currencySymbol, currencyName, countryId) VALUES 
    ('CRC', '₡', 'Colón', v_country_cr_id);

    INSERT IGNORE INTO ExchangeRates (currencyId, rateToUsd, rateDate, source)
    SELECT currencyId, 0.0019, CURDATE(), 'BCCR' FROM Currencies WHERE currencyCode = 'CRC';

    -- 3. MARCAS Y SITIOS WEB
    INSERT INTO Brands (brandName, brandFocus) VALUES 
    ('NaturePure', 'Cuidado Orgánico'), 
    ('ZenVibe', 'Aromaterapia Premium')
    ON DUPLICATE KEY UPDATE brandName=brandName;
    
    SET v_brand_id = LAST_INSERT_ID();

    INSERT INTO Websites (brandId, countryId, siteUrl, marketingFocus) VALUES 
    (v_brand_id, v_country_cr_id, 'https://naturepure.cr', 'Venta minorista Costa Rica')
    ON DUPLICATE KEY UPDATE siteUrl=siteUrl;
    
    SET v_website_id = LAST_INSERT_ID();

    -- 4. CATÁLOGO (Vínculo con Etheria)
    -- Simulamos que el etheriaProductId 1 de Postgres es este producto aquí
    INSERT INTO ProductCatalog (etheriaProductId, brandId, brandedName, categoryLabel) VALUES 
    (1, v_brand_id, 'Aceite Esencial de Lavanda NaturePure', 'Aromaterapia'),
    (2, v_brand_id, 'Shampoo de Menta Orgánica', 'Cosmética')
    ON DUPLICATE KEY UPDATE brandedName=brandedName;
    
    SET v_catalog_id = LAST_INSERT_ID();

    -- 5. PRODUCTOS EN SITIO WEB Y PRECIOS
    INSERT INTO WebsiteProducts (websiteId, catalogProductId, stockDisplay) VALUES 
    (v_website_id, v_catalog_id, 100);
    
    SET v_web_prod_id = LAST_INSERT_ID();

    INSERT INTO WebsiteProductPrices (websiteProductId, salePriceLocal, currencyId, validFrom) VALUES 
    (v_web_prod_id, 8500.00, (SELECT currencyId FROM Currencies WHERE currencyCode = 'CRC'), CURDATE());

    -- 6. CLIENTES Y ÓRDENES
    INSERT INTO Customers (firstName, lastName, email, passwordHash, phone, countryId) VALUES 
    ('Ana', 'García', 'ana.garcia@email.com', 'hash_seguro_123', '8888-9999', v_country_cr_id)
    ON DUPLICATE KEY UPDATE email=email;
    
    SET v_customer_id = LAST_INSERT_ID();

    -- Simulamos una orden de compra
    INSERT INTO Orders (customerId, websiteId, customerAddressId, totalAmountLocal, currencyId, exchangeRateId, exchangeRateSnapshot, totalAmountUsd, status)
    VALUES (v_customer_id, v_website_id, 1, 8500.00, 1, 1, 0.0019, 16.15, 'CONFIRMADA');
    
    SET v_order_id = LAST_INSERT_ID();

    INSERT INTO OrderItems (orderId, websiteProductId, quantity, unitPriceLocal, subtotalLocal)
    VALUES (v_order_id, v_web_prod_id, 1, 8500.00, 8500.00);

    -- 7. LOG
    INSERT INTO ProcessLog (eventSource, eventType, description, status)
    VALUES ('MySQL Seeder', 'INSERT', 'Carga de datos minoristas completada', 'SUCCESS');

END $$

DELIMITER ;

-- Ejecutar el procedimiento
CALL PopulateDynamicBrands();

-- Borrar el procedimiento después de usarlo
DROP PROCEDURE IF EXISTS PopulateDynamicBrands;