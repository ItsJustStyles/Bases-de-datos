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
--  7. INVENTARIO HUB (NICARAGUA)
-- ============================================================

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
    referenceId     INTEGER,
    notes           VARCHAR(200),
    isDeleted       BOOLEAN         NOT NULL DEFAULT FALSE,
    createdAt       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
--  8. ÓRDENES DE DESPACHO
-- ============================================================

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
CREATE INDEX idx_productchar_product      ON ProductCharacteristics(productId);

-- Compras / inventario
CREATE INDEX idx_bulkpurchases_product    ON BulkPurchases(productId);
CREATE INDEX idx_bulkpurchases_supplier   ON BulkPurchases(supplierId);
CREATE INDEX idx_bulkpurchases_status     ON BulkPurchases(status);
CREATE INDEX idx_importpermits_bulk       ON ImportPermits(bulkId);
CREATE INDEX idx_inventoryhub_product     ON InventoryHub(productId);
CREATE INDEX idx_inventoryhub_bulk        ON InventoryHub(bulkId);
CREATE INDEX idx_inventoryhub_movement    ON InventoryHub(movementType);

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

-- LLenado de las tablas:

-- ============================================================
-- SCRIPT DE POBLACIÓN DE DATOS - ETHERIA GLOBAL DB
-- ============================================================

DO $$
DECLARE
    -- Variables para IDs
    v_person_id INT;
    v_admin_id INT;
    v_city_id INT;
    v_address_id INT;
    v_prod_id INT;
    v_bulk_id INT;
    -- Variables de cálculo
    v_qty DECIMAL;
    v_price DECIMAL;
    r_cat RECORD;
    r_prod RECORD;
