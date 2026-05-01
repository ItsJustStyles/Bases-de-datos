-- ============================================================
--  Etheria Global DB — Stored Procedures
--  Engine  : PostgreSQL 18
--  DB      : etheria_global_db
--  Created : 2026-05-01
--
--  CONVENCIONES
--    · Todos los SPs usan LANGUAGE plpgsql
--    · Parámetros de entrada      : p_  (IN)
--    · Parámetros INOUT (retorno) : p_  (INOUT)
--    · Variables locales          : v_
--    · Cada SP registra actividad en ProcessLog vía sp_log_event
--    · Los SPs de escritura con múltiples tablas usan transacción
--      explícita (BEGIN … COMMIT / EXCEPTION … ROLLBACK)
--
--  COHERENCIA CON DYNAMIC BRANDS
--    · Countries.isoCode     = Dynamic.Countries.isoCode
--    · Currencies.currencyCode = Dynamic.Currencies.currencyCode
--    · Products.productId    → Dynamic.ProductCatalog.etheriaProductId
--    · DispatchOrders.dispatchOrderId → Dynamic.Orders.etheriaDispatchOrderId
-- ============================================================

-- ============================================================
--  HELPER  sp_log_event
--  Inserta un evento en ProcessLog.
--  Usado internamente por todos los demás SPs.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_log_event(
    IN p_eventSource        VARCHAR(150),
    IN p_eventType          VARCHAR(60),
    IN p_affectedTable      VARCHAR(100),
    IN p_affectedRecordId   BIGINT,
    IN p_description        TEXT,
    IN p_status             VARCHAR(20),
    IN p_errorDetail        TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ProcessLog (
        eventSource, eventType, affectedTable,
        affectedRecordId, description, status, errorDetail
    ) VALUES (
        p_eventSource, p_eventType, p_affectedTable,
        p_affectedRecordId, p_description, p_status, p_errorDetail
    );
END;
$$;

-- ============================================================
--  1. sp_upsert_country
--  Crea o actualiza un país.
--  isoCode es la clave de upsert (mismo código que usa Dynamic Brands).
--  Ejemplos coherentes: 'Costa Rica'/'CRI', 'Nicaragua'/'NIC',
--                        'México'/'MEX', 'Colombia'/'COL', 'Estados Unidos'/'USA'
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_country(
    IN    p_countryName   VARCHAR(100),
    IN    p_isoCode       CHAR(3),
    INOUT p_countryId     INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT countryId INTO v_existing
      FROM Countries
     WHERE isoCode = p_isoCode AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Countries (countryName, isoCode)
        VALUES (p_countryName, p_isoCode)
        RETURNING countryId INTO p_countryId;

        CALL sp_log_event('sp_upsert_country', 'INSERT', 'Countries', p_countryId,
            'País creado: ' || p_countryName || ' (' || p_isoCode || ')', 'SUCCESS', NULL);
    ELSE
        UPDATE Countries SET countryName = p_countryName, updatedAt = CURRENT_TIMESTAMP
         WHERE countryId = v_existing;
        p_countryId := v_existing;

        CALL sp_log_event('sp_upsert_country', 'UPDATE', 'Countries', p_countryId,
            'País actualizado: ' || p_countryName, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_country', 'UPSERT', 'Countries', NULL,
        'Error al procesar país: ' || p_countryName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  2. sp_upsert_geographic_region
--  Crea o recupera una región geográfica macro (ej: América Central,
--  América del Sur, Europa, etc.).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_geographic_region(
    IN    p_regionName            VARCHAR(100),
    INOUT p_geographicRegionId    INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT geographicRegionId INTO v_existing
      FROM GeographicRegions
     WHERE regionName = p_regionName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO GeographicRegions (regionName)
        VALUES (p_regionName)
        RETURNING geographicRegionId INTO p_geographicRegionId;

        CALL sp_log_event('sp_upsert_geographic_region', 'INSERT', 'GeographicRegions', p_geographicRegionId,
            'Región geográfica creada: ' || p_regionName, 'SUCCESS', NULL);
    ELSE
        p_geographicRegionId := v_existing;

        CALL sp_log_event('sp_upsert_geographic_region', 'INFO', 'GeographicRegions', p_geographicRegionId,
            'Región geográfica ya existe: ' || p_regionName, 'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_geographic_region', 'UPSERT', 'GeographicRegions', NULL,
        'Error región geográfica: ' || p_regionName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  3. sp_link_country_region
--  Vincula un país a una región geográfica en CountryRegions.
--  Evita duplicados.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_link_country_region(
    IN    p_countryId             INTEGER,
    IN    p_geographicRegionId    INTEGER,
    INOUT p_countryRegionId       INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT countryRegionId INTO v_existing
      FROM CountryRegions
     WHERE countryId          = p_countryId
       AND geographicRegionId = p_geographicRegionId
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO CountryRegions (countryId, geographicRegionId)
        VALUES (p_countryId, p_geographicRegionId)
        RETURNING countryRegionId INTO p_countryRegionId;

        CALL sp_log_event('sp_link_country_region', 'INSERT', 'CountryRegions', p_countryRegionId,
            'Vínculo creado: countryId ' || p_countryId || ' → geographicRegionId ' || p_geographicRegionId,
            'SUCCESS', NULL);
    ELSE
        p_countryRegionId := v_existing;

        CALL sp_log_event('sp_link_country_region', 'INFO', 'CountryRegions', p_countryRegionId,
            'Vínculo ya existe: countryId ' || p_countryId || ' / geographicRegionId ' || p_geographicRegionId,
            'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_link_country_region', 'INSERT', 'CountryRegions', NULL,
        'Error al vincular country/region: ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  4. sp_upsert_admin_region
--  Crea o recupera una región administrativa dentro de un país
--  (equivalente a Regions de Dynamic Brands).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_admin_region(
    IN    p_countryId       INTEGER,
    IN    p_regionName      VARCHAR(100),
    INOUT p_adminRegionId   INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT adminRegionId INTO v_existing
      FROM AdminRegions
     WHERE countryId   = p_countryId
       AND regionName  = p_regionName
       AND isDeleted   = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO AdminRegions (countryId, regionName)
        VALUES (p_countryId, p_regionName)
        RETURNING adminRegionId INTO p_adminRegionId;

        CALL sp_log_event('sp_upsert_admin_region', 'INSERT', 'AdminRegions', p_adminRegionId,
            'Región administrativa creada: ' || p_regionName || ' (countryId: ' || p_countryId || ')',
            'SUCCESS', NULL);
    ELSE
        p_adminRegionId := v_existing;

        CALL sp_log_event('sp_upsert_admin_region', 'INFO', 'AdminRegions', p_adminRegionId,
            'Región administrativa ya existe: ' || p_regionName, 'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_admin_region', 'UPSERT', 'AdminRegions', NULL,
        'Error región administrativa: ' || p_regionName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  5. sp_upsert_city
--  Crea o recupera una ciudad dentro de una región administrativa.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_city(
    IN    p_adminRegionId   INTEGER,
    IN    p_cityName        VARCHAR(100),
    INOUT p_cityId          INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT cityId INTO v_existing
      FROM Cities
     WHERE adminRegionId = p_adminRegionId
       AND cityName      = p_cityName
       AND isDeleted     = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Cities (adminRegionId, cityName)
        VALUES (p_adminRegionId, p_cityName)
        RETURNING cityId INTO p_cityId;

        CALL sp_log_event('sp_upsert_city', 'INSERT', 'Cities', p_cityId,
            'Ciudad creada: ' || p_cityName || ' (adminRegionId: ' || p_adminRegionId || ')',
            'SUCCESS', NULL);
    ELSE
        p_cityId := v_existing;

        CALL sp_log_event('sp_upsert_city', 'INFO', 'Cities', p_cityId,
            'Ciudad ya existe: ' || p_cityName, 'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_city', 'UPSERT', 'Cities', NULL,
        'Error ciudad: ' || p_cityName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  6. sp_insert_address
--  Inserta una nueva dirección física. No hace upsert porque
--  las direcciones se versionan (cada cambio crea un registro nuevo).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_insert_address(
    IN    p_cityId        INTEGER,
    IN    p_addressLine1  VARCHAR(200),
    IN    p_addressLine2  VARCHAR(200),
    IN    p_postalCode    VARCHAR(20),
    INOUT p_addressId     INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO Addresses (cityId, addressLine1, addressLine2, postalCode)
    VALUES (p_cityId, p_addressLine1, p_addressLine2, p_postalCode)
    RETURNING addressId INTO p_addressId;

    CALL sp_log_event('sp_insert_address', 'INSERT', 'Addresses', p_addressId,
        'Dirección creada en cityId: ' || p_cityId, 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_insert_address', 'INSERT', 'Addresses', NULL,
        'Error al insertar dirección: ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  7. sp_upsert_currency
--  Crea o actualiza una moneda.
--  currencyCode es la clave de upsert y debe coincidir con
--  Dynamic Brands (CRC, USD, NIO, MXN, COP, etc.).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_currency(
    IN    p_currencyCode    CHAR(3),
    IN    p_currencySymbol  VARCHAR(5),
    IN    p_currencyName    VARCHAR(80),
    IN    p_countryId       INTEGER,
    INOUT p_currencyId      INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT currencyId INTO v_existing
      FROM Currencies
     WHERE currencyCode = p_currencyCode AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Currencies (currencyCode, currencySymbol, currencyName, countryId)
        VALUES (p_currencyCode, p_currencySymbol, p_currencyName, p_countryId)
        RETURNING currencyId INTO p_currencyId;

        CALL sp_log_event('sp_upsert_currency', 'INSERT', 'Currencies', p_currencyId,
            'Moneda creada: ' || p_currencyCode || ' - ' || p_currencyName, 'SUCCESS', NULL);
    ELSE
        UPDATE Currencies
           SET currencySymbol = COALESCE(p_currencySymbol, currencySymbol),
               currencyName   = p_currencyName,
               countryId      = p_countryId,
               updatedAt      = CURRENT_TIMESTAMP
         WHERE currencyId = v_existing;
        p_currencyId := v_existing;

        CALL sp_log_event('sp_upsert_currency', 'UPDATE', 'Currencies', p_currencyId,
            'Moneda actualizada: ' || p_currencyCode, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_currency', 'UPSERT', 'Currencies', NULL,
        'Error moneda: ' || p_currencyCode || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  8. sp_upsert_person
--  Crea o actualiza una persona (contacto, empleado, etc.).
--  El email es la clave de upsert cuando se provee.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_person(
    IN    p_firstName   VARCHAR(80),
    IN    p_lastName    VARCHAR(80),
    IN    p_email       VARCHAR(150),
    IN    p_phone       VARCHAR(30),
    INOUT p_personId    INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    IF p_email IS NOT NULL THEN
        SELECT personId INTO v_existing
          FROM Persons
         WHERE email = p_email AND isDeleted = FALSE
         LIMIT 1;
    END IF;

    IF v_existing IS NULL THEN
        INSERT INTO Persons (firstName, lastName, email, phone)
        VALUES (p_firstName, p_lastName, p_email, p_phone)
        RETURNING personId INTO p_personId;

        CALL sp_log_event('sp_upsert_person', 'INSERT', 'Persons', p_personId,
            'Persona creada: ' || p_firstName || ' ' || p_lastName, 'SUCCESS', NULL);
    ELSE
        UPDATE Persons
           SET firstName = p_firstName,
               lastName  = p_lastName,
               phone     = COALESCE(p_phone, phone),
               updatedAt = CURRENT_TIMESTAMP
         WHERE personId = v_existing;
        p_personId := v_existing;

        CALL sp_log_event('sp_upsert_person', 'UPDATE', 'Persons', p_personId,
            'Persona actualizada: ' || p_firstName || ' ' || p_lastName, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_person', 'UPSERT', 'Persons', NULL,
        'Error persona: ' || p_firstName || ' ' || p_lastName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  9. sp_upsert_supplier
--  Crea o actualiza un proveedor.
--  La clave de upsert es el nombre del proveedor.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_supplier(
    IN    p_supplierName        VARCHAR(150),
    IN    p_primaryContactId    INTEGER,
    IN    p_countryId           INTEGER,
    IN    p_addressId           INTEGER,
    IN    p_isActive            BOOLEAN,
    INOUT p_supplierId          INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT supplierId INTO v_existing
      FROM Suppliers
     WHERE supplierName = p_supplierName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Suppliers (supplierName, primaryContactId, countryId, addressId, isActive)
        VALUES (p_supplierName, p_primaryContactId, p_countryId, p_addressId, COALESCE(p_isActive, TRUE))
        RETURNING supplierId INTO p_supplierId;

        CALL sp_log_event('sp_upsert_supplier', 'INSERT', 'Suppliers', p_supplierId,
            'Proveedor creado: ' || p_supplierName || ' (countryId: ' || p_countryId || ')',
            'SUCCESS', NULL);
    ELSE
        UPDATE Suppliers
           SET primaryContactId = COALESCE(p_primaryContactId, primaryContactId),
               countryId        = p_countryId,
               addressId        = COALESCE(p_addressId, addressId),
               isActive         = COALESCE(p_isActive, isActive),
               updatedAt        = CURRENT_TIMESTAMP
         WHERE supplierId = v_existing;
        p_supplierId := v_existing;

        CALL sp_log_event('sp_upsert_supplier', 'UPDATE', 'Suppliers', p_supplierId,
            'Proveedor actualizado: ' || p_supplierName, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_supplier', 'UPSERT', 'Suppliers', NULL,
        'Error proveedor: ' || p_supplierName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  10. sp_upsert_product_category
--  Crea o actualiza una categoría de productos.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_product_category(
    IN    p_categoryName        VARCHAR(100),
    IN    p_categoryDescription VARCHAR(200),
    INOUT p_categoryId          INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT categoryId INTO v_existing
      FROM ProductCategories
     WHERE categoryName = p_categoryName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO ProductCategories (categoryName, categoryDescription)
        VALUES (p_categoryName, p_categoryDescription)
        RETURNING categoryId INTO p_categoryId;

        CALL sp_log_event('sp_upsert_product_category', 'INSERT', 'ProductCategories', p_categoryId,
            'Categoría creada: ' || p_categoryName, 'SUCCESS', NULL);
    ELSE
        UPDATE ProductCategories
           SET categoryDescription = COALESCE(p_categoryDescription, categoryDescription),
               updatedAt           = CURRENT_TIMESTAMP
         WHERE categoryId = v_existing;
        p_categoryId := v_existing;

        CALL sp_log_event('sp_upsert_product_category', 'UPDATE', 'ProductCategories', p_categoryId,
            'Categoría actualizada: ' || p_categoryName, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_product_category', 'UPSERT', 'ProductCategories', NULL,
        'Error categoría: ' || p_categoryName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  11. sp_upsert_measurement_unit
--  Crea o recupera una unidad de medida (kg, L, unidad, etc.).
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_measurement_unit(
    IN    p_unitName    VARCHAR(20),
    INOUT p_unitId      INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT unitId INTO v_existing
      FROM MeasurementUnits
     WHERE unitName = p_unitName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO MeasurementUnits (unitName)
        VALUES (p_unitName)
        RETURNING unitId INTO p_unitId;

        CALL sp_log_event('sp_upsert_measurement_unit', 'INSERT', 'MeasurementUnits', p_unitId,
            'Unidad de medida creada: ' || p_unitName, 'SUCCESS', NULL);
    ELSE
        p_unitId := v_existing;

        CALL sp_log_event('sp_upsert_measurement_unit', 'INFO', 'MeasurementUnits', p_unitId,
            'Unidad de medida ya existe: ' || p_unitName, 'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_measurement_unit', 'UPSERT', 'MeasurementUnits', NULL,
        'Error unidad: ' || p_unitName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  12. sp_upsert_product
--  Crea o actualiza un producto maestro.
--  El productId resultante es el etheriaProductId que usará
--  Dynamic Brands al registrar entradas en ProductCatalog.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_product(
    IN    p_productName     VARCHAR(150),
    IN    p_categoryId      INTEGER,
    IN    p_baseUnitId      INTEGER,
    IN    p_unitVolumeM3    DECIMAL(10,6),
    IN    p_unitWeightKg    DECIMAL(10,4),
    INOUT p_productId       INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT productId INTO v_existing
      FROM Products
     WHERE productName = p_productName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO Products (productName, categoryId, baseUnitId, unitVolumeM3, unitWeightKg)
        VALUES (p_productName, p_categoryId, p_baseUnitId, p_unitVolumeM3, p_unitWeightKg)
        RETURNING productId INTO p_productId;

        -- Inicializar stock en cero al crear el producto
        INSERT INTO InventoryStock (productId, stockQuantity)
        VALUES (p_productId, 0)
        ON CONFLICT (productId) DO NOTHING;

        CALL sp_log_event('sp_upsert_product', 'INSERT', 'Products', p_productId,
            'Producto creado: "' || p_productName || '" (productId será etheriaProductId en Dynamic)',
            'SUCCESS', NULL);
    ELSE
        UPDATE Products
           SET categoryId    = p_categoryId,
               baseUnitId    = p_baseUnitId,
               unitVolumeM3  = COALESCE(p_unitVolumeM3, unitVolumeM3),
               unitWeightKg  = COALESCE(p_unitWeightKg, unitWeightKg),
               updatedAt     = CURRENT_TIMESTAMP
         WHERE productId = v_existing;
        p_productId := v_existing;

        CALL sp_log_event('sp_upsert_product', 'UPDATE', 'Products', p_productId,
            'Producto actualizado: "' || p_productName || '"', 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_product', 'UPSERT', 'Products', NULL,
        'Error producto: ' || p_productName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  13. sp_set_product_price
--  Establece el precio de venta USD de Etheria a Dynamic Brands.
--  Cierra el precio anterior (validTo) y crea uno nuevo.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_set_product_price(
    IN    p_productId       INTEGER,
    IN    p_salePriceUsd    DECIMAL(12,4),
    IN    p_validFrom       DATE,
    IN    p_validTo         DATE,
    INOUT p_productPriceId  INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_salePriceUsd <= 0 THEN
        RAISE EXCEPTION 'El precio de venta debe ser mayor a cero.';
    END IF;

    -- Cerrar precio anterior abierto
    UPDATE ProductPrices
       SET validTo = p_validFrom - INTERVAL '1 day'
     WHERE productId = p_productId
       AND validTo IS NULL
       AND validFrom < p_validFrom;

    INSERT INTO ProductPrices (productId, salePriceUsd, validFrom, validTo)
    VALUES (p_productId, p_salePriceUsd, p_validFrom, p_validTo)
    RETURNING productPriceId INTO p_productPriceId;

    CALL sp_log_event('sp_set_product_price', 'INSERT', 'ProductPrices', p_productPriceId,
        'Precio establecido: USD ' || p_salePriceUsd || ' para productId: ' || p_productId ||
        ', desde: ' || p_validFrom, 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_set_product_price', 'INSERT', 'ProductPrices', NULL,
        'Error precio productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  14. sp_add_product_characteristic
--  Agrega una característica (sabor, presentación, ingrediente, etc.)
--  a un producto. No hace upsert para preservar historial.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_add_product_characteristic(
    IN    p_productId               INTEGER,
    IN    p_characteristicType      VARCHAR(50),
    IN    p_characteristicValue     VARCHAR(100),
    INOUT p_characteristicId        INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    -- Evitar duplicados exactos
    SELECT characteristicId INTO v_existing
      FROM ProductCharacteristics
     WHERE productId            = p_productId
       AND characteristicType   = p_characteristicType
       AND characteristicValue  = p_characteristicValue
       AND isDeleted            = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO ProductCharacteristics (productId, characteristicType, characteristicValue)
        VALUES (p_productId, p_characteristicType, p_characteristicValue)
        RETURNING characteristicId INTO p_characteristicId;

        CALL sp_log_event('sp_add_product_characteristic', 'INSERT', 'ProductCharacteristics', p_characteristicId,
            'Característica agregada: [' || p_characteristicType || ': ' || p_characteristicValue ||
            '] para productId: ' || p_productId, 'SUCCESS', NULL);
    ELSE
        p_characteristicId := v_existing;
        CALL sp_log_event('sp_add_product_characteristic', 'INFO', 'ProductCharacteristics', p_characteristicId,
            'Característica ya existe: [' || p_characteristicType || ': ' || p_characteristicValue || ']',
            'INFO', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_add_product_characteristic', 'INSERT', 'ProductCharacteristics', NULL,
        'Error característica productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  15. sp_register_bulk_purchase
--  Registra una compra a granel (importación) de un producto
--  a un proveedor.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_bulk_purchase(
    IN    p_productId           INTEGER,
    IN    p_supplierId          INTEGER,
    IN    p_quantityBulk        DECIMAL(10,3),
    IN    p_unitId              INTEGER,
    IN    p_priceBulkUsd        DECIMAL(12,2),
    IN    p_originCountryId     INTEGER,
    IN    p_weightKg            DECIMAL(10,3),
    IN    p_volumeM3            DECIMAL(10,4),
    IN    p_arrivalDate         TIMESTAMP,
    IN    p_importDutyUsd       DECIMAL(12,2),
    IN    p_freightCostUsd      DECIMAL(12,2),
    INOUT p_bulkId              INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_quantityBulk <= 0 THEN
        RAISE EXCEPTION 'La cantidad de la compra debe ser mayor a cero.';
    END IF;

    INSERT INTO BulkPurchases (
        productId, supplierId, quantityBulk, unitId,
        priceBulkUsd, originCountryId, weightKg, volumeM3,
        arrivalDate, status, importDutyUsd, freightCostUsd
    ) VALUES (
        p_productId, p_supplierId, p_quantityBulk, p_unitId,
        p_priceBulkUsd, p_originCountryId, p_weightKg, p_volumeM3,
        p_arrivalDate, 'EN_TRANSITO',
        COALESCE(p_importDutyUsd, 0.00), COALESCE(p_freightCostUsd, 0.00)
    )
    RETURNING bulkId INTO p_bulkId;

    CALL sp_log_event('sp_register_bulk_purchase', 'INSERT', 'BulkPurchases', p_bulkId,
        'Compra a granel registrada: productId ' || p_productId ||
        ', cantidad: ' || p_quantityBulk || ', proveedor: ' || p_supplierId, 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_register_bulk_purchase', 'INSERT', 'BulkPurchases', NULL,
        'Error compra a granel productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  16. sp_update_bulk_purchase_status
--  Actualiza el estado de una compra a granel.
--  Estados: EN_TRANSITO → RECIBIDO → EN_ALMACEN → DESPACHADO | CANCELADO
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_update_bulk_purchase_status(
    IN p_bulkId         INTEGER,
    IN p_newStatus      VARCHAR(30),
    IN p_arrivalDate    TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists    BOOLEAN;
    v_oldStatus VARCHAR(30);
BEGIN
    SELECT TRUE, status INTO v_exists, v_oldStatus
      FROM BulkPurchases
     WHERE bulkId = p_bulkId AND isDeleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Compra a granel no encontrada (bulkId: %).', p_bulkId;
    END IF;

    UPDATE BulkPurchases
       SET status      = p_newStatus,
           arrivalDate = COALESCE(p_arrivalDate, arrivalDate),
           updatedAt   = CURRENT_TIMESTAMP
     WHERE bulkId = p_bulkId;

    CALL sp_log_event('sp_update_bulk_purchase_status', 'UPDATE', 'BulkPurchases', p_bulkId,
        'Estado compra a granel: ' || v_oldStatus || ' → ' || p_newStatus, 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_update_bulk_purchase_status', 'UPDATE', 'BulkPurchases', p_bulkId,
        'Error actualizar estado bulkId: ' || p_bulkId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  17. sp_upsert_permit_type
--  Crea o recupera un tipo de permiso de importación.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_permit_type(
    IN    p_permitTypeName          VARCHAR(80),
    IN    p_permitTypeDescription   VARCHAR(200),
    INOUT p_permitTypeId            INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    SELECT permitTypeId INTO v_existing
      FROM PermitTypes
     WHERE permitTypeName = p_permitTypeName AND isDeleted = FALSE
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO PermitTypes (permitTypeName, permitTypeDescription)
        VALUES (p_permitTypeName, p_permitTypeDescription)
        RETURNING permitTypeId INTO p_permitTypeId;

        CALL sp_log_event('sp_upsert_permit_type', 'INSERT', 'PermitTypes', p_permitTypeId,
            'Tipo de permiso creado: ' || p_permitTypeName, 'SUCCESS', NULL);
    ELSE
        UPDATE PermitTypes
           SET permitTypeDescription = COALESCE(p_permitTypeDescription, permitTypeDescription)
         WHERE permitTypeId = v_existing;
        p_permitTypeId := v_existing;

        CALL sp_log_event('sp_upsert_permit_type', 'UPDATE', 'PermitTypes', p_permitTypeId,
            'Tipo de permiso actualizado: ' || p_permitTypeName, 'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_permit_type', 'UPSERT', 'PermitTypes', NULL,
        'Error tipo permiso: ' || p_permitTypeName || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  18. sp_register_import_permit
--  Registra un permiso de importación asociado a una compra a granel.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_import_permit(
    IN    p_bulkId              INTEGER,
    IN    p_permitTypeId        INTEGER,
    IN    p_permitNumber        VARCHAR(80),
    IN    p_issuingAuthority    VARCHAR(150),
    IN    p_issueDate           DATE,
    IN    p_expiryDate          DATE,
    IN    p_permitCostUsd       DECIMAL(10,2),
    INOUT p_importPermitId      INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ImportPermits (
        bulkId, permitTypeId, permitNumber,
        issuingAuthority, issueDate, expiryDate, permitCostUsd
    ) VALUES (
        p_bulkId, p_permitTypeId, p_permitNumber,
        p_issuingAuthority, p_issueDate, p_expiryDate,
        COALESCE(p_permitCostUsd, 0.00)
    )
    RETURNING importPermitId INTO p_importPermitId;

    CALL sp_log_event('sp_register_import_permit', 'INSERT', 'ImportPermits', p_importPermitId,
        'Permiso de importación registrado: N° ' || COALESCE(p_permitNumber, 'SIN NÚMERO') ||
        ' (bulkId: ' || p_bulkId || ')', 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_register_import_permit', 'INSERT', 'ImportPermits', NULL,
        'Error permiso bulkId: ' || p_bulkId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  19. sp_create_dispatch_order
--  Crea una orden de despacho para enviar unidades a un país destino.
--  El dispatchOrderId resultante es referenciado en Dynamic Brands
--  como Orders.etheriaDispatchOrderId.
--  externalOrderNumber permite mapear 1-a-1 con la orden de Dynamic.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_create_dispatch_order(
    IN    p_externalOrderNumber     VARCHAR(60),
    IN    p_productId               INTEGER,
    IN    p_quantityDispatched      DECIMAL(12,3),
    IN    p_destinationCountryId    INTEGER,
    IN    p_unitCostUsd             DECIMAL(12,4),
    INOUT p_dispatchOrderId         INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_quantityDispatched <= 0 THEN
        RAISE EXCEPTION 'La cantidad despachada debe ser mayor a cero.';
    END IF;

    INSERT INTO DispatchOrders (
        externalOrderNumber, productId, quantityDispatched,
        destinationCountryId, unitCostUsd, status
    ) VALUES (
        p_externalOrderNumber, p_productId, p_quantityDispatched,
        p_destinationCountryId, p_unitCostUsd, 'PENDIENTE'
    )
    RETURNING dispatchOrderId INTO p_dispatchOrderId;

    CALL sp_log_event('sp_create_dispatch_order', 'INSERT', 'DispatchOrders', p_dispatchOrderId,
        'Orden de despacho creada: productId ' || p_productId ||
        ', cantidad: ' || p_quantityDispatched ||
        ', destino countryId: ' || p_destinationCountryId ||
        COALESCE(', externalOrder: ' || p_externalOrderNumber, ''), 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_create_dispatch_order', 'INSERT', 'DispatchOrders', NULL,
        'Error crear despacho productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  20. sp_update_dispatch_order_status
--  Actualiza el estado de una orden de despacho.
--  Estados: PENDIENTE → EN_ETIQUETADO → LISTO_COURIER
--                     → ENTREGADO_COURIER | CANCELADO
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_update_dispatch_order_status(
    IN p_dispatchOrderId    INTEGER,
    IN p_newStatus          VARCHAR(30),
    IN p_dispatchDate       TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_oldStatus VARCHAR(30);
BEGIN
    SELECT status INTO v_oldStatus
      FROM DispatchOrders
     WHERE dispatchOrderId = p_dispatchOrderId AND isDeleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden de despacho no encontrada (dispatchOrderId: %).', p_dispatchOrderId;
    END IF;

    UPDATE DispatchOrders
       SET status       = p_newStatus,
           dispatchDate = COALESCE(p_dispatchDate, dispatchDate),
           updatedAt    = CURRENT_TIMESTAMP
     WHERE dispatchOrderId = p_dispatchOrderId;

    CALL sp_log_event('sp_update_dispatch_order_status', 'UPDATE', 'DispatchOrders', p_dispatchOrderId,
        'Estado despacho: ' || v_oldStatus || ' → ' || p_newStatus, 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_update_dispatch_order_status', 'UPDATE', 'DispatchOrders', p_dispatchOrderId,
        'Error actualizar despacho: ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  21. sp_register_inventory_movement
--  Registra un movimiento en InventoryHub y actualiza
--  automáticamente el stock consolidado en InventoryStock.
--
--  Reglas de movimiento:
--    ENTRADA (+)  → bulkId obligatorio, dispatchOrderId NULL
--    SALIDA  (-)  → dispatchOrderId obligatorio
--    AJUSTE  (+/-)→ quantity positiva = incremento, negativa = decremento
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_inventory_movement(
    IN    p_productId           INTEGER,
    IN    p_bulkId              INTEGER,
    IN    p_movementType        VARCHAR(20),
    IN    p_quantity            DECIMAL(12,3),
    IN    p_costPerUnitUsd      DECIMAL(12,4),
    IN    p_dispatchOrderId     INTEGER,
    IN    p_notes               VARCHAR(200),
    INOUT p_inventoryHubId      INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stockDelta    DECIMAL(12,3);
    v_currentStock  DECIMAL(12,3);
BEGIN
    -- Calcular el delta según el tipo de movimiento
    IF p_movementType = 'ENTRADA' THEN
        v_stockDelta := ABS(p_quantity);
    ELSIF p_movementType = 'SALIDA' THEN
        v_stockDelta := -ABS(p_quantity);
        IF p_dispatchOrderId IS NULL THEN
            RAISE EXCEPTION 'Una SALIDA requiere un dispatchOrderId válido.';
        END IF;
    ELSIF p_movementType = 'AJUSTE' THEN
        v_stockDelta := p_quantity; -- puede ser positivo o negativo
    ELSE
        RAISE EXCEPTION 'Tipo de movimiento inválido: %. Use ENTRADA, SALIDA o AJUSTE.', p_movementType;
    END IF;

    -- Verificar que el stock no quede negativo
    SELECT stockQuantity INTO v_currentStock
      FROM InventoryStock
     WHERE productId = p_productId;

    IF v_currentStock IS NULL THEN
        RAISE EXCEPTION 'No existe InventoryStock para productId: %. Ejecute sp_upsert_product primero.', p_productId;
    END IF;

    IF (v_currentStock + v_stockDelta) < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente. Stock actual: %, movimiento: %, resultante: %.',
            v_currentStock, v_stockDelta, (v_currentStock + v_stockDelta);
    END IF;

    -- Registrar el movimiento
    INSERT INTO InventoryHub (
        productId, bulkId, movementType,
        quantity, costPerUnitUsd, dispatchOrderId, notes
    ) VALUES (
        p_productId, p_bulkId, p_movementType,
        p_quantity, p_costPerUnitUsd, p_dispatchOrderId, p_notes
    )
    RETURNING inventoryHubId INTO p_inventoryHubId;

    -- Actualizar stock consolidado
    UPDATE InventoryStock
       SET stockQuantity  = stockQuantity + v_stockDelta,
           lastMovementId = p_inventoryHubId,
           updatedAt      = CURRENT_TIMESTAMP
     WHERE productId = p_productId;

    CALL sp_log_event('sp_register_inventory_movement', 'INSERT', 'InventoryHub', p_inventoryHubId,
        'Movimiento registrado: [' || p_movementType || '] ' || p_quantity ||
        ' unidades | productId: ' || p_productId ||
        ' | Stock resultante: ' || (v_currentStock + v_stockDelta), 'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_register_inventory_movement', 'INSERT', 'InventoryHub', NULL,
        'Error movimiento inventario productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  22. sp_recalculate_inventory_stock
--  Recalcula el stock consolidado de un producto sumando todos
--  los movimientos de InventoryHub. Útil para corrección o auditoría.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_recalculate_inventory_stock(
    IN    p_productId           INTEGER,
    INOUT p_recalculatedStock   DECIMAL(12,3)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_newStock      DECIMAL(12,3);
    v_lastMoveId    INTEGER;
BEGIN
    SELECT
        SUM(
            CASE movementType
                WHEN 'ENTRADA' THEN  ABS(quantity)
                WHEN 'SALIDA'  THEN -ABS(quantity)
                WHEN 'AJUSTE'  THEN  quantity
            END
        ),
        MAX(inventoryHubId)
    INTO v_newStock, v_lastMoveId
    FROM InventoryHub
    WHERE productId = p_productId AND isDeleted = FALSE;

    v_newStock := COALESCE(v_newStock, 0);

    IF v_newStock < 0 THEN
        RAISE EXCEPTION 'El stock recalculado es negativo (%). Revise los movimientos del productId: %.', v_newStock, p_productId;
    END IF;

    UPDATE InventoryStock
       SET stockQuantity  = v_newStock,
           lastMovementId = v_lastMoveId,
           updatedAt      = CURRENT_TIMESTAMP
     WHERE productId = p_productId;

    p_recalculatedStock := v_newStock;

    CALL sp_log_event('sp_recalculate_inventory_stock', 'UPDATE', 'InventoryStock', p_productId,
        'Stock recalculado para productId: ' || p_productId || ' → ' || v_newStock || ' unidades',
        'SUCCESS', NULL);
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_recalculate_inventory_stock', 'UPDATE', 'InventoryStock', NULL,
        'Error recalcular stock productId: ' || p_productId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  23. sp_upsert_exchange_rate
--  Crea o actualiza el tipo de cambio de una moneda para una fecha.
--  Coherente con Dynamic Brands: misma moneda (currencyCode),
--  misma lógica de snapshot.
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_exchange_rate(
    IN    p_currencyId        INTEGER,
    IN    p_rateToUsd         DECIMAL(18,6),
    IN    p_rateDate          DATE,
    IN    p_source            VARCHAR(100),
    INOUT p_exchangeRateId    INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing INTEGER;
BEGIN
    IF p_rateToUsd <= 0 THEN
        RAISE EXCEPTION 'La tasa de cambio debe ser mayor a cero.';
    END IF;

    SELECT exchangeRateId INTO v_existing
      FROM ExchangeRates
     WHERE currencyId = p_currencyId AND rateDate = p_rateDate
     LIMIT 1;

    IF v_existing IS NULL THEN
        INSERT INTO ExchangeRates (currencyId, rateToUsd, rateDate, source)
        VALUES (p_currencyId, p_rateToUsd, p_rateDate, p_source)
        RETURNING exchangeRateId INTO p_exchangeRateId;

        CALL sp_log_event('sp_upsert_exchange_rate', 'INSERT', 'ExchangeRates', p_exchangeRateId,
            'Tipo de cambio creado: ' || p_rateToUsd || ' (currencyId: ' || p_currencyId ||
            ', fecha: ' || p_rateDate || ')', 'SUCCESS', NULL);
    ELSE
        UPDATE ExchangeRates
           SET rateToUsd = p_rateToUsd,
               source    = COALESCE(p_source, source)
         WHERE exchangeRateId = v_existing;
        p_exchangeRateId := v_existing;

        CALL sp_log_event('sp_upsert_exchange_rate', 'UPDATE', 'ExchangeRates', p_exchangeRateId,
            'Tipo de cambio actualizado: ' || p_rateToUsd || ' (currencyId: ' || p_currencyId || ')',
            'SUCCESS', NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_upsert_exchange_rate', 'UPSERT', 'ExchangeRates', NULL,
        'Error tipo de cambio currencyId: ' || p_currencyId || ' | ' || SQLERRM, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================
--  FIN DEL ARCHIVO — sp_etheria_global.sql
-- ============================================================


-- Insercion:

-- countryRegions:
DO $$
DECLARE
    -- Lista de nombres de regiones
    v_regiones TEXT[] := ARRAY[
        'América Central',
        'América del Norte',
        'América del Sur',
        'Europa Occidental',
        'Europa del Este',
        'Asia Oriental',
        'Oceanía'
    ];
    v_region_nombre TEXT;
    v_id INTEGER;
BEGIN
    FOREACH v_region_nombre IN ARRAY v_regiones LOOP
        CALL sp_upsert_geographic_region(v_region_nombre, v_id);
        
        RAISE NOTICE 'Región procesada: % (ID: %)', v_region_nombre, v_id;
    END LOOP;
END $$;