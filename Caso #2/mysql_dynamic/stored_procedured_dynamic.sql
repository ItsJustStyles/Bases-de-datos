-- ============================================================
--  Dynamic Brands DB — Stored Procedures
--  Engine  : MySQL 8.4
--  DB      : dynamic_brands_db
--  Created : 2026-05-01
--
--  CONVENCIONES
--    · Todos los SPs llevan prefijo sp_
--    · Parámetros de entrada : p_  (IN)
--    · Parámetros de salida  : p_  (OUT / INOUT)
--    · Variables locales     : v_
--    · Cada SP registra su actividad en ProcessLog vía sp_log_event
--    · Los SPs de escritura abren transacción explícita cuando
--      afectan más de una tabla
--
--  COHERENCIA CON ETHERIA
--    · ProductCatalog.etheriaProductId  → Etheria.Products.productId
--    · Orders.etheriaDispatchOrderId    → Etheria.DispatchOrders.dispatchOrderId
--    · Countries y Currencies comparten isoCode / currencyCode entre ambas DBs
-- ============================================================

USE dynamic_brands_db;

DELIMITER $$

-- ============================================================
--  HELPER  sp_log_event
--  Inserta un registro en ProcessLog.
--  Usado internamente por todos los demás SPs.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_log_event(
    IN p_eventSource        VARCHAR(150),
    IN p_eventType          VARCHAR(60),
    IN p_affectedTable      VARCHAR(100),
    IN p_affectedRecordId   BIGINT UNSIGNED,
    IN p_description        TEXT,
    IN p_status             VARCHAR(20),
    IN p_errorDetail        TEXT
)
BEGIN
    INSERT INTO ProcessLog (
        eventSource, eventType, affectedTable,
        affectedRecordId, description, status, errorDetail
    ) VALUES (
        p_eventSource, p_eventType, p_affectedTable,
        p_affectedRecordId, p_description, p_status, p_errorDetail
    );
END$$