BEGIN
    RAISE NOTICE 'Iniciando carga de datos...';

    -- 1. GEOGRAFÍA BÁSICA
    INSERT INTO GeographicRegions (regionName) VALUES 
    ('Centroamérica'), ('Asia del Sur'), ('Norte de África'), ('Europa Occidental'), ('Amazonía')
    ON CONFLICT (regionName) DO NOTHING;

    INSERT INTO Countries (countryName, isoCode) VALUES 
    ('Costa Rica', 'CRI'), ('Nicaragua', 'NIC'), ('India', 'IND'), 
    ('Marruecos', 'MAR'), ('Egipto', 'EGY'), ('Brasil', 'BRA'),
    ('Francia', 'FRA'), ('Madagascar', 'MDG')
    ON CONFLICT DO NOTHING;

    INSERT INTO CountryRegions (countryId, geographicRegionId)
    SELECT countryId, (SELECT geographicRegionId FROM GeographicRegions WHERE regionName = 'Centroamérica')
    FROM Countries WHERE isoCode IN ('CRI', 'NIC');

    -- 2. MONEDAS Y TIPOS DE CAMBIO
    INSERT INTO Currencies (currencyCode, currencySymbol, currencyName, countryId) VALUES 
    ('CRC', '₡', 'Colón Costarricense', (SELECT countryId FROM Countries WHERE isoCode = 'CRI')),
    ('NIO', 'C$', 'Córdoba Nicaragüense', (SELECT countryId FROM Countries WHERE isoCode = 'NIC')),
    ('INR', '₹', 'Rupia India', (SELECT countryId FROM Countries WHERE isoCode = 'IND')),
    ('MAD', 'dh', 'Dírham Marroquí', (SELECT countryId FROM Countries WHERE isoCode = 'MAR'))
    ON CONFLICT DO NOTHING;

    INSERT INTO ExchangeRates (currencyId, rateToUsd, rateDate, source)
    SELECT currencyId, 0.0019, CURRENT_DATE, 'BCCR' FROM Currencies WHERE currencyCode = 'CRC';
    
    INSERT INTO ExchangeRates (currencyId, rateToUsd, rateDate, source)
    SELECT currencyId, 0.027, CURRENT_DATE, 'BCN' FROM Currencies WHERE currencyCode = 'NIO';

    -- 3. PRODUCTOS Y UNIDADES
    INSERT INTO MeasurementUnits (unitName) VALUES 
    ('Litros'), ('Kilogramos'), ('Gramos'), ('Unidades'), ('Mililitros')
    ON CONFLICT DO NOTHING;

    INSERT INTO ProductCategories (categoryName, categoryDescription) VALUES 
    ('Aromaterapia', 'Aceites esenciales y difusores'),
    ('Cosmética Capilar', 'Tratamientos naturales para el cabello'),
    ('Cuidado Dermatológico', 'Cremas y ungüentos medicinales exóticos'),
    ('Suplementos Alimenticios', 'Bebidas y polvos curativos')
    ON CONFLICT DO NOTHING;

    -- Generar Productos por cada categoría
    FOR r_cat IN (SELECT categoryId, categoryName FROM ProductCategories) LOOP
        FOR i IN 1..3 LOOP
            INSERT INTO Products (productName, categoryId, baseUnitId, unitVolumeM3, unitWeightKg)
            VALUES (
                'Extracto de ' || r_cat.categoryName || ' Premium ' || i, 
                r_cat.categoryId, 
                (SELECT unitId FROM MeasurementUnits ORDER BY random() LIMIT 1),
                (random() * 0.05)::DECIMAL(10,6),
                (random() * 1.5)::DECIMAL(10,4)
            ) RETURNING productId INTO v_prod_id;

            INSERT INTO ProductCharacteristics (productId, characteristicType, characteristicValue)
            VALUES (v_prod_id, 'Certificación', 'Orgánico USDA');
        END LOOP;
    END LOOP;

    -- 4. PERSONAS, DIRECCIONES Y PROVEEDORES
    -- Crear región para el HUB en Nicaragua
    INSERT INTO AdminRegions (countryId, regionName) 
    VALUES ((SELECT countryId FROM Countries WHERE isoCode = 'NIC'), 'Costa Caribe Norte') 
    RETURNING adminRegionId INTO v_admin_id;

    INSERT INTO Cities (adminRegionId, cityName) VALUES (v_admin_id, 'Puerto Cabezas') 
    RETURNING cityId INTO v_city_id;

    INSERT INTO Addresses (cityId, addressLine1, postalCode) 
    VALUES (v_city_id, 'Muelle Municipal 200m Norte', '70000') 
    RETURNING addressId INTO v_address_id;

    -- Proveedores y Contactos
    INSERT INTO Persons (firstName, lastName, email, phone) 
    VALUES ('Rajesh', 'Sharma', 'contact@himalayan.in', '+91 98765 43210')
    RETURNING personId INTO v_person_id;

    INSERT INTO Suppliers (supplierName, primaryContactId, countryId, addressId) VALUES 
    ('Himalayan Botanics Ltd', v_person_id, (SELECT countryId FROM Countries WHERE isoCode = 'IND'), v_address_id),
    ('Atlas Oasis S.A.', v_person_id, (SELECT countryId FROM Countries WHERE isoCode = 'MAR'), v_address_id)
    ON CONFLICT DO NOTHING;

    -- 5. PERMISOS
    INSERT INTO PermitTypes (permitTypeName, permitTypeDescription) VALUES 
    ('Sanitario', 'Permiso de consumo humano'),
    ('Fitonutricional', 'Certificación botánica'),
    ('Ambiental', 'Extracción sostenible')
    ON CONFLICT DO NOTHING;

    -- 6. IMPORTACIONES (BULK PURCHASES) E INVENTARIO
    FOR i IN 1..20 LOOP
        SELECT productId INTO r_prod FROM Products ORDER BY random() LIMIT 1;
        v_qty := (random() * 450 + 50);
        v_price := (random() * 2000 + 150);

        INSERT INTO BulkPurchases (
            productId, supplierId, quantityBulk, unitId, priceBulkUsd, 
            originCountryId, weightKg, volumeM3, arrivalDate, status, 
            importDutyUsd, freightCostUsd
        )
        VALUES (
            r_prod.productId, 
            (SELECT supplierId FROM Suppliers ORDER BY random() LIMIT 1), 
            v_qty, 
            (SELECT unitId FROM MeasurementUnits ORDER BY random() LIMIT 1),
            v_price, 
            (SELECT countryId FROM Countries ORDER BY random() LIMIT 1),
            (v_qty * 0.4), 
            (v_qty * 0.008), 
            NOW() - (random() * interval '45 days'),
            (ARRAY['EN_TRANSITO', 'RECIBIDO', 'EN_ALMACEN'])[floor(random()*3)+1],
            v_price * 0.12,
            v_price * 0.05
        ) RETURNING bulkId INTO v_bulk_id;

        -- Llenar Inventario HUB para las recibidas
        INSERT INTO InventoryHub (productId, bulkId, movementType, quantity, costPerUnitUsd, notes)
        VALUES (r_prod.productId, v_bulk_id, 'ENTRADA', v_qty, (v_price / v_qty), 'Carga masiva inicial');
    END LOOP;

    -- 7. DESPACHOS (ÓRDENES DE SALIDA)
    FOR i IN 1..12 LOOP
        INSERT INTO DispatchOrders (
            externalOrderNumber, productId, quantityDispatched, dispatchDate, 
            destinationCountryId, status, unitCostUsd
        )
        VALUES (
            'EXP-' || 2000 + i,
            (SELECT productId FROM Products ORDER BY random() LIMIT 1),
            (random() * 15 + 2),
            NOW() - (random() * interval '7 days'),
            (SELECT countryId FROM Countries WHERE isoCode = 'CRI'),
            (ARRAY['PENDIENTE', 'LISTO_COURIER', 'ENTREGADO_COURIER'])[floor(random()*3)+1],
            (random() * 60 + 15)
        );
    END LOOP;

    -- 8. LOG FINAL
    INSERT INTO ProcessLog (eventSource, eventType, description, status)
    VALUES ('System Initializer', 'SEEDING', 'Carga masiva de datos de holding completada exitosamente', 'SUCCESS');

    RAISE NOTICE 'Carga completada. Revisa Metabase en localhost:3000';
END $$;