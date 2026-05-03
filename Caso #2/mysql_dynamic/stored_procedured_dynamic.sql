USE dynamic_brands_db;

SET NAMES 'utf8mb4' COLLATE 'utf8mb4_0900_ai_ci';
SET CHARACTER SET utf8mb4;

DELIMITER $$

CREATE PROCEDURE sp_log_event(
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
CREATE PROCEDURE sp_upsert_country(
    IN  p_countryName   VARCHAR(100),
    IN  p_isoCode       CHAR(2),
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
     WHERE isoCode COLLATE utf8mb4_0900_ai_ci = p_isoCode COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_upsert_region(
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
     WHERE countryId = p_countryId AND regionName COLLATE utf8mb4_0900_ai_ci = p_regionName COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_upsert_city(
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
     WHERE regionId = p_regionId AND cityName COLLATE utf8mb4_0900_ai_ci = p_cityName COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_insert_address(
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
CREATE PROCEDURE sp_upsert_currency(
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
     WHERE currencyCode COLLATE utf8mb4_0900_ai_ci = p_currencyCode COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_upsert_country_tax(
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
CREATE PROCEDURE sp_upsert_brand(
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
     WHERE brandName COLLATE utf8mb4_0900_ai_ci = p_brandName COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_upsert_website(
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
     WHERE siteUrl COLLATE utf8mb4_0900_ai_ci = p_siteUrl COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_upsert_product_catalog(
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
CREATE PROCEDURE sp_upsert_website_product(
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
CREATE PROCEDURE sp_set_website_product_price(
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
CREATE PROCEDURE sp_sync_inventory_display(
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
CREATE PROCEDURE sp_register_customer(
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
     WHERE email COLLATE utf8mb4_0900_ai_ci = p_email COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_add_customer_address(
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
CREATE PROCEDURE sp_upsert_exchange_rate(
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
CREATE PROCEDURE sp_place_order(
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
CREATE PROCEDURE sp_cancel_order(
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
CREATE PROCEDURE sp_update_order_status(
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
CREATE PROCEDURE sp_register_courier(
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
     WHERE courierName COLLATE utf8mb4_0900_ai_ci = p_courierName COLLATE utf8mb4_0900_ai_ci AND isDeleted = 0
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
CREATE PROCEDURE sp_create_shipping_record(
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
CREATE PROCEDURE sp_update_shipping_status(
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

-- LLenado de tablas:

-- 1. PAISES (11 países idénticos a Etheria)
CALL sp_upsert_country('Costa Rica',      'CR', 1, @country_cr);
CALL sp_upsert_country('Estados Unidos',  'US', 1, @country_us);
CALL sp_upsert_country('Panamá',          'PA', 1, @country_pa);
CALL sp_upsert_country('España',          'ES', 1, @country_es);
CALL sp_upsert_country('Colombia',        'CO', 1, @country_co);
CALL sp_upsert_country('México',          'MX', 1, @country_mx);
CALL sp_upsert_country('Alemania',        'DE', 1, @country_de);
CALL sp_upsert_country('Francia',         'FR', 1, @country_fr);
CALL sp_upsert_country('Japón',           'JP', 1, @country_jp);
CALL sp_upsert_country('Brasil',          'BR', 1, @country_br);
CALL sp_upsert_country('Nicaragua',       'NI', 1, @country_ni);

-- 2. MONEDAS (11 monedas idénticas a Etheria)
CALL sp_upsert_currency('NIO', 'C$',  'Córdoba',               @country_ni, @curr_nio);
CALL sp_upsert_currency('USD', '$',   'Dólar Estadounidense',  @country_us, @curr_usd);
CALL sp_upsert_currency('CRC', '₡',   'Colón Costarricense',   @country_cr, @curr_crc);
CALL sp_upsert_currency('PAB', 'B/.', 'Balboa',                @country_pa, @curr_pab);
CALL sp_upsert_currency('COP', '$',   'Peso Colombiano',       @country_co, @curr_cop);
CALL sp_upsert_currency('MXN', '$',   'Peso Mexicano',         @country_mx, @curr_mxn);
CALL sp_upsert_currency('BRL', 'R$',  'Real Brasileño',        @country_br, @curr_brl);
-- El Euro se inserta una vez (la lógica de upsert actualizará el país dueño al último)
CALL sp_upsert_currency('EUR', '€',   'Euro', @country_es, @curr_eur);
CALL sp_upsert_currency('EUR', '€',   'Euro', @country_fr, @curr_eur);
CALL sp_upsert_currency('EUR', '€',   'Euro', @country_de, @curr_eur);
CALL sp_upsert_currency('JPY', '¥',   'Yen Japonés',           @country_jp, @curr_jpy);

-- 3. REGIONES (15 AdminRegions de Etheria mapeadas a Regions en Dynamic)
CALL sp_upsert_region(@country_ni, 'Costa Caribe Sur',  @reg_ni_1);
CALL sp_upsert_region(@country_ni, 'Managua',           @reg_ni_2);
CALL sp_upsert_region(@country_cr, 'San José',          @reg_cr_1);
CALL sp_upsert_region(@country_cr, 'Cartago',           @reg_cr_2);
CALL sp_upsert_region(@country_pa, 'Panamá',            @reg_pa_1);
CALL sp_upsert_region(@country_mx, 'Ciudad de México',  @reg_mx_1);
CALL sp_upsert_region(@country_mx, 'Jalisco',           @reg_mx_2);
CALL sp_upsert_region(@country_co, 'Bogotá D.C.',       @reg_co_1);
CALL sp_upsert_region(@country_co, 'Antioquia',         @reg_co_2);
CALL sp_upsert_region(@country_br, 'São Paulo',         @reg_br_1);
CALL sp_upsert_region(@country_us, 'Florida',           @reg_us_1);
CALL sp_upsert_region(@country_es, 'Madrid',            @reg_es_1);
CALL sp_upsert_region(@country_fr, 'Île-de-France',     @reg_fr_1);
CALL sp_upsert_region(@country_de, 'Baviera',           @reg_de_1);
CALL sp_upsert_region(@country_jp, 'Tokio',             @reg_jp_1);

-- 4. CIUDADES (15 ciudades idénticas a Etheria)
CALL sp_upsert_city(@reg_ni_1, 'Bluefields',        @city_ni_1);
CALL sp_upsert_city(@reg_ni_2, 'Managua',           @city_ni_2);
CALL sp_upsert_city(@reg_cr_1, 'Escazú',            @city_cr_1);
CALL sp_upsert_city(@reg_cr_2, 'Paraíso',           @city_cr_2);
CALL sp_upsert_city(@reg_pa_1, 'Ciudad de Panamá',  @city_pa_1);
CALL sp_upsert_city(@reg_mx_1, 'Polanco',           @city_mx_1);
CALL sp_upsert_city(@reg_mx_2, 'Guadalajara',       @city_mx_2);
CALL sp_upsert_city(@reg_co_1, 'Bogotá',            @city_co_1);
CALL sp_upsert_city(@reg_co_2, 'Medellín',          @city_co_2);
CALL sp_upsert_city(@reg_br_1, 'Campinas',          @city_br_1);
CALL sp_upsert_city(@reg_us_1, 'Miami',             @city_us_1);
CALL sp_upsert_city(@reg_es_1, 'Madrid',            @city_es_1);
CALL sp_upsert_city(@reg_fr_1, 'París',             @city_fr_1);
CALL sp_upsert_city(@reg_de_1, 'Múnich',            @city_de_1);
CALL sp_upsert_city(@reg_jp_1, 'Shibuya',           @city_jp_1);

-- 5. DIRECCIONES (15 direcciones idénticas a Etheria)
CALL sp_insert_address(@city_ni_1, 'Zona Portuaria, Muelle Municipal',    'HUB Logístico Etheria',        '82100',   @addr_ni_1);
CALL sp_insert_address(@city_ni_2, 'Plaza España, 200m Sur',              'Oficinas Administrativas',     '11001',   @addr_ni_2);
CALL sp_insert_address(@city_cr_1, 'Multiplaza Escazú, Local 45',         'Showroom Dynamic',             '10201',   @addr_cr_1);
CALL sp_insert_address(@city_cr_2, 'Calle Principal, frente al Parque',   'Centro de Distribución Local', '30201',   @addr_cr_2);
CALL sp_insert_address(@city_pa_1, 'Costa del Este, Business Park',       'Torre B, Piso 10',             '0801',    @addr_pa_1);
CALL sp_insert_address(@city_mx_1, 'Av. Presidente Masaryk 123',          'Boutique de Lujo',             '11550',   @addr_mx_1);
CALL sp_insert_address(@city_mx_2, 'Puerta de Hierro',                    'Edificio Corporativo',         '45116',   @addr_mx_2);
CALL sp_insert_address(@city_co_1, 'Carrera 7 # 71-21',                   'Torre Financiera',             '110221',  @addr_co_1);
CALL sp_insert_address(@city_co_2, 'El Poblado, Carrera 43A',             'Milla de Oro',                 '050021',  @addr_co_2);
CALL sp_insert_address(@city_br_1, 'Av. Guilherme Campos, 500',           'Parque Dom Pedro',             '13087',   @addr_br_1);
CALL sp_insert_address(@city_us_1, 'Port of Miami, Terminal G',           'Warehouse de Exportación',     '33132',   @addr_us_1);
CALL sp_insert_address(@city_es_1, 'Calle de Velázquez 50',               'Sourcing Office',              '28001',   @addr_es_1);
CALL sp_insert_address(@city_fr_1, 'Rue du Faubourg Saint-Honoré',        'Cosmética Premium',            '75008',   @addr_fr_1);
CALL sp_insert_address(@city_de_1, 'Marienplatz 1',                       'Aceites Esenciales Bulk',      '80331',   @addr_de_1);
CALL sp_insert_address(@city_jp_1, '2-24-12 Shibuya',                     'Scramble Square',              '150-6101',@addr_jp_1);

-- 6. TIPOS DE CAMBIO (Snapshot 1 USD = X)
CALL sp_upsert_exchange_rate(@curr_nio, 0.0278,  '2026-05-01', 'BCN',                @rate_nio);
CALL sp_upsert_exchange_rate(@curr_usd, 1.0,     '2026-05-01', 'FED',                @rate_usd);
CALL sp_upsert_exchange_rate(@curr_crc, 0.002,   '2026-05-01', 'BCCR',               @rate_crc);
CALL sp_upsert_exchange_rate(@curr_pab, 1.0,     '2026-05-01', 'Banco Nacional',     @rate_pab);
CALL sp_upsert_exchange_rate(@curr_cop, 0.00025, '2026-05-01', 'Banco de la República', @rate_cop);
CALL sp_upsert_exchange_rate(@curr_mxn, 0.0588,  '2026-05-01', 'Banxico',            @rate_mxn);
CALL sp_upsert_exchange_rate(@curr_brl, 0.20,    '2026-05-01', 'BCB',                @rate_brl);
CALL sp_upsert_exchange_rate(@curr_eur, 1.08,    '2026-05-01', 'BCE',                @rate_eur);
CALL sp_upsert_exchange_rate(@curr_jpy, 0.0067,  '2026-05-01', 'BoJ',               @rate_jpy);

-- 7. IMPUESTOS POR PAÍS
CALL sp_upsert_country_tax(@country_ni, 10.00, 'IVA Nicaragua',     '2026-01-01', NULL, @tax_ni);
CALL sp_upsert_country_tax(@country_us,  0.00, 'No federal VAT',    '2026-01-01', NULL, @tax_us);
CALL sp_upsert_country_tax(@country_pa,  7.00, 'ITBMS Panamá',      '2026-01-01', NULL, @tax_pa);
CALL sp_upsert_country_tax(@country_es, 15.00, 'IVA España',        '2026-01-01', NULL, @tax_es);
CALL sp_upsert_country_tax(@country_co, 8.00, 'IVA Colombia',      '2026-01-01', NULL, @tax_co);
CALL sp_upsert_country_tax(@country_mx, 16.00, 'IVA México',        '2026-01-01', NULL, @tax_mx);
CALL sp_upsert_country_tax(@country_br, 17.00, 'ICMS Brasil',       '2026-01-01', NULL, @tax_br);
CALL sp_upsert_country_tax(@country_fr, 14.00, 'TVA Francia',       '2026-01-01', NULL, @tax_fr);
CALL sp_upsert_country_tax(@country_de, 19.00, 'IVA Alemania',      '2026-01-01', NULL, @tax_de);
CALL sp_upsert_country_tax(@country_jp, 10.00, 'Consumo Japón',     '2026-01-01', NULL, @tax_jp);
CALL sp_upsert_country_tax(@country_cr, 13.00, 'IVA Costa Rica',    '2026-01-01', NULL, @tax_cr);

-- 8. MARCAS (IA-Driven, necesarias para el flujo de Dynamic)
CALL sp_upsert_brand('Aura Organics',  'Skincare y cosmética dermatológica',  1, @brand_aura);
CALL sp_upsert_brand('Vital Essence',  'Cuidado capilar y aceites esenciales',1, @brand_vital);
CALL sp_upsert_brand('EcoLuxe',        'Aromaterapia y bienestar',            1, @brand_ecoluxe);
CALL sp_upsert_brand('VitalCore', 'Suplementos y Bienestar', 1, @brand_vitalcore);
CALL sp_upsert_brand('DermaNatura', 'Cuidado Dermatológico y Capilar', 1, @brand_dermanatura);
CALL sp_upsert_brand('AromaLux', 'Aromaterapia y Fragancias Premium', 1, @brand_aromalux);
CALL sp_upsert_brand('PureSense', 'Jabones e Higiene de Lujo', 1, @brand_puresense);
CALL sp_upsert_brand('GiftEssence', 'Kits de Regalo y Bebidas Saludables', 1, @brand_giftessence);

-- 9. SITIOS WEB (9 sitios usando países existentes en Etheria)
-- Aura Organics
CALL sp_upsert_website(@brand_aura,    @country_cr, 'https://aura-cr.com',    'Skincare premium Costa Rica', NULL, '2026-05-01', NULL, @site_1);
CALL sp_upsert_website(@brand_aura,    @country_co, 'https://aura-co.com',    'Skincare premium Colombia',   NULL, '2026-05-01', NULL, @site_2);
CALL sp_upsert_website(@brand_aura,    @country_mx, 'https://aura-mx.com',    'Skincare premium México',     NULL, '2026-05-01', NULL, @site_3);
-- Vital Essence
CALL sp_upsert_website(@brand_vital,   @country_us, 'https://vital-us.com',   'Hair care USA',               NULL, '2026-05-01', NULL, @site_4);
CALL sp_upsert_website(@brand_vital,   @country_ni, 'https://vital-ni.com',   'Hair care Nicaragua',         NULL, '2026-05-01', NULL, @site_5);
CALL sp_upsert_website(@brand_vital,   @country_es, 'https://vital-es.com',   'Hair care España',            NULL, '2026-05-01', NULL, @site_6);
-- EcoLuxe
CALL sp_upsert_website(@brand_ecoluxe, @country_br, 'https://ecoluxe-br.com', 'Aromaterapia Brasil',         NULL, '2026-05-01', NULL, @site_7);
CALL sp_upsert_website(@brand_ecoluxe, @country_fr, 'https://ecoluxe-fr.com', 'Aromaterapia Francia',        NULL, '2026-05-01', NULL, @site_8);
CALL sp_upsert_website(@brand_ecoluxe, @country_jp, 'https://ecoluxe-jp.com', 'Aromaterapia Japón',          NULL, '2026-05-01', NULL, @site_9);
-- VitalCore
CALL sp_upsert_website(@brand_vitalcore, @country_co, 'https://vitalcore.co', 'Bienestar integral para Colombia', NULL, '2025-06-01', NULL, @site_10);
CALL sp_upsert_website(@brand_vitalcore, @country_br, 'https://vitalcore.pe', 'Suplementos naturales para Brasil', NULL, '2025-06-15', NULL, @site_11);
-- DermaNatura
CALL sp_upsert_website(@brand_dermanatura, @country_mx, 'https://dermanat.mx', 'Cuidado de piel premium para Mexico', NULL, '2025-08-01', NULL, @site_12);
-- AromaLux
CALL sp_upsert_website(@brand_aromalux, @country_co, 'https://aromalux.co', 'Aromaterapia y fragancias en Colombia', NULL, '2025-09-01', NULL, @site_13);
CALL sp_upsert_website(@brand_aromalux, @country_cr, 'https://aromalux.cr', 'Aromaterapia y bienestar Costa Rica', NULL, '2025-11-01', NULL, @site_14);
-- PureSense
CALL sp_upsert_website(@brand_puresense, @country_ni, 'https://puresense.pe', 'Higiene artesanal para Nicaragua', NULL, '2025-09-15', NULL, @site_15);
-- GiftEssence
CALL sp_upsert_website(@brand_giftessence, @country_us, 'https://giftessence.us', 'Premium wellness gifts USA', NULL, '2025-07-01', NULL, @site_16);
CALL sp_upsert_website(@brand_giftessence, @country_ni, 'https://giftessence.sv', 'Regalos de bienestar Nicaragua', NULL, '2025-10-01', NULL, @site_17);


-- 10. CATÁLOGO DE PRODUCTOS 
DELIMITER $$
CREATE PROCEDURE sp_populate_dynamic_full()
BEGIN

    DECLARE v_product_id         INT UNSIGNED DEFAULT 1;
    DECLARE v_website_id         INT UNSIGNED;
    DECLARE v_brand_id           INT UNSIGNED;
    DECLARE v_catalog_id         INT UNSIGNED;
    DECLARE v_website_product_id INT UNSIGNED;
    DECLARE v_price_id           INT UNSIGNED;    
    DECLARE v_price              DECIMAL(14,2);
    DECLARE v_currency_id        INT UNSIGNED;

    DECLARE v_curr_crc INT UNSIGNED;
    DECLARE v_curr_cop INT UNSIGNED;
    DECLARE v_curr_mxn INT UNSIGNED;
    DECLARE v_curr_usd INT UNSIGNED;
    DECLARE v_curr_nio INT UNSIGNED;
    DECLARE v_curr_eur INT UNSIGNED;
    DECLARE v_curr_brl INT UNSIGNED;
    DECLARE v_curr_jpy INT UNSIGNED;

    SELECT currencyId INTO v_curr_crc FROM Currencies WHERE currencyCode = 'CRC' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_cop FROM Currencies WHERE currencyCode = 'COP' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_mxn FROM Currencies WHERE currencyCode = 'MXN' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_usd FROM Currencies WHERE currencyCode = 'USD' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_nio FROM Currencies WHERE currencyCode = 'NIO' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_eur FROM Currencies WHERE currencyCode = 'EUR' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_brl FROM Currencies WHERE currencyCode = 'BRL' AND isDeleted = 0 LIMIT 1;
    SELECT currencyId INTO v_curr_jpy FROM Currencies WHERE currencyCode = 'JPY' AND isDeleted = 0 LIMIT 1;

    WHILE v_product_id <= 100 DO
        SET v_website_id = ((v_product_id - 1) % 17) + 1;
        SET v_brand_id = ((v_product_id - 1) % 5) + 1;

        CALL sp_upsert_product_catalog(
            v_product_id,
            v_brand_id,
            v_website_id,
            CONCAT('Producto B2C ', v_product_id),
            'Generado por IA para Dynamic',
            CONCAT('https://cdn.dynamic.com/', v_product_id, '.jpg'),
            'Categoría General',
            'Beneficios de salud',
            1,
            v_catalog_id
        );

        CALL sp_upsert_website_product(v_website_id, v_catalog_id, 0, 1, v_website_product_id);

        CASE v_website_id
            WHEN 1 THEN SET v_price = 25000.00;  SET v_currency_id = v_curr_crc; -- AromaLux CR (Original)
            WHEN 2 THEN SET v_price = 200000.00; SET v_currency_id = v_curr_cop; -- Colombia
            WHEN 3 THEN SET v_price = 850.00;    SET v_currency_id = v_curr_mxn; -- México
            WHEN 4 THEN SET v_price = 250.00;     SET v_currency_id = v_curr_usd; -- Panamá / USD
            WHEN 5 THEN SET v_price = 900.00;    SET v_currency_id = v_curr_nio; -- Nicaragua
            WHEN 6 THEN SET v_price = 450.00;     SET v_currency_id = v_curr_eur; -- Europa
            WHEN 7 THEN SET v_price = 400.00;    SET v_currency_id = v_curr_brl; -- EcoLuxe BR
            WHEN 8 THEN SET v_price = 505.00;     SET v_currency_id = v_curr_eur; -- EcoLuxe FR
            WHEN 9 THEN SET v_price = 6500.00;   SET v_currency_id = v_curr_jpy; -- EcoLuxe JP
            WHEN 10 THEN SET v_price = 185000.00; SET v_currency_id = v_curr_cop; -- VitalCore CO
            WHEN 11 THEN SET v_price = 350.00;    SET v_currency_id = v_curr_brl; -- VitalCore BR
            WHEN 12 THEN SET v_price = 950.00;    SET v_currency_id = v_curr_mxn; -- DermaNatura MX
            WHEN 13 THEN SET v_price = 175000.00; SET v_currency_id = v_curr_cop; -- AromaLux CO
            WHEN 14 THEN SET v_price = 28000.00;  SET v_currency_id = v_curr_crc; -- AromaLux CR
            WHEN 15 THEN SET v_price = 800.00;    SET v_currency_id = v_curr_nio; -- PureSense NI
            WHEN 16 THEN SET v_price = 650.00;     SET v_currency_id = v_curr_usd; -- GiftEssence US
            WHEN 17 THEN SET v_price = 750.00;    SET v_currency_id = v_curr_nio; -- GiftEssence NI
        END CASE;

        CALL sp_set_website_product_price(
            v_website_product_id, v_price, v_currency_id,
            '2026-05-01', NULL,
            v_price_id   
        );

        SET v_product_id = v_product_id + 1;
    END WHILE;
END$$
DELIMITER ;

CALL sp_populate_dynamic_full();
DROP PROCEDURE IF EXISTS sp_populate_dynamic_full;  

-- 11. CLIENTES 
CALL sp_register_customer('María',  'González', 'maria.gonzalez@crcr.com', 'hash123', '+506-8888-7777',   @country_cr, @cust1);
CALL sp_register_customer('John',   'Smith',    'john.smith@us.com',       'hash456', '+1-305-555-1234',  @country_us, @cust2);
CALL sp_register_customer('Carlos', 'López',    'carlos.lopez@coco.com',   'hash789', '+57-300-123-4567', @country_co, @cust3);
CALL sp_register_customer('Ana',    'García',   'ana.garcia@mxmx.com',     'hash012', '+52-55-1234-5678', @country_mx, @cust4);
CALL sp_register_customer('Luis',   'Ramírez',  'luis.ramirez@nini.com',   'hash345', '+505-8123-4567',   @country_ni, @cust5);
CALL sp_register_customer('Alejandro', 'Díaz', 'user001@example.com', 'hash001', '+30932734539', @country_pa, @cust6);
CALL sp_register_customer('Andrés', 'Silva', 'user002@example.com', 'hash002', '+61857232668', @country_ni, @cust7);
CALL sp_register_customer('Ricardo', 'Díaz', 'user003@example.com', 'hash003', '+85950826208', @country_mx, @cust8);
CALL sp_register_customer('Luis', 'Herrera', 'user004@example.com', 'hash004', '+5235555899',  @country_pa, @cust9);
CALL sp_register_customer('Alejandro', 'Rivera', 'user005@example.com', 'hash005', '+13572775194', @country_co, @cust10);
CALL sp_register_customer('Monica', 'Jiménez', 'user006@example.com', 'hash006', '+2875718152',  @country_co, @cust11);
CALL sp_register_customer('Andrea', 'Ortiz', 'user007@example.com', 'hash007', '+20180346223', @country_pa, @cust12);
CALL sp_register_customer('Diego', 'Rivera', 'user008@example.com', 'hash008', '+80843785903', @country_co, @cust13);
CALL sp_register_customer('José', 'Rivera', 'user009@example.com', 'hash009', '+87672972597', @country_co, @cust14);
CALL sp_register_customer('Andrés', 'Ortiz', 'user010@example.com', 'hash010', '+92915401487', @country_cr, @cust15);
CALL sp_register_customer('Natalia', 'Rodríguez', 'user011@example.com', 'hash011', '+80173466219', @country_co, @cust16);
CALL sp_register_customer('Juliana', 'Flores', 'user012@example.com', 'hash012', '+30901834280', @country_co, @cust17);
CALL sp_register_customer('Ana', 'Ortiz', 'user013@example.com', 'hash013', '+91207918827', @country_cr, @cust18);
CALL sp_register_customer('Roberto', 'Flores', 'user014@example.com', 'hash014', '+4149382425',  @country_co, @cust19);
CALL sp_register_customer('María', 'Flores', 'user015@example.com', 'hash015', '+46502482554', @country_br, @cust20);
CALL sp_register_customer('Laura', 'Vargas', 'user016@example.com', 'hash016', '+53707660630', @country_co, @cust21);
CALL sp_register_customer('Sofía', 'Pérez', 'user017@example.com', 'hash017', '+23184791618', @country_mx, @cust22);
CALL sp_register_customer('Ricardo', 'Medina', 'user018@example.com', 'hash018', '+88358589021', @country_cr, @cust23);
CALL sp_register_customer('Alejandro', 'González', 'user019@example.com', 'hash019', '+30595155950', @country_cr, @cust24);
CALL sp_register_customer('Miguel', 'Torres', 'user020@example.com', 'hash020', '+86110090412', @country_cr, @cust25);
CALL sp_register_customer('Miguel', 'Flores', 'user021@example.com', 'hash021', '+87686905284', @country_co, @cust26);
CALL sp_register_customer('Miguel', 'Gómez', 'user022@example.com', 'hash022', '+76421214426', @country_pa, @cust27);

-- 12. DIRECCIONES DE CLIENTES 
CALL sp_add_customer_address(@cust1,  @addr_cr_1, 'Casa',        1, @cust_addr1);
CALL sp_add_customer_address(@cust2,  @addr_us_1, 'Office',      1, @cust_addr2);
CALL sp_add_customer_address(@cust3,  @addr_co_1, 'Apartamento', 1, @cust_addr3);
CALL sp_add_customer_address(@cust4,  @addr_mx_1, 'Casa',        1, @cust_addr4);
CALL sp_add_customer_address(@cust5,  @addr_ni_1, 'Casa',        1, @cust_addr5);
CALL sp_add_customer_address(@cust6,  @addr_pa_1, 'Casa',        1, @cust_addr6);
CALL sp_add_customer_address(@cust7,  @addr_ni_1, 'Casa',        1, @cust_addr7);
CALL sp_add_customer_address(@cust8,  @addr_mx_1, 'Apartamento', 1, @cust_addr8);
CALL sp_add_customer_address(@cust9,  @addr_pa_1, 'Casa',        1, @cust_addr9);
CALL sp_add_customer_address(@cust10, @addr_co_1, 'Casa',        1, @cust_addr10);
CALL sp_add_customer_address(@cust11, @addr_co_1, 'Oficina',     1, @cust_addr11);
CALL sp_add_customer_address(@cust12, @addr_pa_1, 'Casa',        1, @cust_addr12);
CALL sp_add_customer_address(@cust13, @addr_co_1, 'Casa',        1, @cust_addr13);
CALL sp_add_customer_address(@cust14, @addr_co_1, 'Apartamento', 1, @cust_addr14);
CALL sp_add_customer_address(@cust15, @addr_cr_1, 'Casa',        1, @cust_addr15);
CALL sp_add_customer_address(@cust16, @addr_co_1, 'Casa',        1, @cust_addr16);
CALL sp_add_customer_address(@cust17, @addr_co_1, 'Casa',        1, @cust_addr17);
CALL sp_add_customer_address(@cust18, @addr_cr_1, 'Oficina',     1, @cust_addr18);
CALL sp_add_customer_address(@cust19, @addr_co_1, 'Casa',        1, @cust_addr19);
CALL sp_add_customer_address(@cust20, @addr_br_1, 'Casa',        1, @cust_addr20);
CALL sp_add_customer_address(@cust21, @addr_co_1, 'Apartamento', 1, @cust_addr21);
CALL sp_add_customer_address(@cust22, @addr_mx_1, 'Casa',        1, @cust_addr22);
CALL sp_add_customer_address(@cust23, @addr_cr_1, 'Casa',        1, @cust_addr23);
CALL sp_add_customer_address(@cust24, @addr_cr_1, 'Oficina',     1, @cust_addr24);
CALL sp_add_customer_address(@cust25, @addr_cr_1, 'Casa',        1, @cust_addr25);
CALL sp_add_customer_address(@cust26, @addr_co_1, 'Casa',        1, @cust_addr26);
CALL sp_add_customer_address(@cust27, @addr_pa_1, 'Apartamento', 1, @cust_addr27);

-- Curiers:
CALL sp_register_courier(
    'DHL Express',
    'ops@dhl.com',
    '+1-800-225-5345',
    'https://www.dhl.com/track?id={tracking}',
    1,
    @courier_dhl
);

CALL sp_register_courier(
    'FedEx International',
    'support@fedex.com',
    '+1-800-463-3339',
    'https://www.fedex.com/track?id={tracking}',
    1,
    @courier_fedex
);

CALL sp_register_courier(
    'Correos de Costa Rica',
    'correos@correos.go.cr',
    '+506-2202-8000',
    'https://correos.go.cr/rastreo?codigo={tracking}',
    1,
    @courier_correos_cr
);

CALL sp_register_courier(
    'Servientrega',
    'servicioalcliente@servientrega.com',
    '+57-601-307-7050',
    'https://www.servientrega.com/rastreo?guia={tracking}',
    1,
    @courier_servientrega
);

CALL sp_register_courier(
    'Estafeta México',
    'atencion@estafeta.com',
    '+52-55-5950-7070',
    'https://www.estafeta.com/rastreo/{tracking}',
    1,
    @courier_estafeta
);

-- Items
-- Orden 1-A: 2 ítems
CALL sp_place_order(
    @cust1,
    @site_1,
    @cust_addr1,
    @curr_crc,
    @rate_crc,
    '[{"websiteProductId":1,  "quantity":2, "unitPriceLocal":25000.00},
      {"websiteProductId":10, "quantity":1, "unitPriceLocal":25000.00}]',
    @order_1a
);

-- Orden 1-B: 3 ítems
CALL sp_place_order(
    @cust1,
    @site_1,
    @cust_addr1,
    @curr_crc,
    @rate_crc,
    '[{"websiteProductId":19, "quantity":1, "unitPriceLocal":25000.00},
      {"websiteProductId":28, "quantity":3, "unitPriceLocal":25000.00},
      {"websiteProductId":37, "quantity":2, "unitPriceLocal":25000.00}]',
    @order_1b
);

-- -------------------------------------------------------
--  cust2 · John Smith · Estados Unidos
--  site_4 (USD) · moneda @curr_usd · tasa @rate_usd
--  websiteProductIds del site_4: 4, 13, 22, 31, 40
-- -------------------------------------------------------

-- Orden 2-A: 2 ítems
CALL sp_place_order(
    @cust2,
    @site_4,
    @cust_addr2,
    @curr_usd,
    @rate_usd,
    '[{"websiteProductId":4,  "quantity":1, "unitPriceLocal":50.00},
      {"websiteProductId":13, "quantity":2, "unitPriceLocal":50.00}]',
    @order_2a
);

-- Orden 2-B: 3 ítems
CALL sp_place_order(
    @cust2,
    @site_4,
    @cust_addr2,
    @curr_usd,
    @rate_usd,
    '[{"websiteProductId":22, "quantity":4, "unitPriceLocal":50.00},
      {"websiteProductId":31, "quantity":1, "unitPriceLocal":50.00},
      {"websiteProductId":40, "quantity":2, "unitPriceLocal":50.00}]',
    @order_2b
);

-- -------------------------------------------------------
--  cust3 · Carlos López · Colombia
--  site_2 (COP) · moneda @curr_cop · tasa @rate_cop
--  websiteProductIds del site_2: 2, 11, 20, 29, 38
-- -------------------------------------------------------

-- Orden 3-A: 2 ítems
CALL sp_place_order(
    @cust3,
    @site_2,
    @cust_addr3,
    @curr_cop,
    @rate_cop,
    '[{"websiteProductId":2,  "quantity":1, "unitPriceLocal":200000.00},
      {"websiteProductId":11, "quantity":2, "unitPriceLocal":200000.00}]',
    @order_3a
);

-- Orden 3-B: 3 ítems
CALL sp_place_order(
    @cust3,
    @site_2,
    @cust_addr3,
    @curr_cop,
    @rate_cop,
    '[{"websiteProductId":20, "quantity":1, "unitPriceLocal":200000.00},
      {"websiteProductId":29, "quantity":2, "unitPriceLocal":200000.00},
      {"websiteProductId":38, "quantity":1, "unitPriceLocal":200000.00}]',
    @order_3b
);

-- -------------------------------------------------------
--  cust4 · Ana García · México
--  site_3 (MXN) · moneda @curr_mxn · tasa @rate_mxn
--  websiteProductIds del site_3: 3, 12, 21, 30, 39
-- -------------------------------------------------------

-- Orden 4-A: 2 ítems
CALL sp_place_order(
    @cust4,
    @site_3,
    @cust_addr4,
    @curr_mxn,
    @rate_mxn,
    '[{"websiteProductId":3,  "quantity":3, "unitPriceLocal":850.00},
      {"websiteProductId":12, "quantity":2, "unitPriceLocal":850.00}]',
    @order_4a
);

-- Orden 4-B: 3 ítems
CALL sp_place_order(
    @cust4,
    @site_3,
    @cust_addr4,
    @curr_mxn,
    @rate_mxn,
    '[{"websiteProductId":21, "quantity":1, "unitPriceLocal":850.00},
      {"websiteProductId":30, "quantity":4, "unitPriceLocal":850.00},
      {"websiteProductId":39, "quantity":2, "unitPriceLocal":850.00}]',
    @order_4b
);

-- -------------------------------------------------------
--  cust5 · Luis Ramírez · Nicaragua
--  site_5 (NIO) · moneda @curr_nio · tasa @rate_nio
--  websiteProductIds del site_5: 5, 14, 23, 32, 41
-- -------------------------------------------------------

-- Orden 5-A: 2 ítems
CALL sp_place_order(
    @cust5,
    @site_5,
    @cust_addr5,
    @curr_nio,
    @rate_nio,
    '[{"websiteProductId":5,  "quantity":2, "unitPriceLocal":900.00},
      {"websiteProductId":14, "quantity":1, "unitPriceLocal":900.00}]',
    @order_5a
);

-- Orden 5-B: 3 ítems
CALL sp_place_order(
    @cust5,
    @site_5,
    @cust_addr5,
    @curr_nio,
    @rate_nio,
    '[{"websiteProductId":23, "quantity":1, "unitPriceLocal":900.00},
      {"websiteProductId":32, "quantity":3, "unitPriceLocal":900.00},
      {"websiteProductId":41, "quantity":2, "unitPriceLocal":900.00}]',
    @order_5b
);

-- -------------------------------------------------------
-- Clientes 6, 9, 12, 27 · Panamá
-- Nota: Como no hay un sitio específico de Panamá en tu nueva lista, 
-- se mantiene @site_4 o se puede usar @site_16 (USA/Global)
-- -------------------------------------------------------

-- Orden 6-A
CALL sp_place_order(@cust6, @site_4, @cust_addr6, @curr_usd, @rate_usd, 
    '[{"websiteProductId":4, "quantity":1, "unitPriceLocal":100.00}, {"websiteProductId":13, "quantity":1, "unitPriceLocal":100.00}]', @order_6a);

-- Orden 9-A
CALL sp_place_order(@cust9, @site_4, @cust_addr9, @curr_usd, @rate_usd, 
    '[{"websiteProductId":22, "quantity":2, "unitPriceLocal":55.00}]', @order_9a);

-- Orden 12-A
CALL sp_place_order(@cust12, @site_4, @cust_addr12, @curr_usd, @rate_usd, 
    '[{"websiteProductId":31, "quantity":1, "unitPriceLocal":120.00}, {"websiteProductId":40, "quantity":1, "unitPriceLocal":120.00}]', @order_12a);

-- Orden 27-A
CALL sp_place_order(@cust27, @site_4, @cust_addr27, @curr_usd, @rate_usd, 
    '[{"websiteProductId":4, "quantity":3, "unitPriceLocal":40.00}]', @order_27a);

-- -------------------------------------------------------
-- Clientes 7 · Nicaragua
-- Usando @site_15 (PureSense NI) o @site_17 (GiftEssence NI)
-- -------------------------------------------------------

-- Orden 7-A (PureSense NI)
CALL sp_place_order(@cust7, @site_15, @cust_addr7, @curr_nio, @rate_nio, 
    '[{"websiteProductId":5, "quantity":2, "unitPriceLocal":850.00}, {"websiteProductId":14, "quantity":1, "unitPriceLocal":850.00}]', @order_7a);

-- -------------------------------------------------------
-- Clientes 8, 22 · México
-- Usando @site_12 (DermaNatura MX)
-- -------------------------------------------------------

-- Orden 8-A
CALL sp_place_order(@cust8, @site_12, @cust_addr8, @curr_mxn, @rate_mxn, 
    '[{"websiteProductId":3, "quantity":1, "unitPriceLocal":1200.00}, {"websiteProductId":12, "quantity":2, "unitPriceLocal":1200.00}]', @order_8a);

-- Orden 22-A
CALL sp_place_order(@cust22, @site_12, @cust_addr22, @curr_mxn, @rate_mxn, 
    '[{"websiteProductId":21, "quantity":1, "unitPriceLocal":950.00}]', @order_22a);

-- -------------------------------------------------------
-- Clientes 10, 11, 13, 14, 16, 17, 19, 21, 26 · Colombia
-- Usando @site_10 (VitalCore CO) o @site_13 (AromaLux CO)
-- -------------------------------------------------------

-- Orden 10-A (VitalCore)
CALL sp_place_order(@cust10, @site_10, @cust_addr10, @curr_cop, @rate_cop, 
    '[{"websiteProductId":2, "quantity":1, "unitPriceLocal":150000.00}]', @order_10a);

-- Orden 11-A (AromaLux)
CALL sp_place_order(@cust11, @site_13, @cust_addr11, @curr_cop, @rate_cop, 
    '[{"websiteProductId":11, "quantity":2, "unitPriceLocal":180000.00}, {"websiteProductId":20, "quantity":1, "unitPriceLocal":180000.00}]', @order_11a);

-- Orden 13-A (VitalCore)
CALL sp_place_order(@cust13, @site_10, @cust_addr13, @curr_cop, @rate_cop, 
    '[{"websiteProductId":29, "quantity":1, "unitPriceLocal":210000.00}]', @order_13a);

-- Orden 14-A (AromaLux)
CALL sp_place_order(@cust14, @site_13, @cust_addr14, @curr_cop, @rate_cop, 
    '[{"websiteProductId":38, "quantity":3, "unitPriceLocal":150000.00}]', @order_14a);

-- Orden 16-A (VitalCore)
CALL sp_place_order(@cust16, @site_10, @cust_addr16, @curr_cop, @rate_cop, 
    '[{"websiteProductId":2, "quantity":1, "unitPriceLocal":190000.00}]', @order_16a);

-- Orden 17-A (AromaLux)
CALL sp_place_order(@cust17, @site_13, @cust_addr17, @curr_cop, @rate_cop, 
    '[{"websiteProductId":11, "quantity":1, "unitPriceLocal":175000.00}]', @order_17a);

-- Orden 19-A (VitalCore)
CALL sp_place_order(@cust19, @site_10, @cust_addr19, @curr_cop, @rate_cop, 
    '[{"websiteProductId":20, "quantity":2, "unitPriceLocal":160000.00}]', @order_19a);

-- Orden 21-A (AromaLux)
CALL sp_place_order(@cust21, @site_13, @cust_addr21, @curr_cop, @rate_cop, 
    '[{"websiteProductId":29, "quantity":1, "unitPriceLocal":200000.00}]', @order_21a);

-- Orden 26-A (VitalCore)
CALL sp_place_order(@cust26, @site_10, @cust_addr26, @curr_cop, @rate_cop, 
    '[{"websiteProductId":38, "quantity":1, "unitPriceLocal":155000.00}]', @order_26a);

-- -------------------------------------------------------
-- Clientes 15, 18, 23, 24, 25 · Costa Rica
-- Usando @site_14 (AromaLux CR) o @site_1 (Original)
-- -------------------------------------------------------

-- Orden 15-A
CALL sp_place_order(@cust15, @site_14, @cust_addr15, @curr_crc, @rate_crc, 
    '[{"websiteProductId":1, "quantity":2, "unitPriceLocal":22000.00}]', @order_15a);

-- Orden 18-A
CALL sp_place_order(@cust18, @site_14, @cust_addr18, @curr_crc, @rate_crc, 
    '[{"websiteProductId":10, "quantity":1, "unitPriceLocal":30000.00}, {"websiteProductId":19, "quantity":1, "unitPriceLocal":30000.00}]', @order_18a);

-- Orden 23-A
CALL sp_place_order(@cust23, @site_14, @cust_addr23, @curr_crc, @rate_crc, 
    '[{"websiteProductId":28, "quantity":1, "unitPriceLocal":25000.00}]', @order_23a);

-- Orden 24-A
CALL sp_place_order(@cust24, @site_14, @cust_addr24, @curr_crc, @rate_crc, 
    '[{"websiteProductId":37, "quantity":4, "unitPriceLocal":22000.00}]', @order_24a);

-- Orden 25-A
CALL sp_place_order(@cust25, @site_14, @cust_addr25, @curr_crc, @rate_crc, 
    '[{"websiteProductId":1, "quantity":1, "unitPriceLocal":25000.00}]', @order_25a);

-- -------------------------------------------------------
-- Cliente 20 · Brasil
-- Usando @site_11 (VitalCore BR) o @site_7 (EcoLuxe BR)
-- -------------------------------------------------------

-- Orden 20-A (VitalCore BR)
CALL sp_place_order(@cust20, @site_11, @cust_addr20, @curr_usd, @rate_usd, 
    '[{"websiteProductId":13, "quantity":2, "unitPriceLocal":60.00}]', @order_20a);

-- ordenes: 
CALL sp_update_order_status(@order_1a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_1b, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_2a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_2b, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_3a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_3b, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_4a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_4b, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_5a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_5b, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_6a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_7a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_8a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_9a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_10a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_11a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_12a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_13a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_14a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_15a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_16a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_17a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_18a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_19a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_20a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_21a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_22a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_23a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_24a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_25a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_26a, 'CONFIRMADA', NULL);
CALL sp_update_order_status(@order_27a, 'CONFIRMADA', NULL);

CALL sp_create_shipping_record(
    @order_1a, @courier_correos_cr, 'CRCR-2026-000101',
    350.00, @curr_crc, @rate_crc,
    '2026-05-15', @country_cr,
    'CR-2026-00101',
    @ship_1a
);

CALL sp_create_shipping_record(
    @order_1b, @courier_correos_cr, 'CRCR-2026-000102',
    3500.00, @curr_crc, @rate_crc,
    '2026-05-16', @country_cr,
    'CR-2026-00102',
    @ship_1b
);

-- cust2 / US — FedEx International / USD
CALL sp_create_shipping_record(
    @order_2a, @courier_fedex, 'FEDX-2026-US-0201',
    18.00, @curr_usd, @rate_usd,
    '2026-05-10', @country_us,
    'US-2026-00201',
    @ship_2a
);

CALL sp_create_shipping_record(
    @order_2b, @courier_fedex, 'FEDX-2026-US-0202',
    22.50, @curr_usd, @rate_usd,
    '2026-05-11', @country_us,
    'US-2026-00202',
    @ship_2b
);

-- cust3 / CO — Servientrega / COP
CALL sp_create_shipping_record(
    @order_3a, @courier_servientrega, 'SVRG-2026-CO-0301',
    2500.00, @curr_cop, @rate_cop,
    '2026-05-14', @country_co,
    'CO-2026-00301',
    @ship_3a
);

CALL sp_create_shipping_record(
    @order_3b, @courier_servientrega, 'SVRG-2026-CO-0302',
    25000.00, @curr_cop, @rate_cop,
    '2026-05-15', @country_co,
    'CO-2026-00302',
    @ship_3b
);

-- cust4 / MX — Estafeta México / MXN
CALL sp_create_shipping_record(
    @order_4a, @courier_estafeta, 'ESTF-2026-MX-0401',
    120.00, @curr_mxn, @rate_mxn,
    '2026-05-12', @country_mx,
    'MX-2026-00401',
    @ship_4a
);

CALL sp_create_shipping_record(
    @order_4b, @courier_estafeta, 'ESTF-2026-MX-0402',
    110.00, @curr_mxn, @rate_mxn,
    '2026-05-13', @country_mx,
    'MX-2026-00402',
    @ship_4b
);

-- cust5 / NI — DHL Express / NIO
CALL sp_create_shipping_record(
    @order_5a, @courier_dhl, 'DHL-2026-NI-0501',
    100.00, @curr_nio, @rate_nio,
    '2026-05-17', @country_ni,
    'NI-2026-00501',
    @ship_5a
);

CALL sp_create_shipping_record(
    @order_5b, @courier_dhl, 'DHL-2026-NI-0502',
    210.00, @curr_nio, @rate_nio,
    '2026-05-18', @country_ni,
    'NI-2026-00502',
    @ship_5b
);

-- cust6 / PA — DHL Express / USD
CALL sp_create_shipping_record(@order_6a, @courier_dhl, 'DHL-PA-0601', 25.00, @curr_usd, @rate_usd, '2026-05-10', @country_pa, 'PA-2026-00601', @ship_6a);

-- cust7 / NI — DHL Express / NIO
CALL sp_create_shipping_record(@order_7a, @courier_dhl, 'DHL-NI-0701', 10.00, @curr_nio, @rate_nio, '2026-05-12', @country_ni, 'NI-2026-00701', @ship_7a);

-- cust8 / MX — Estafeta / MXN
CALL sp_create_shipping_record(@order_8a, @courier_estafeta, 'EST-MX-0801', 10.00, @curr_mxn, @rate_mxn, '2026-05-14', @country_mx, 'MX-2026-00801', @ship_8a);

-- cust9 / PA — DHL Express / USD
CALL sp_create_shipping_record(@order_9a, @courier_dhl, 'DHL-PA-0901', 28.00, @curr_usd, @rate_usd, '2026-05-15', @country_pa, 'PA-2026-00901', @ship_9a);

-- cust10 a 14 / CO — Servientrega / COP
CALL sp_create_shipping_record(@order_10a, @courier_servientrega, 'SRV-CO-1001', 22000.00, @curr_cop, @rate_cop, '2026-05-10', @country_co, 'CO-2026-01001', @ship_10a);
CALL sp_create_shipping_record(@order_11a, @courier_servientrega, 'SRV-CO-1101', 22000.00, @curr_cop, @rate_cop, '2026-05-11', @country_co, 'CO-2026-01101', @ship_11a);
CALL sp_create_shipping_record(@order_12a, @courier_dhl, 'DHL-PA-1201', 30.00, @curr_usd, @rate_usd, '2026-05-12', @country_pa, 'PA-2026-01201', @ship_12a);
CALL sp_create_shipping_record(@order_13a, @courier_servientrega, 'SRV-CO-1301', 22000.00, @curr_cop, @rate_cop, '2026-05-13', @country_co, 'CO-2026-01301', @ship_13a);
CALL sp_create_shipping_record(@order_14a, @courier_servientrega, 'SRV-CO-1401', 22000.00, @curr_cop, @rate_cop, '2026-05-14', @country_co, 'CO-2026-01401', @ship_14a);

-- cust15 / CR — Correos CR / CRC
CALL sp_create_shipping_record(@order_15a, @courier_correos_cr, 'CR-1501', 2800.00, @curr_crc, @rate_crc, '2026-05-15', @country_cr, 'CR-2026-01501', @ship_15a);

-- cust16, 17, 19 / CO — Servientrega / COP
CALL sp_create_shipping_record(@order_16a, @courier_servientrega, 'SRV-CO-1601', 22000.00, @curr_cop, @rate_cop, '2026-05-16', @country_co, 'CO-2026-01601', @ship_16a);
CALL sp_create_shipping_record(@order_17a, @courier_servientrega, 'SRV-CO-1701', 22000.00, @curr_cop, @rate_cop, '2026-05-17', @country_co, 'CO-2026-01701', @ship_17a);
CALL sp_create_shipping_record(@order_19a, @courier_servientrega, 'SRV-CO-1901', 22000.00, @curr_cop, @rate_cop, '2026-05-19', @country_co, 'CO-2026-01901', @ship_19a);

-- cust18, 23, 24, 25 / CR — Correos CR / CRC
CALL sp_create_shipping_record(@order_18a, @courier_correos_cr, 'CR-1801', 2800.00, @curr_crc, @rate_crc, '2026-05-18', @country_cr, 'CR-2026-01801', @ship_18a);
CALL sp_create_shipping_record(@order_23a, @courier_correos_cr, 'CR-2301', 2800.00, @curr_crc, @rate_crc, '2026-05-20', @country_cr, 'CR-2026-02301', @ship_23a);
CALL sp_create_shipping_record(@order_24a, @courier_correos_cr, 'CR-2401', 2800.00, @curr_crc, @rate_crc, '2026-05-21', @country_cr, 'CR-2026-02401', @ship_24a);
CALL sp_create_shipping_record(@order_25a, @courier_correos_cr, 'CR-2501', 2800.00, @curr_crc, @rate_crc, '2026-05-22', @country_cr, 'CR-2026-02501', @ship_25a);

-- cust20 / BR — FedEx / BRL (Asumiendo variable @curr_brl y @rate_brl)
CALL sp_create_shipping_record(@order_20a, @courier_fedex, 'FDX-BR-2001', 45.00, @curr_usd, @rate_usd, '2026-05-20', @country_br, 'BR-2026-02001', @ship_20a);

-- cust22 / MX — Estafeta / MXN
CALL sp_create_shipping_record(@order_22a, @courier_estafeta, 'EST-MX-2201', 140.00, @curr_mxn, @rate_mxn, '2026-05-22', @country_mx, 'MX-2026-02201', @ship_22a);

-- cust27 / PA — DHL Express / USD
CALL sp_create_shipping_record(@order_27a, @courier_dhl, 'DHL-PA-2701', 35.00, @curr_usd, @rate_usd, '2026-05-23', @country_pa, 'PA-2026-02701', @ship_27a);

-- Entregados
CALL sp_update_shipping_status(@ship_1a, 'ENTREGADO', '2026-05-13');
CALL sp_update_shipping_status(@ship_2a, 'ENTREGADO', '2026-05-09');
CALL sp_update_shipping_status(@ship_3a, 'ENTREGADO', '2026-05-13');
CALL sp_update_shipping_status(@ship_5a, 'ENTREGADO', '2026-05-16');

-- En tránsito
CALL sp_update_shipping_status(@ship_1b, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_2b, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_4a, 'EN_TRANSITO', NULL);

CALL sp_update_shipping_status(@ship_6a, 'ENTREGADO', '2026-05-15');
CALL sp_update_shipping_status(@ship_10a, 'ENTREGADO', '2026-05-15');
CALL sp_update_shipping_status(@ship_15a, 'ENTREGADO', '2026-05-18');

CALL sp_update_shipping_status(@ship_7a, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_8a, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_11a, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_12a, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_13a, 'EN_TRANSITO', NULL);
CALL sp_update_shipping_status(@ship_20a, 'EN_TRANSITO', NULL);