-- ============================================================
--  1. sp_upsert_country
--  Crea o actualiza un país.
--  isoCode es la clave de upsert (mismo código que usa Etheria).
--  Ejemplo: 'Costa Rica', 'CRI' | 'Nicaragua', 'NIC' | 'México', 'MEX'
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_country(
    IN  p_countryName   VARCHAR(100),
    IN  p_isoCode       CHAR(3),
    IN  p_isActive      TINYINT(1),
    OUT p_countryId     INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_country', 'UPSERT', 'Countries', NULL,
            CONCAT('Error al procesar país: ', p_countryName, ' | ', @err_msg),
            'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT countryId INTO v_existing
      FROM Countries
     WHERE isoCode = p_isoCode AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Countries (countryName, isoCode, isActive)
        VALUES (p_countryName, p_isoCode, IFNULL(p_isActive, 1));
        SET p_countryId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_country', 'INSERT', 'Countries', p_countryId,
            CONCAT('País creado: ', p_countryName, ' (', p_isoCode, ')'), 'SUCCESS', NULL);
    ELSE
        UPDATE Countries
           SET countryName = p_countryName,
               isActive    = IFNULL(p_isActive, isActive)
         WHERE countryId = v_existing;
        SET p_countryId = v_existing;
        CALL sp_log_event('sp_upsert_country', 'UPDATE', 'Countries', p_countryId,
            CONCAT('País actualizado: ', p_countryName), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  2. sp_upsert_region
--  Crea o recupera una región administrativa dentro de un país.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_region(
    IN  p_countryId     INT UNSIGNED,
    IN  p_regionName    VARCHAR(100),
    OUT p_regionId      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_region', 'UPSERT', 'Regions', NULL,
            CONCAT('Error región: ', p_regionName, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT regionId INTO v_existing
      FROM Regions
     WHERE countryId = p_countryId AND regionName = p_regionName AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Regions (countryId, regionName)
        VALUES (p_countryId, p_regionName);
        SET p_regionId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_region', 'INSERT', 'Regions', p_regionId,
            CONCAT('Región creada: ', p_regionName, ' (countryId: ', p_countryId, ')'), 'SUCCESS', NULL);
    ELSE
        SET p_regionId = v_existing;
        CALL sp_log_event('sp_upsert_region', 'INFO', 'Regions', p_regionId,
            CONCAT('Región ya existe: ', p_regionName), 'INFO', NULL);
    END IF;
END$$

-- ============================================================
--  3. sp_upsert_city
--  Crea o recupera una ciudad dentro de una región.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_city(
    IN  p_regionId  INT UNSIGNED,
    IN  p_cityName  VARCHAR(100),
    OUT p_cityId    INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_city', 'UPSERT', 'Cities', NULL,
            CONCAT('Error ciudad: ', p_cityName, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT cityId INTO v_existing
      FROM Cities
     WHERE regionId = p_regionId AND cityName = p_cityName AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Cities (regionId, cityName)
        VALUES (p_regionId, p_cityName);
        SET p_cityId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_city', 'INSERT', 'Cities', p_cityId,
            CONCAT('Ciudad creada: ', p_cityName, ' (regionId: ', p_regionId, ')'), 'SUCCESS', NULL);
    ELSE
        SET p_cityId = v_existing;
        CALL sp_log_event('sp_upsert_city', 'INFO', 'Cities', p_cityId,
            CONCAT('Ciudad ya existe: ', p_cityName), 'INFO', NULL);
    END IF;
END$$

-- ============================================================
--  4. sp_insert_address
--  Inserta una dirección física. Siempre crea un registro nuevo
--  (las direcciones no se actualizan; se crean versiones nuevas).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_insert_address(
    IN  p_cityId        INT UNSIGNED,
    IN  p_addressLine1  VARCHAR(200),
    IN  p_addressLine2  VARCHAR(200),
    IN  p_postalCode    VARCHAR(20),
    OUT p_addressId     INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_insert_address', 'INSERT', 'Addresses', NULL,
            CONCAT('Error al insertar dirección: ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    INSERT INTO Addresses (cityId, addressLine1, addressLine2, postalCode)
    VALUES (p_cityId, p_addressLine1, p_addressLine2, p_postalCode);

    SET p_addressId = LAST_INSERT_ID();
    CALL sp_log_event('sp_insert_address', 'INSERT', 'Addresses', p_addressId,
        CONCAT('Dirección creada en cityId: ', p_cityId), 'SUCCESS', NULL);
END$$

-- ============================================================
--  5. sp_upsert_currency
--  Crea o actualiza una moneda.
--  Coherencia con Etheria: currencyCode es la clave compartida
--  (CRC, USD, NIO, MXN, COP, etc.)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_currency(
    IN  p_currencyCode      CHAR(3),
    IN  p_currencySymbol    VARCHAR(5),
    IN  p_currencyName      VARCHAR(80),
    IN  p_countryId         INT UNSIGNED,
    OUT p_currencyId        INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_currency', 'UPSERT', 'Currencies', NULL,
            CONCAT('Error moneda: ', p_currencyCode, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT currencyId INTO v_existing
      FROM Currencies
     WHERE currencyCode = p_currencyCode AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Currencies (currencyCode, currencySymbol, currencyName, countryId)
        VALUES (p_currencyCode, p_currencySymbol, p_currencyName, p_countryId);
        SET p_currencyId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_currency', 'INSERT', 'Currencies', p_currencyId,
            CONCAT('Moneda creada: ', p_currencyCode, ' - ', p_currencyName), 'SUCCESS', NULL);
    ELSE
        UPDATE Currencies
           SET currencySymbol = IFNULL(p_currencySymbol, currencySymbol),
               currencyName   = p_currencyName,
               countryId      = p_countryId
         WHERE currencyId = v_existing;
        SET p_currencyId = v_existing;
        CALL sp_log_event('sp_upsert_currency', 'UPDATE', 'Currencies', p_currencyId,
            CONCAT('Moneda actualizada: ', p_currencyCode), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  6. sp_upsert_country_tax
--  Crea o actualiza la tasa impositiva de un país para un período.
--  La clave de upsert es (countryId, validFrom).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_country_tax(
    IN  p_countryId         INT UNSIGNED,
    IN  p_taxRatePercent    DECIMAL(5,2),
    IN  p_regulatoryNotes   TEXT,
    IN  p_validFrom         DATE,
    IN  p_validTo           DATE,
    OUT p_countryTaxId      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_country_tax', 'UPSERT', 'CountryTaxes', NULL,
            CONCAT('Error impuesto countryId: ', p_countryId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT countryTaxId INTO v_existing
      FROM CountryTaxes
     WHERE countryId = p_countryId AND validFrom = p_validFrom AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO CountryTaxes (countryId, taxRatePercent, regulatoryNotes, validFrom, validTo)
        VALUES (p_countryId, p_taxRatePercent, p_regulatoryNotes, p_validFrom, p_validTo);
        SET p_countryTaxId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_country_tax', 'INSERT', 'CountryTaxes', p_countryTaxId,
            CONCAT('Impuesto creado: ', p_taxRatePercent, '% para countryId: ', p_countryId), 'SUCCESS', NULL);
    ELSE
        UPDATE CountryTaxes
           SET taxRatePercent  = p_taxRatePercent,
               regulatoryNotes = p_regulatoryNotes,
               validTo         = p_validTo
         WHERE countryTaxId = v_existing;
        SET p_countryTaxId = v_existing;
        CALL sp_log_event('sp_upsert_country_tax', 'UPDATE', 'CountryTaxes', p_countryTaxId,
            CONCAT('Impuesto actualizado a: ', p_taxRatePercent, '% para countryId: ', p_countryId), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  7. sp_upsert_brand
--  Crea o actualiza una marca white-label.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_brand(
    IN  p_brandName     VARCHAR(150),
    IN  p_brandFocus    VARCHAR(100),
    IN  p_isActive      TINYINT(1),
    OUT p_brandId       INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_brand', 'UPSERT', 'Brands', NULL,
            CONCAT('Error marca: ', p_brandName, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT brandId INTO v_existing
      FROM Brands
     WHERE brandName = p_brandName AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Brands (brandName, brandFocus, isActive)
        VALUES (p_brandName, p_brandFocus, IFNULL(p_isActive, 1));
        SET p_brandId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_brand', 'INSERT', 'Brands', p_brandId,
            CONCAT('Marca creada: ', p_brandName, ' | Foco: ', p_brandFocus), 'SUCCESS', NULL);
    ELSE
        UPDATE Brands
           SET brandFocus = p_brandFocus,
               isActive   = IFNULL(p_isActive, isActive)
         WHERE brandId = v_existing;
        SET p_brandId = v_existing;
        CALL sp_log_event('sp_upsert_brand', 'UPDATE', 'Brands', p_brandId,
            CONCAT('Marca actualizada: ', p_brandName), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  8. sp_upsert_website
--  Crea o actualiza un sitio web de una marca en un país.
--  La URL es la clave de upsert.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_website(
    IN  p_brandId           INT UNSIGNED,
    IN  p_countryId         INT UNSIGNED,
    IN  p_siteUrl           VARCHAR(500),
    IN  p_marketingFocus    VARCHAR(200),
    IN  p_siteConfig        JSON,
    IN  p_launchDate        DATE,
    IN  p_closeDate         DATE,
    OUT p_websiteId         INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_website', 'UPSERT', 'Websites', NULL,
            CONCAT('Error sitio: ', p_siteUrl, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT websiteId INTO v_existing
      FROM Websites
     WHERE siteUrl = p_siteUrl AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Websites (brandId, countryId, siteUrl, marketingFocus, siteConfig, launchDate, closeDate)
        VALUES (p_brandId, p_countryId, p_siteUrl, p_marketingFocus, p_siteConfig, p_launchDate, p_closeDate);
        SET p_websiteId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_website', 'INSERT', 'Websites', p_websiteId,
            CONCAT('Sitio creado: ', p_siteUrl, ' | brandId: ', p_brandId), 'SUCCESS', NULL);
    ELSE
        UPDATE Websites
           SET brandId        = p_brandId,
               countryId      = p_countryId,
               marketingFocus = p_marketingFocus,
               siteConfig     = p_siteConfig,
               launchDate     = IFNULL(p_launchDate, launchDate),
               closeDate      = p_closeDate
         WHERE websiteId = v_existing;
        SET p_websiteId = v_existing;
        CALL sp_log_event('sp_upsert_website', 'UPDATE', 'Websites', p_websiteId,
            CONCAT('Sitio actualizado: ', p_siteUrl), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  9. sp_upsert_product_catalog
--  Crea o actualiza la representación white-label de un producto
--  de Etheria para una marca y sitio específicos.
--  IMPORTANTE: p_etheriaProductId debe existir en Etheria.Products
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_product_catalog(
    IN  p_etheriaProductId      INT UNSIGNED,
    IN  p_brandId               INT UNSIGNED,
    IN  p_websiteId             INT UNSIGNED,
    IN  p_brandedName           VARCHAR(150),
    IN  p_brandedDescription    TEXT,
    IN  p_brandedImageUrl       VARCHAR(500),
    IN  p_categoryLabel         VARCHAR(100),
    IN  p_healthClaims          TEXT,
    IN  p_isActive              TINYINT(1),
    OUT p_catalogProductId      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_product_catalog', 'UPSERT', 'ProductCatalog', NULL,
            CONCAT('Error catálogo etheriaProductId: ', p_etheriaProductId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT catalogProductId INTO v_existing
      FROM ProductCatalog
     WHERE etheriaProductId = p_etheriaProductId
       AND brandId           = p_brandId
       AND websiteId         = p_websiteId
       AND isDeleted         = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO ProductCatalog (
            etheriaProductId, brandId, websiteId,
            brandedName, brandedDescription, brandedImageUrl,
            categoryLabel, healthClaims, isActive
        ) VALUES (
            p_etheriaProductId, p_brandId, p_websiteId,
            p_brandedName, p_brandedDescription, p_brandedImageUrl,
            p_categoryLabel, p_healthClaims, IFNULL(p_isActive, 1)
        );
        SET p_catalogProductId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_product_catalog', 'INSERT', 'ProductCatalog', p_catalogProductId,
            CONCAT('Producto catálogo creado: "', p_brandedName, '" (etheriaProductId: ', p_etheriaProductId, ')'), 'SUCCESS', NULL);
    ELSE
        UPDATE ProductCatalog
           SET brandedName        = p_brandedName,
               brandedDescription = p_brandedDescription,
               brandedImageUrl    = IFNULL(p_brandedImageUrl, brandedImageUrl),
               categoryLabel      = p_categoryLabel,
               healthClaims       = p_healthClaims,
               isActive           = IFNULL(p_isActive, isActive)
         WHERE catalogProductId = v_existing;
        SET p_catalogProductId = v_existing;
        CALL sp_log_event('sp_upsert_product_catalog', 'UPDATE', 'ProductCatalog', p_catalogProductId,
            CONCAT('Producto catálogo actualizado: "', p_brandedName, '"'), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  10. sp_upsert_website_product
--  Vincula un producto del catálogo a un sitio web.
--  Al crear, también inicializa su registro en InventoryDisplay.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_website_product(
    IN  p_websiteId             INT UNSIGNED,
    IN  p_catalogProductId      INT UNSIGNED,
    IN  p_isFeatured            TINYINT(1),
    IN  p_isActive              TINYINT(1),
    OUT p_websiteProductId      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_upsert_website_product', 'UPSERT', 'WebsiteProducts', NULL,
            CONCAT('Error websiteProduct catalogProductId: ', p_catalogProductId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT websiteProductId INTO v_existing
      FROM WebsiteProducts
     WHERE websiteId        = p_websiteId
       AND catalogProductId = p_catalogProductId
       AND isDeleted        = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        START TRANSACTION;

        INSERT INTO WebsiteProducts (websiteId, catalogProductId, isFeatured, isActive)
        VALUES (p_websiteId, p_catalogProductId, IFNULL(p_isFeatured, 0), IFNULL(p_isActive, 1));
        SET p_websiteProductId = LAST_INSERT_ID();

        -- Inicializar inventario visible en cero; se sincronizará desde Etheria
        INSERT INTO InventoryDisplay (websiteProductId, stockDisplay, lastSyncedAt)
        VALUES (p_websiteProductId, 0, NULL);

        COMMIT;
        CALL sp_log_event('sp_upsert_website_product', 'INSERT', 'WebsiteProducts', p_websiteProductId,
            CONCAT('WebsiteProduct creado y InventoryDisplay inicializado (catalogProductId: ', p_catalogProductId, ')'), 'SUCCESS', NULL);
    ELSE
        UPDATE WebsiteProducts
           SET isFeatured = IFNULL(p_isFeatured, isFeatured),
               isActive   = IFNULL(p_isActive, isActive)
         WHERE websiteProductId = v_existing;
        SET p_websiteProductId = v_existing;
        CALL sp_log_event('sp_upsert_website_product', 'UPDATE', 'WebsiteProducts', p_websiteProductId,
            CONCAT('WebsiteProduct actualizado (catalogProductId: ', p_catalogProductId, ')'), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  11. sp_set_website_product_price
--  Cierra el precio activo anterior y establece uno nuevo.
--  Garantiza que siempre exista un único precio abierto por producto.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_set_website_product_price(
    IN  p_websiteProductId  INT UNSIGNED,
    IN  p_salePriceLocal    DECIMAL(14,2),
    IN  p_currencyId        INT UNSIGNED,
    IN  p_validFrom         DATE,
    IN  p_validTo           DATE,
    OUT p_priceId           INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_set_website_product_price', 'INSERT', 'WebsiteProductPrices', NULL,
            CONCAT('Error precio websiteProductId: ', p_websiteProductId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    IF p_salePriceLocal <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio de venta debe ser mayor a cero.';
    END IF;

    START TRANSACTION;

    -- Cerrar precio anterior que esté abierto (validTo IS NULL)
    UPDATE WebsiteProductPrices
       SET validTo = DATE_SUB(p_validFrom, INTERVAL 1 DAY)
     WHERE websiteProductId = p_websiteProductId
       AND validTo IS NULL
       AND validFrom < p_validFrom;

    INSERT INTO WebsiteProductPrices (websiteProductId, salePriceLocal, currencyId, validFrom, validTo)
    VALUES (p_websiteProductId, p_salePriceLocal, p_currencyId, p_validFrom, p_validTo);
    SET p_priceId = LAST_INSERT_ID();

    COMMIT;
    CALL sp_log_event('sp_set_website_product_price', 'INSERT', 'WebsiteProductPrices', p_priceId,
        CONCAT('Precio establecido: ', p_salePriceLocal, ' (websiteProductId: ', p_websiteProductId, ', desde: ', p_validFrom, ')'), 'SUCCESS', NULL);
END$$

-- ============================================================
--  12. sp_sync_inventory_display
--  Actualiza el stock visible de un producto de sitio web.
--  Llamado por el proceso de sincronización con Etheria
--  (InventoryStock.stockQuantity → InventoryDisplay.stockDisplay).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_sync_inventory_display(
    IN  p_websiteProductId      INT UNSIGNED,
    IN  p_stockDisplay          INT UNSIGNED,
    OUT p_inventoryDisplayId    INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_sync_inventory_display', 'UPDATE', 'InventoryDisplay', NULL,
            CONCAT('Error sync inventario websiteProductId: ', p_websiteProductId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    UPDATE InventoryDisplay
       SET stockDisplay = p_stockDisplay,
           lastSyncedAt = CURRENT_TIMESTAMP
     WHERE websiteProductId = p_websiteProductId;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No existe InventoryDisplay para el websiteProductId indicado.';
    END IF;

    SELECT inventoryDisplayId INTO p_inventoryDisplayId
      FROM InventoryDisplay
     WHERE websiteProductId = p_websiteProductId
     LIMIT 1;

    CALL sp_log_event('sp_sync_inventory_display', 'UPDATE', 'InventoryDisplay', p_inventoryDisplayId,
        CONCAT('Stock sincronizado: ', p_stockDisplay, ' unidades (websiteProductId: ', p_websiteProductId, ')'), 'SUCCESS', NULL);
END$$

-- ============================================================
--  13. sp_register_customer
--  Registra un nuevo cliente. El email es único; lanza error si ya existe.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_customer(
    IN  p_firstName     VARCHAR(80),
    IN  p_lastName      VARCHAR(80),
    IN  p_email         VARCHAR(150),
    IN  p_passwordHash  VARCHAR(255),
    IN  p_phone         VARCHAR(30),
    IN  p_countryId     INT UNSIGNED,
    OUT p_customerId    INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_register_customer', 'INSERT', 'Customers', NULL,
            CONCAT('Error registro cliente: ', p_email, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT customerId INTO v_existing
      FROM Customers
     WHERE email = p_email AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El correo electrónico ya se encuentra registrado.';
    END IF;

    INSERT INTO Customers (firstName, lastName, email, passwordHash, phone, countryId)
    VALUES (p_firstName, p_lastName, p_email, p_passwordHash, p_phone, p_countryId);
    SET p_customerId = LAST_INSERT_ID();

    CALL sp_log_event('sp_register_customer', 'INSERT', 'Customers', p_customerId,
        CONCAT('Cliente registrado: ', p_firstName, ' ', p_lastName, ' <', p_email, '>'), 'SUCCESS', NULL);
END$$

-- ============================================================
--  14. sp_add_customer_address
--  Asocia una dirección a un cliente.
--  Si isDefault = 1, quita el flag predeterminado de las demás.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_add_customer_address(
    IN  p_customerId        INT UNSIGNED,
    IN  p_addressId         INT UNSIGNED,
    IN  p_alias             VARCHAR(60),
    IN  p_isDefault         TINYINT(1),
    OUT p_customerAddressId INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_add_customer_address', 'INSERT', 'CustomerAddresses', NULL,
            CONCAT('Error agregar dirección cliente: ', p_customerId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_isDefault = 1 THEN
        UPDATE CustomerAddresses
           SET isDefault = 0
         WHERE customerId = p_customerId AND isDeleted = 0;
    END IF;

    INSERT INTO CustomerAddresses (customerId, addressId, alias, isDefault)
    VALUES (p_customerId, p_addressId, p_alias, IFNULL(p_isDefault, 0));
    SET p_customerAddressId = LAST_INSERT_ID();

    COMMIT;
    CALL sp_log_event('sp_add_customer_address', 'INSERT', 'CustomerAddresses', p_customerAddressId,
        CONCAT('Dirección (alias: "', IFNULL(p_alias, 'Sin alias'), '") agregada al cliente: ', p_customerId), 'SUCCESS', NULL);
END$$

-- ============================================================
--  15. sp_upsert_exchange_rate
--  Crea o actualiza el tipo de cambio de una moneda para una fecha.
--  Los snapshots guardados en Orders/ShippingRecords usan este valor.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_exchange_rate(
    IN  p_currencyId        INT UNSIGNED,
    IN  p_rateToUsd         DECIMAL(18,6),
    IN  p_rateDate          DATE,
    IN  p_source            VARCHAR(100),
    OUT p_exchangeRateId    INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_upsert_exchange_rate', 'UPSERT', 'ExchangeRates', NULL,
            CONCAT('Error tipo de cambio currencyId: ', p_currencyId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    IF p_rateToUsd <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La tasa de cambio debe ser mayor a cero.';
    END IF;

    SELECT exchangeRateId INTO v_existing
      FROM ExchangeRates
     WHERE currencyId = p_currencyId AND rateDate = p_rateDate
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO ExchangeRates (currencyId, rateToUsd, rateDate, source)
        VALUES (p_currencyId, p_rateToUsd, p_rateDate, p_source);
        SET p_exchangeRateId = LAST_INSERT_ID();
        CALL sp_log_event('sp_upsert_exchange_rate', 'INSERT', 'ExchangeRates', p_exchangeRateId,
            CONCAT('Tipo de cambio creado: 1 USD = ', p_rateToUsd, ' (currencyId: ', p_currencyId, ', fecha: ', p_rateDate, ')'), 'SUCCESS', NULL);
    ELSE
        UPDATE ExchangeRates
           SET rateToUsd = p_rateToUsd,
               source    = IFNULL(p_source, source)
         WHERE exchangeRateId = v_existing;
        SET p_exchangeRateId = v_existing;
        CALL sp_log_event('sp_upsert_exchange_rate', 'UPDATE', 'ExchangeRates', p_exchangeRateId,
            CONCAT('Tipo de cambio actualizado: ', p_rateToUsd, ' (currencyId: ', p_currencyId, ')'), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  16. sp_place_order
--  Crea una orden con sus ítems dentro de una transacción.
--  p_items: JSON array de objetos con la estructura:
--    [{"websiteProductId": N, "quantity": N, "unitPriceLocal": N.NN}, ...]
--  El total USD se calcula aplicando el snapshot del tipo de cambio.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_place_order(
    IN  p_customerId            INT UNSIGNED,
    IN  p_websiteId             INT UNSIGNED,
    IN  p_customerAddressId     INT UNSIGNED,
    IN  p_currencyId            INT UNSIGNED,
    IN  p_exchangeRateId        INT UNSIGNED,
    IN  p_items                 JSON,
    OUT p_orderId               INT UNSIGNED
)
BEGIN
    DECLARE v_totalLocal    DECIMAL(14,2) DEFAULT 0.00;
    DECLARE v_rateSnapshot  DECIMAL(18,6);
    DECLARE v_totalUsd      DECIMAL(14,4);
    DECLARE v_itemCount     INT DEFAULT 0;
    DECLARE v_i             INT DEFAULT 0;
    DECLARE v_wpId          INT UNSIGNED;
    DECLARE v_qty           INT UNSIGNED;
    DECLARE v_unitPrice     DECIMAL(14,2);
    DECLARE v_subtotal      DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_place_order', 'INSERT', 'Orders', NULL,
            CONCAT('Error al crear orden customerId: ', p_customerId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    -- Validar que el JSON de items no esté vacío
    IF JSON_LENGTH(p_items) = 0 OR p_items IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe contener al menos un ítem.';
    END IF;

    START TRANSACTION;

    -- Obtener snapshot del tipo de cambio
    SELECT rateToUsd INTO v_rateSnapshot
      FROM ExchangeRates
     WHERE exchangeRateId = p_exchangeRateId;

    IF v_rateSnapshot IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de cambio indicado no existe.';
    END IF;

    -- Calcular total local recorriendo el JSON
    SET v_itemCount = JSON_LENGTH(p_items);
    WHILE v_i < v_itemCount DO
        SET v_unitPrice = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].unitPriceLocal'))) AS DECIMAL(14,2));
        SET v_qty       = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].quantity')))       AS UNSIGNED);
        SET v_totalLocal = v_totalLocal + (v_unitPrice * v_qty);
        SET v_i = v_i + 1;
    END WHILE;

    SET v_totalUsd = ROUND(v_totalLocal / v_rateSnapshot, 4);

    -- Insertar cabecera de la orden
    INSERT INTO Orders (
        customerId, websiteId, customerAddressId,
        currencyId, exchangeRateId, exchangeRateSnapshot,
        totalAmountLocal, totalAmountUsd, status
    ) VALUES (
        p_customerId, p_websiteId, p_customerAddressId,
        p_currencyId, p_exchangeRateId, v_rateSnapshot,
        v_totalLocal, v_totalUsd, 'PENDIENTE'
    );
    SET p_orderId = LAST_INSERT_ID();

    -- Insertar líneas de la orden
    SET v_i = 0;
    WHILE v_i < v_itemCount DO
        SET v_wpId      = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].websiteProductId'))) AS UNSIGNED);
        SET v_qty       = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].quantity')))         AS UNSIGNED);
        SET v_unitPrice = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].unitPriceLocal')))   AS DECIMAL(14,2));
        SET v_subtotal  = v_unitPrice * v_qty;

        INSERT INTO OrderItems (orderId, websiteProductId, quantity, unitPriceLocal, subtotalLocal)
        VALUES (p_orderId, v_wpId, v_qty, v_unitPrice, v_subtotal);

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
    CALL sp_log_event('sp_place_order', 'INSERT', 'Orders', p_orderId,
        CONCAT('Orden creada: ', v_itemCount, ' ítems | Total local: ', v_totalLocal, ' | Total USD: ', v_totalUsd), 'SUCCESS', NULL);
END$$

-- ============================================================
--  17. sp_cancel_order
--  Cancela una orden que aún no haya sido enviada o entregada.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_cancel_order(
    IN p_orderId    INT UNSIGNED,
    IN p_reason     TEXT
)
BEGIN
    DECLARE v_currentStatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_cancel_order', 'UPDATE', 'Orders', p_orderId,
            CONCAT('Error al cancelar orden: ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_currentStatus
      FROM Orders
     WHERE orderId = p_orderId AND isDeleted = 0
     FOR UPDATE;

    IF v_currentStatus IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Orden no encontrada o eliminada.';
    END IF;

    IF v_currentStatus IN ('ENVIADA', 'ENTREGADA', 'CANCELADA', 'REEMBOLSADA') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cancelar una orden con estado ENVIADA, ENTREGADA, CANCELADA o REEMBOLSADA.';
    END IF;

    UPDATE Orders
       SET status = 'CANCELADA'
     WHERE orderId = p_orderId;

    COMMIT;
    CALL sp_log_event('sp_cancel_order', 'UPDATE', 'Orders', p_orderId,
        CONCAT('Orden cancelada. Estado anterior: ', v_currentStatus, '. Motivo: ', IFNULL(p_reason, 'No especificado')), 'SUCCESS', NULL);
END$$

-- ============================================================
--  18. sp_update_order_status
--  Actualiza el estado de una orden y, opcionalmente, vincula
--  el ID de la orden de despacho de Etheria.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_update_order_status(
    IN p_orderId                    INT UNSIGNED,
    IN p_newStatus                  VARCHAR(30),
    IN p_etheriaDispatchOrderId     INT UNSIGNED
)
BEGIN
    DECLARE v_exists TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_update_order_status', 'UPDATE', 'Orders', p_orderId,
            CONCAT('Error actualizar estado orden: ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_exists FROM Orders WHERE orderId = p_orderId AND isDeleted = 0;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Orden no encontrada.';
    END IF;

    UPDATE Orders
       SET status                  = p_newStatus,
           etheriaDispatchOrderId  = IFNULL(p_etheriaDispatchOrderId, etheriaDispatchOrderId)
     WHERE orderId   = p_orderId
       AND isDeleted = 0;

    CALL sp_log_event('sp_update_order_status', 'UPDATE', 'Orders', p_orderId,
        CONCAT('Estado de orden actualizado a: ', p_newStatus,
               IF(p_etheriaDispatchOrderId IS NOT NULL, CONCAT(' | etheriaDispatchOrderId: ', p_etheriaDispatchOrderId), '')),
        'SUCCESS', NULL);
END$$

-- ============================================================
--  19. sp_register_courier
--  Crea o actualiza un courier/transportista.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_courier(
    IN  p_courierName           VARCHAR(100),
    IN  p_contactEmail          VARCHAR(150),
    IN  p_contactPhone          VARCHAR(30),
    IN  p_trackingUrlTemplate   VARCHAR(300),
    IN  p_isActive              TINYINT(1),
    OUT p_courierId             INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        CALL sp_log_event('sp_register_courier', 'UPSERT', 'Couriers', NULL,
            CONCAT('Error courier: ', p_courierName, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    SELECT courierId INTO v_existing
      FROM Couriers
     WHERE courierName = p_courierName AND isDeleted = 0
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Couriers (courierName, contactEmail, contactPhone, trackingUrlTemplate, isActive)
        VALUES (p_courierName, p_contactEmail, p_contactPhone, p_trackingUrlTemplate, IFNULL(p_isActive, 1));
        SET p_courierId = LAST_INSERT_ID();
        CALL sp_log_event('sp_register_courier', 'INSERT', 'Couriers', p_courierId,
            CONCAT('Courier registrado: ', p_courierName), 'SUCCESS', NULL);
    ELSE
        UPDATE Couriers
           SET contactEmail        = IFNULL(p_contactEmail, contactEmail),
               contactPhone        = IFNULL(p_contactPhone, contactPhone),
               trackingUrlTemplate = IFNULL(p_trackingUrlTemplate, trackingUrlTemplate),
               isActive            = IFNULL(p_isActive, isActive)
         WHERE courierId = v_existing;
        SET p_courierId = v_existing;
        CALL sp_log_event('sp_register_courier', 'UPDATE', 'Couriers', p_courierId,
            CONCAT('Courier actualizado: ', p_courierName), 'SUCCESS', NULL);
    END IF;
END$$

-- ============================================================
--  20. sp_create_shipping_record
--  Crea un registro de envío para una orden ya confirmada.
--  Captura el snapshot del tipo de cambio y actualiza la orden
--  a estado EN_PREPARACION si estaba en CONFIRMADA.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_create_shipping_record(
    IN  p_orderId                   INT UNSIGNED,
    IN  p_courierId                 INT UNSIGNED,
    IN  p_trackingCode              VARCHAR(100),
    IN  p_shippingCostLocal         DECIMAL(12,2),
    IN  p_currencyId                INT UNSIGNED,
    IN  p_exchangeRateId            INT UNSIGNED,
    IN  p_estimatedDeliveryDate     DATE,
    IN  p_destinationCountryId      INT UNSIGNED,
    IN  p_healthPermitNumber        VARCHAR(100),
    OUT p_shippingId                INT UNSIGNED
)
BEGIN
    DECLARE v_rateSnapshot  DECIMAL(18,6);
    DECLARE v_orderStatus   VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_create_shipping_record', 'INSERT', 'ShippingRecords', NULL,
            CONCAT('Error envío orderId: ', p_orderId, ' | ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_orderStatus FROM Orders WHERE orderId = p_orderId AND isDeleted = 0 FOR UPDATE;
    IF v_orderStatus IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Orden no encontrada.';
    END IF;

    SELECT rateToUsd INTO v_rateSnapshot FROM ExchangeRates WHERE exchangeRateId = p_exchangeRateId;
    IF v_rateSnapshot IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de cambio no encontrado.';
    END IF;

    INSERT INTO ShippingRecords (
        orderId, courierId, trackingCode,
        shippingCostLocal, currencyId,
        exchangeRateId, exchangeRateSnapshot,
        estimatedDeliveryDate, destinationCountryId,
        healthPermitNumber, status
    ) VALUES (
        p_orderId, p_courierId, p_trackingCode,
        p_shippingCostLocal, p_currencyId,
        p_exchangeRateId, v_rateSnapshot,
        p_estimatedDeliveryDate, p_destinationCountryId,
        p_healthPermitNumber, 'PENDIENTE'
    );
    SET p_shippingId = LAST_INSERT_ID();

    -- Actualizar orden a EN_PREPARACION si procede
    UPDATE Orders
       SET status = 'EN_PREPARACION'
     WHERE orderId = p_orderId AND status = 'CONFIRMADA';

    COMMIT;
    CALL sp_log_event('sp_create_shipping_record', 'INSERT', 'ShippingRecords', p_shippingId,
        CONCAT('Envío creado (orderId: ', p_orderId, ', courier: ', p_courierId,
               IF(p_trackingCode IS NOT NULL, CONCAT(', tracking: ', p_trackingCode), ''), ')'), 'SUCCESS', NULL);
END$$

-- ============================================================
--  21. sp_update_shipping_status
--  Actualiza el estado del envío y sincroniza el estado de la
--  orden correspondiente según la transición de estados.
--  Si el envío queda EN_TRANSITO  → Orden pasa a ENVIADA
--  Si el envío queda ENTREGADO    → Orden pasa a ENTREGADA
--  Si el envío queda FALLIDO      → Orden pasa a CANCELADA
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_update_shipping_status(
    IN p_shippingId             INT UNSIGNED,
    IN p_newStatus              VARCHAR(30),
    IN p_actualDeliveryDate     DATE
)
BEGIN
    DECLARE v_orderId       INT UNSIGNED;
    DECLARE v_currentStatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL sp_log_event('sp_update_shipping_status', 'UPDATE', 'ShippingRecords', p_shippingId,
            CONCAT('Error actualizar envío: ', @err_msg), 'ERROR', @err_msg);
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT orderId, status INTO v_orderId, v_currentStatus
      FROM ShippingRecords
     WHERE shippingId = p_shippingId AND isDeleted = 0
     FOR UPDATE;

    IF v_orderId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro de envío no encontrado.';
    END IF;

    UPDATE ShippingRecords
       SET status             = p_newStatus,
           actualDeliveryDate = IFNULL(p_actualDeliveryDate, actualDeliveryDate)
     WHERE shippingId = p_shippingId;

    -- Cascada de estados hacia la orden
    IF p_newStatus = 'EN_TRANSITO' THEN
        UPDATE Orders SET status = 'ENVIADA'    WHERE orderId = v_orderId;
    ELSEIF p_newStatus = 'ENTREGADO' THEN
        UPDATE Orders SET status = 'ENTREGADA'  WHERE orderId = v_orderId;
    ELSEIF p_newStatus = 'FALLIDO' THEN
        UPDATE Orders SET status = 'CANCELADA'  WHERE orderId = v_orderId;
    END IF;

    COMMIT;
    CALL sp_log_event('sp_update_shipping_status', 'UPDATE', 'ShippingRecords', p_shippingId,
        CONCAT('Estado de envío: ', v_currentStatus, ' → ', p_newStatus, ' (orderId: ', v_orderId, ')'), 'SUCCESS', NULL);
END$$

DELIMITER ;
-- ============================================================
--  FIN DEL ARCHIVO — sp_dynamic_brands.sql
-- ============================================================