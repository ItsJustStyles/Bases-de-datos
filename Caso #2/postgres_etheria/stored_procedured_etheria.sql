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
    IN    p_productId               INTEGER,
    IN    p_quantityDispatched      DECIMAL(12,3),
    IN    p_destinationCountryId    INTEGER,
    IN    p_unitCostUsd             DECIMAL(12,4),
    INOUT p_dispatchOrderId         INTEGER,
    INOUT p_generatedOrderNumber    VARCHAR(60) -- Nuevo parámetro de salida
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country_iso VARCHAR(3);
    v_last_number INTEGER;
    v_prefix      VARCHAR(10);
BEGIN
    SELECT isoCode INTO v_country_iso 
      FROM Countries 
     WHERE countryId = p_destinationCountryId;

    v_prefix := 'EXP-' || v_country_iso || '-';

    SELECT COALESCE(MAX(CAST(SUBSTRING(externalOrderNumber FROM '\d+$') AS INTEGER)), 0)
      INTO v_last_number
      FROM DispatchOrders
     WHERE externalOrderNumber LIKE v_prefix || '%';

    p_generatedOrderNumber := v_prefix || LPAD((v_last_number + 1)::TEXT, 3, '0');

    IF p_quantityDispatched <= 0 THEN
        RAISE EXCEPTION 'La cantidad despachada debe ser mayor a cero.';
    END IF;

    INSERT INTO DispatchOrders (
        externalOrderNumber, productId, quantityDispatched,
        destinationCountryId, unitCostUsd, status
    ) VALUES (
        p_generatedOrderNumber, p_productId, p_quantityDispatched,
        p_destinationCountryId, p_unitCostUsd, 'PENDIENTE'
    )
    RETURNING dispatchOrderId INTO p_dispatchOrderId;

    CALL sp_log_event('sp_create_dispatch_order', 'INSERT', 'DispatchOrders', p_dispatchOrderId,
        'Orden automática creada: ' || p_generatedOrderNumber || ' para producto: ' || p_productId, 'SUCCESS', NULL);

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_event('sp_create_dispatch_order', 'INSERT', 'DispatchOrders', NULL,
        'Error crear despacho automático: ' || SQLERRM, 'ERROR', SQLERRM);
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

-- geographicRegions:
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

-- Paises:
DO $$
DECLARE
    -- Definimos un array de registros (Nombre, ISO)
    paises RECORD;
    v_lista_paises TEXT[][] := ARRAY[
        ['Costa Rica', 'CR'],
        ['Estados Unidos', 'US'],
        ['Panamá', 'PA'],
        ['España', 'ES'],
        ['Colombia', 'CO'],
        ['México', 'MX'],
        ['Alemania', 'DE'],
        ['Francia', 'FR'],
        ['Japón', 'JP'],
        ['Brasil', 'BR'],
        ['Nicaragua', 'NI']
    ];
    v_id INTEGER;
BEGIN
    FOR i IN 1..array_length(v_lista_paises, 1) LOOP
        CALL sp_upsert_country(
            v_lista_paises[i][1],
            v_lista_paises[i][2], 
            v_id                  
        );
        
        RAISE NOTICE 'Procesado: % (ID: %)', v_lista_paises[i][1], v_id;
    END LOOP;
END $$;

-- countryRegions
DO $$
DECLARE
    v_country_id INTEGER;
    v_region_id  INTEGER;
    v_link_id    INTEGER;
	
    v_mapeos TEXT[][] := ARRAY[
        ['CR', 'América Central'],
        ['PA', 'América Central'],
        ['US', 'América del Norte'],
        ['MX', 'América del Norte'],
        ['BR', 'América del Sur'],
        ['CO', 'América del Sur'],
        ['ES', 'Europa Occidental'],
        ['FR', 'Europa Occidental'],
        ['DE', 'Europa Occidental'],
        ['JP', 'Asia Oriental'],
        ['NI', 'América Central']
    ];
BEGIN
    FOR i IN 1..array_length(v_mapeos, 1) LOOP
        SELECT countryId INTO v_country_id 
        FROM Countries 
        WHERE isoCode = v_mapeos[i][1] AND isDeleted = FALSE;

        SELECT geographicRegionId INTO v_region_id 
        FROM GeographicRegions 
        WHERE regionName = v_mapeos[i][2] AND isDeleted = FALSE;

        IF v_country_id IS NOT NULL AND v_region_id IS NOT NULL THEN
            CALL sp_link_country_region(v_country_id, v_region_id, v_link_id);
            RAISE NOTICE 'Vínculo exitoso: % -> % (ID: %)', v_mapeos[i][1], v_mapeos[i][2], v_link_id;
        ELSE
            RAISE WARNING 'No se pudo encontrar país (%) o región (%)', v_mapeos[i][1], v_mapeos[i][2];
        END IF;
    END LOOP;
END $$;

-- adminRegions:
DO $$
DECLARE
    v_country_id INTEGER;
    v_admin_id   INTEGER;
    v_reg_dato   TEXT[];
    v_lista_admin TEXT[][] := ARRAY[
        ['NI', 'Costa Caribe Sur'], 
        ['NI', 'Managua'],
        ['CR', 'San José'],
        ['CR', 'Cartago'],
        ['PA', 'Panamá'],
        ['MX', 'Ciudad de México'],
        ['MX', 'Jalisco'],
        ['CO', 'Bogotá D.C.'],
        ['CO', 'Antioquia'],
        ['BR', 'São Paulo'],
        ['US', 'Florida'],
        ['ES', 'Madrid'],
        ['FR', 'Île-de-France'],
        ['DE', 'Baviera'],
        ['JP', 'Tokio']
    ];
BEGIN
    FOR i IN 1..array_length(v_lista_admin, 1) LOOP
        SELECT countryId INTO v_country_id 
        FROM Countries 
        WHERE isoCode = v_lista_admin[i][1] AND isDeleted = FALSE;

        IF v_country_id IS NOT NULL THEN
            CALL sp_upsert_admin_region(v_country_id, v_lista_admin[i][2], v_admin_id);
            RAISE NOTICE 'Insertada región: % para el país %', v_lista_admin[i][2], v_lista_admin[i][1];
        ELSE
            RAISE WARNING 'No se encontró el país con ISO: %', v_lista_admin[i][1];
        END IF;
    END LOOP;
END $$;

-- cities
DO $$
DECLARE
    v_admin_id INTEGER;
    v_city_id  INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['NI', 'Costa Caribe Sur', 'Bluefields'],
        ['NI', 'Managua', 'Managua'],
        
        ['CR', 'San José', 'Escazú'],
        ['CR', 'Cartago', 'Paraíso'], 
        ['PA', 'Panamá', 'Ciudad de Panamá'],
        ['MX', 'Ciudad de México', 'Polanco'],
        ['MX', 'Jalisco', 'Guadalajara'],
        ['CO', 'Bogotá D.C.', 'Bogotá'],
        ['CO', 'Antioquia', 'Medellín'],
        ['BR', 'São Paulo', 'Campinas'],
        
        ['US', 'Florida', 'Miami'],
        ['ES', 'Madrid', 'Madrid'],
        ['FR', 'Île-de-France', 'París'],
        ['DE', 'Baviera', 'Múnich'],
        ['JP', 'Tokio', 'Shibuya']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT ar.adminRegionId INTO v_admin_id
        FROM AdminRegions ar
        JOIN Countries c ON ar.countryId = c.countryId
        WHERE c.isoCode = v_datos[i][1] 
          AND ar.regionName = v_datos[i][2]
          AND ar.isDeleted = FALSE;

        IF v_admin_id IS NOT NULL THEN
            CALL sp_upsert_city(v_admin_id, v_datos[i][3], v_city_id);
            RAISE NOTICE 'Ciudad procesada: % (ID: %) en %', v_datos[i][3], v_city_id, v_datos[i][2];
        ELSE
            RAISE WARNING 'No se encontró la región % para el país %', v_datos[i][2], v_datos[i][1];
        END IF;
    END LOOP;
END $$;

-- addresses
DO $$
DECLARE
    v_city_id    INTEGER;
    v_address_id INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['NI', 'Costa Caribe Sur', 'Bluefields', 'Zona Portuaria, Muelle Municipal', 'HUB Logístico Etheria', '82100'],
        ['NI', 'Managua', 'Managua', 'Plaza España, 200m Sur', 'Oficinas Administrativas', '11001'],
        
        ['CR', 'San José', 'Escazú', 'Multiplaza Escazú, Local 45', 'Showroom Dynamic', '10201'],
        ['CR', 'Cartago', 'Paraíso', 'Calle Principal, frente al Parque', 'Centro de Distribución Local', '30201'],
        ['PA', 'Panamá', 'Ciudad de Panamá', 'Costa del Este, Business Park', 'Torre B, Piso 10', '0801'],
        ['MX', 'Ciudad de México', 'Polanco', 'Av. Presidente Masaryk 123', 'Boutique de Lujo', '11550'],
        ['MX', 'Jalisco', 'Guadalajara', 'Puerta de Hierro', 'Edificio Corporativo', '45116'],
        ['CO', 'Bogotá D.C.', 'Bogotá', 'Carrera 7 # 71-21', 'Torre Financiera', '110221'],
        ['CO', 'Antioquia', 'Medellín', 'El Poblado, Carrera 43A', 'Milla de Oro', '050021'],
        ['BR', 'São Paulo', 'Campinas', 'Av. Guilherme Campos, 500', 'Parque Dom Pedro', '13087'],
        
        ['US', 'Florida', 'Miami', 'Port of Miami, Termina G', 'Warehouse de Exportación', '33132'],
        ['ES', 'Madrid', 'Madrid', 'Calle de Velázquez 50', 'Sourcing Office', '28001'],
        ['FR', 'Île-de-France', 'París', 'Rue du Faubourg Saint-Honoré', 'Cosmética Premium', '75008'],
        ['DE', 'Baviera', 'Múnich', 'Marienplatz 1', 'Aceites Esenciales Bulk', '80331'],
        ['JP', 'Tokio', 'Shibuya', '2-24-12 Shibuya', 'Scramble Square', '150-6101']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT ct.cityId INTO v_city_id
        FROM Cities ct
        JOIN AdminRegions ar ON ct.adminRegionId = ar.adminRegionId
        JOIN Countries c ON ar.countryId = c.countryId
        WHERE c.isoCode = v_datos[i][1] 
          AND ar.regionName = v_datos[i][2]
          AND ct.cityName = v_datos[i][3]
          AND ct.isDeleted = FALSE;

        IF v_city_id IS NOT NULL THEN
            CALL sp_insert_address(
                v_city_id, 
                v_datos[i][4], 
                v_datos[i][5], 
                v_datos[i][6], 
                v_address_id
            );
            RAISE NOTICE 'Dirección creada en % para % (ID: %)', v_datos[i][3], v_datos[i][1], v_address_id;
        ELSE
            RAISE WARNING 'No se encontró la ciudad % para vincular la dirección', v_datos[i][3];
        END IF;
    END LOOP;
END $$;

-- currency
DO $$
DECLARE
    v_country_id INTEGER;
    v_curr_id    INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['NI', 'NIO', 'C$', 'Córdoba'],
        ['US', 'USD', '$',  'Dólar Estadounidense'],
        ['CR', 'CRC', '₡',  'Colón Costarricense'],
        ['PA', 'PAB', 'B/.', 'Balboa'],
        ['CO', 'COP', '$',  'Peso Colombiano'],
        ['MX', 'MXN', '$',  'Peso Mexicano'],
        ['BR', 'BRL', 'R$', 'Real Brasileño'],
        ['ES', 'EUR', '€',  'Euro'],
        ['FR', 'EUR', '€',  'Euro'],
        ['DE', 'EUR', '€',  'Euro'],
        ['JP', 'JPY', '¥',  'Yen Japonés']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT countryId INTO v_country_id 
        FROM Countries 
        WHERE isoCode = v_datos[i][1] AND isDeleted = FALSE;

        IF v_country_id IS NOT NULL THEN
            CALL sp_upsert_currency(
                v_datos[i][2], 
                v_datos[i][3], 
                v_datos[i][4], 
                v_country_id, 
                v_curr_id     
            );
            RAISE NOTICE 'Moneda procesada: % (%) para el país %', v_datos[i][4], v_datos[i][2], v_datos[i][1];
        ELSE
            RAISE WARNING 'No se encontró el país con ISO % para insertar su moneda', v_datos[i][1];
        END IF;
    END LOOP;
END $$;

-- exchanges_rates
DO $$
DECLARE
    v_curr_id     INTEGER;
    v_rate_id     INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['NIO', '0.027',   'Banco Central de Nicaragua'],
        ['CRC', '0.0019',  'Banco Central de Costa Rica'],
        ['PAB', '1.00',    'Paridad fija'],
        ['COP', '0.00025', 'Banco de la República'],
        ['MXN', '0.059',   'Banxico'],
        ['BRL', '0.20',    'Banco Central do Brasil'],
        ['EUR', '1.08',    'European Central Bank'],
        ['JPY', '0.0066',  'Bank of Japan'],
        ['USD', '1.00',    'Base']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT currencyId INTO v_curr_id 
        FROM Currencies 
        WHERE currencyCode = v_datos[i][1] AND isDeleted = FALSE;

        IF v_curr_id IS NOT NULL THEN
            CALL sp_upsert_exchange_rate(
                v_curr_id, 
                v_datos[i][2]::DECIMAL(18,6), 
                CURRENT_DATE, 
                v_datos[i][3], 
                v_rate_id
            );
            RAISE NOTICE 'Tasa procesada para %: % (ID: %)', v_datos[i][1], v_datos[i][2], v_rate_id;
        ELSE
            RAISE WARNING 'No se encontró la moneda % para insertar su tasa de cambio', v_datos[i][1];
        END IF;
    END LOOP;

    -- Registros pasados:

    -- ENERO 2026
    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'NIO' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.02770, '2026-01-01', 'BCN',         v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'USD' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-01-01', 'FED',         v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'CRC' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00198, '2026-01-01', 'BCCR',        v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'PAB' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-01-01', 'Banco Nac',   v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'COP' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00024, '2026-01-01', 'BanRep',      v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'MXN' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.05750, '2026-01-01', 'Banxico',     v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'BRL' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.19500, '2026-01-01', 'BCB',         v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'EUR' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.07800, '2026-01-01', 'BCE',         v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'JPY' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00660, '2026-01-01', 'BoJ',         v_rate_id);

    -- FEBRERO 2026
    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'NIO' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.02775, '2026-02-01', 'BCN', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'USD' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-02-01', 'FED', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'CRC' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00196, '2026-02-01', 'BCCR', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'PAB' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-02-01', 'Banco Nac', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'COP' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00025, '2026-02-01', 'BanRep', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'MXN' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.05800, '2026-02-01', 'Banxico', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'BRL' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.19800, '2026-02-01', 'BCB', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'EUR' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.08200, '2026-02-01', 'BCE', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'JPY' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00675, '2026-02-01', 'BoJ', v_rate_id);

    -- MARZO 2026
    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'NIO' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.02780, '2026-03-01', 'BCN', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'USD' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-03-01', 'FED', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'CRC' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00199, '2026-03-01', 'BCCR', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'PAB' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-03-01', 'Banco Nac', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'COP' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00025, '2026-03-01', 'BanRep', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'MXN' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.05820, '2026-03-01', 'Banxico', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'BRL' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.20100, '2026-03-01', 'BCB', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'EUR' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.08500, '2026-03-01', 'BCE', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'JPY' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00670, '2026-03-01', 'BoJ', v_rate_id);

    -- ABRIL 2026
    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'NIO' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.02782, '2026-04-01', 'BCN', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'USD' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-04-01', 'FED', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'CRC' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00200, '2026-04-01', 'BCCR', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'PAB' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.00000, '2026-04-01', 'Banco Nac', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'COP' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00025, '2026-04-01', 'BanRep', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'MXN' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.05880, '2026-04-01', 'Banxico', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'BRL' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.20000, '2026-04-01', 'BCB', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'EUR' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 1.08000, '2026-04-01', 'BCE', v_rate_id);

    SELECT currencyId INTO v_curr_id FROM Currencies WHERE currencyCode = 'JPY' AND isDeleted = FALSE;
    CALL sp_upsert_exchange_rate(v_curr_id, 0.00668, '2026-04-01', 'BoJ', v_rate_id);

END $$;

-- persons:
DO $$
DECLARE
    v_person_id INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['Carlos', 'Zeledón', 'c.zeledon@etheria.ni', '+505 8888-0001'],
        ['Xiomara', 'Blandón', 'x.blandon@etheria.ni', '+505 8888-0002'],
        
        ['Roberto', 'Sánchez', 'r.sanchez@fastdelivery.com', '+506 2222-3333'],
        ['Elena', 'White', 'e.white@globalshipping.us', '+1 305-555-0199'],
        ['Jean', 'Dupont', 'j.dupont@frenchfragrance.fr', '+33 1 42 66 10 00'],
        ['Hiroshi', 'Sato', 'sato@osaka-oils.jp', '+81 3-3475-1000'],
        
        ['Ricardo', 'Palacios', 'r.palacios@yahoo.mx', '+52 33 9988-7766'],
        ['Valentina', 'Restrepo', 'v.restrepo@outlook.co', '+57 311 555-4433'],
        ['Fernando', 'Silva', 'f.silva@uol.com.br', '+55 11 98765-4321'],
        ['Gabriela', 'Solano', 'g.solano@est.itcr.ac.cr', '+506 6050-4030'],
        ['Andrés', 'Castillo', 'a.castillo@info.pa', '+507 6611-2233'],
        ['Yuki', 'Tanaka', 'y.tanaka@tokyo-net.jp', '+81 90-1234-5678']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        CALL sp_upsert_person(
            v_datos[i][1], 
            v_datos[i][2], 
            v_datos[i][3], 
            v_datos[i][4], 
            v_person_id   
        );
        RAISE NOTICE 'Insertado: % % (ID: %)', v_datos[i][1], v_datos[i][2], v_person_id;
    END LOOP;
END $$;

-- suppliers
DO $$
DECLARE
    v_supplier_id INTEGER;
    v_country_id  INTEGER;
    v_address_id  INTEGER;
    v_contact_id  INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['French Fragrance Corp', 'FR', 'París', 'j.dupont@frenchfragrance.fr'],
        ['Osaka Essential Oils', 'JP', 'Shibuya', 'y.tanaka@tokyo-net.jp'],
        ['Bavarian Healing Herbs', 'DE', 'Múnich', 'sato@osaka-oils.jp'], 
        ['Madrid Dermatological Sourcing', 'ES', 'Madrid', 'e.white@globalshipping.us'],
        ['Miami Export Logistics', 'US', 'Miami', 'e.white@globalshipping.us']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT countryId INTO v_country_id FROM Countries 
        WHERE isoCode = v_datos[i][2] AND isDeleted = FALSE;

        SELECT personId INTO v_contact_id FROM Persons 
        WHERE email = v_datos[i][4] AND isDeleted = FALSE;

        SELECT a.addressId INTO v_address_id 
        FROM Addresses a
        JOIN Cities ct ON a.cityId = ct.cityId
        WHERE ct.cityName = v_datos[i][3] AND a.isDeleted = FALSE;

        IF v_country_id IS NOT NULL AND v_contact_id IS NOT NULL AND v_address_id IS NOT NULL THEN
            CALL sp_upsert_supplier(
                v_datos[i][1], 
                v_contact_id,  
                v_country_id,  
                v_address_id,  
                TRUE,          
                v_supplier_id  
            );
            RAISE NOTICE 'Proveedor creado: % (ID: %)', v_datos[i][1], v_supplier_id;
        ELSE
            RAISE WARNING 'Faltan datos para el proveedor % (País: %, Contacto: %, Direccion: %)', 
                v_datos[i][1], v_country_id, v_contact_id, v_address_id;
        END IF;
    END LOOP;
END $$;

-- measurement_unit
DO $$
DECLARE
    v_unit_id INTEGER;
    v_unidades TEXT[] := ARRAY[
        'Mililitros', 
        'Litros',      
        'Gramos',      
        'Kilogramos',  
        'Onzas',       
        'Unidades',    
        'Set'          
    ];
BEGIN
    FOR i IN 1..array_length(v_unidades, 1) LOOP
        CALL sp_upsert_measurement_unit(
            v_unidades[i], 
            v_unit_id
        );
        RAISE NOTICE 'Unidad procesada: % (ID: %)', v_unidades[i], v_unit_id;
    END LOOP;
END $$;

-- productscategories
DO $$
DECLARE
    v_cat_id INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['Aceites Esenciales', 'Extractos naturales puros para aromaterapia y bienestar.'],
        ['Cuidado Dermatológico', 'Productos cosméticos de alta gama con ingredientes exóticos.'],
        ['Aromaterapia', 'Velas, difusores y mezclas para la relajación y salud mental.'],
        ['Jabones Artesanales', 'Jabones orgánicos producidos con aceites de origen europeo y asiático.'],
        ['Suplementos Naturales', 'Polvos y cápsulas basados en herbolaria tradicional internacional.'],
        ['Fragancias Premium', 'Perfumes exclusivos desarrollados con marcas blancas de IA.'],
        ['Cuidado Capilar', 'Tratamientos intensivos con aceites naturales y vitaminas.'],
        ['Higiene de Lujo', 'Productos de aseo personal con estándares de calidad superiores.'],
        ['Kits de Regalo', 'Conjuntos seleccionados de productos premium para ocasiones especiales.'],
        ['Bebidas Saludables', 'Infusiones y elixires elaborados con insumos exóticos importados.']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        CALL sp_upsert_product_category(
            v_datos[i][1], 
            v_datos[i][2], 
            v_cat_id     
        );
        RAISE NOTICE 'Categoría procesada: % (ID: %)', v_datos[i][1], v_cat_id;
    END LOOP;
END $$;

-- product
DO $$
DECLARE
    v_prod_id  INTEGER;
    v_cat_id   INTEGER;
    v_unit_id  INTEGER;
    v_datos TEXT[][] := ARRAY[
        -- Aceites Esenciales
        ['Aceite de Lavanda de Provenza', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.05'],
        ['Esencia de Sándalo de Japón', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.05'],
        ['Extracto de Eucalipto Australiano', 'Aceites Esenciales', 'Litros', '0.001', '0.92'],
        
        -- Cuidado Dermatológico
        ['Serum Facial de Algas Rojas', 'Cuidado Dermatológico', 'Mililitros', '0.0002', '0.12'],
        ['Crema Hidratante de Karité Dorado', 'Cuidado Dermatológico', 'Gramos', '0.0003', '0.25'],
        
        -- Aromaterapia
        ['Vela Artesanal de Vainilla y Mirra', 'Aromaterapia', 'Unidades', '0.0005', '0.40'],
        ['Difusor Ultrasónico Premium', 'Aromaterapia', 'Unidades', '0.002', '0.80'],
        
        -- Jabones Artesanales
        ['Jabón de Carbón Activado y Menta', 'Jabones Artesanales', 'Gramos', '0.0002', '0.15'],
        ['Barra de Limpieza de Leche de Burra', 'Jabones Artesanales', 'Gramos', '0.0002', '0.15'],
        
        -- Suplementos Naturales
        ['Cápsulas de Cúrcuma Longa', 'Suplementos Naturales', 'Unidades', '0.0001', '0.10'],
        ['Polvo de Maca Andina Orgánica', 'Suplementos Naturales', 'Gramos', '0.0005', '0.50'],
        
        -- Fragancias Premium
        ['Perfume "Bruma del Desierto" (Eau de Parfum)', 'Fragancias Premium', 'Mililitros', '0.0004', '0.35'],
        ['Agua de Colonia "Jardín Japonés"', 'Fragancias Premium', 'Mililitros', '0.0005', '0.45'],
        
        -- Cuidado Capilar
        ['Máscara Capilar de Aceite de Argán', 'Cuidado Capilar', 'Mililitros', '0.0006', '0.55'],
        ['Shampoo Sólido de Romero y Quina', 'Cuidado Capilar', 'Gramos', '0.0001', '0.10'],
        
        -- Higiene de Lujo
        ['Sales de Baño del Mar Muerto', 'Higiene de Lujo', 'Kilogramos', '0.001', '1.05'],
        ['Loción Corporal de Orquídeas Blancas', 'Higiene de Lujo', 'Mililitros', '0.0005', '0.50'],
        
        -- Kits de Regalo
        ['Set de Bienestar "Zen Spirit"', 'Kits de Regalo', 'Set', '0.005', '2.50'],
        ['Caja de Regalo "Ritual de Sueño"', 'Kits de Regalo', 'Set', '0.004', '1.80'],
        
        -- Bebidas Saludables
        ['Elixir de Té Blanco y Jengibre', 'Bebidas Saludables', 'Mililitros', '0.0006', '0.60'],
        ['Aceite de Bergamota de Calabria', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.06'],
        ['Esencia de Lemongrass de Tailandia', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.04'],
        ['Aceite de Rosa Mosqueta de Chile', 'Aceites Esenciales', 'Mililitros', '0.0002', '0.15'],
        ['Extracto de Incienso de Omán', 'Aceites Esenciales', 'Mililitros', '0.0003', '0.25'],
        ['Esencia de Menta Piperita Americana', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.05'],
        ['Aceite de Árbol de Té de Australia', 'Aceites Esenciales', 'Mililitros', '0.0001', '0.07'],
        ['Extracto de Pachulí de Indonesia', 'Aceites Esenciales', 'Mililitros', '0.0002', '0.10'],
        ['Esencia de Jazmín de Egipto', 'Aceites Esenciales', 'Mililitros', '0.0005', '0.45'],

        -- Cuidado Dermatológico (Continuación)
        ['Gel de Limpieza de Aloe Vera Real', 'Cuidado Dermatológico', 'Mililitros', '0.0001', '0.08'],
        ['Tónico Facial de Agua de Rosas Búlgara', 'Cuidado Dermatológico', 'Mililitros', '0.0001', '0.10'],
        ['Exfoliante de Café y Canela', 'Cuidado Dermatológico', 'Gramos', '0.0002', '0.12'],
        ['Mascarilla de Arcilla Blanca del Amazonas', 'Cuidado Dermatológico', 'Gramos', '0.0002', '0.18'],
        ['Crema de Contorno de Ojos con Ácido Hialurónico', 'Cuidado Dermatológico', 'Mililitros', '0.0005', '0.40'],
        ['Bálsamo Labial de Cera de Abeja y Miel', 'Cuidado Dermatológico', 'Gramos', '0.0001', '0.05'],
        ['Aceite Corporal de Almendras Dulces', 'Cuidado Dermatológico', 'Mililitros', '0.0002', '0.15'],
        ['Protector Solar Mineral de Zinc', 'Cuidado Dermatológico', 'Mililitros', '0.0003', '0.20'],

        -- Aromaterapia (Continuación)
        ['Vela de Soya con Lavanda y Manzanilla', 'Aromaterapia', 'Unidades', '0.0004', '0.35'],
        ['Mezcla de Aceites "Sueño Profundo"', 'Aromaterapia', 'Mililitros', '0.0002', '0.15'],
        ['Incienso Natural de Palo Santo', 'Aromaterapia', 'Unidades', '0.0001', '0.08'],
        ['Spray Ambiental de Cítricos Energizantes', 'Aromaterapia', 'Mililitros', '0.0001', '0.12'],
        ['Difusor de Cañas de Canela y Naranja', 'Aromaterapia', 'Unidades', '0.0003', '0.30'],
        ['Roll-on Anti-Estrés con Vetiver', 'Aromaterapia', 'Mililitros', '0.0002', '0.18'],
        ['Salvia Blanca para Sahumado', 'Aromaterapia', 'Unidades', '0.0001', '0.10'],
        ['Aceite de Masaje Relajante de Árnica', 'Aromaterapia', 'Mililitros', '0.0003', '0.22'],

        -- Jabones Artesanales (Continuación)
        ['Jabón de Avena y Miel Silvestre', 'Jabones Artesanales', 'Gramos', '0.0001', '0.10'],
        ['Barra de Jabón de Arcilla Roja', 'Jabones Artesanales', 'Gramos', '0.0001', '0.12'],
        ['Jabón Exfoliante de Semillas de Amapola', 'Jabones Artesanales', 'Gramos', '0.0001', '0.11'],
        ['Jabón Líquido de Caléndula Orgánica', 'Jabones Artesanales', 'Mililitros', '0.0002', '0.14'],
        ['Barra de Jabón de Coco y Lima', 'Jabones Artesanales', 'Gramos', '0.0001', '0.09'],
        ['Jabón de Manteca de Cacao y Vainilla', 'Jabones Artesanales', 'Gramos', '0.0001', '0.13'],
        ['Jabón de Romero y Limón', 'Jabones Artesanales', 'Gramos', '0.0001', '0.10'],
        ['Jabón Cremoso de Leche de Cabra', 'Jabones Artesanales', 'Gramos', '0.0001', '0.12'],

        -- Suplementos Naturales (Continuación)
        ['Cápsulas de Espirulina Azul', 'Suplementos Naturales', 'Unidades', '0.0002', '0.15'],
        ['Extracto de Hongo Reishi en Polvo', 'Suplementos Naturales', 'Gramos', '0.0006', '0.65'],
        ['Colágeno Hidrolizado Marino', 'Suplementos Naturales', 'Gramos', '0.0004', '0.40'],
        ['Cápsulas de Aceite de Krill', 'Suplementos Naturales', 'Unidades', '0.0003', '0.35'],
        ['Polvo de Ashwagandha de la India', 'Suplementos Naturales', 'Gramos', '0.0005', '0.55'],
        ['Magnesio Quelado de Alta Absorción', 'Suplementos Naturales', 'Unidades', '0.0002', '0.20'],
        ['Probióticos Multicepa 50 Billones', 'Suplementos Naturales', 'Unidades', '0.0004', '0.50'],
        ['Gotas de Clorofila Líquida Concentrada', 'Suplementos Naturales', 'Mililitros', '0.0003', '0.30'],

        -- Fragancias Premium (Continuación)
        ['Perfume "Noche en Marrakech"', 'Fragancias Premium', 'Mililitros', '0.0006', '0.65'],
        ['Eau de Toilette "Brisas del Mediterráneo"', 'Fragancias Premium', 'Mililitros', '0.0004', '0.40'],
        ['Aceite Perfumado "Ámbar Sagrado"', 'Fragancias Premium', 'Mililitros', '0.0008', '0.85'],
        ['Perfume Sólido de Sándalo y Oud', 'Fragancias Premium', 'Gramos', '0.0005', '0.50'],
        ['Fragancia "Bosque de Niebla"', 'Fragancias Premium', 'Mililitros', '0.0005', '0.45'],
        ['Colonia de Té Verde y Jengibre', 'Fragancias Premium', 'Mililitros', '0.0003', '0.25'],
        ['Perfume Unisex "Metal y Seda"', 'Fragancias Premium', 'Mililitros', '0.0007', '0.70'],
        ['Extracto de Perfume "Luna de Invierno"', 'Fragancias Premium', 'Mililitros', '0.0009', '0.95'],

        -- Cuidado Capilar (Continuación)
        ['Acondicionador de Coco y Biotina', 'Cuidado Capilar', 'Mililitros', '0.0002', '0.18'],
        ['Serum Anti-Frizz de Keratina Vegetal', 'Cuidado Capilar', 'Mililitros', '0.0004', '0.35'],
        ['Tónico Capilar de Ortiga y Ginseng', 'Cuidado Capilar', 'Mililitros', '0.0003', '0.25'],
        ['Mascarilla Nutritiva de Palta y Karité', 'Cuidado Capilar', 'Mililitros', '0.0005', '0.45'],
        ['Shampoo Desintoxicante de Menta y Carbón', 'Cuidado Capilar', 'Mililitros', '0.0002', '0.20'],
        ['Aceite Pre-Lavado de Neem', 'Cuidado Capilar', 'Mililitros', '0.0003', '0.28'],
        ['Spray Protector de Calor de Bambú', 'Cuidado Capilar', 'Mililitros', '0.0003', '0.32'],
        ['Ampollas de Rescate Capilar (Pack 4)', 'Cuidado Capilar', 'Set', '0.001', '1.10'],

        -- Higiene de Lujo (Continuación)
        ['Gel de Ducha de Orquídea y Vainilla', 'Higiene de Lujo', 'Mililitros', '0.0002', '0.15'],
        ['Espuma de Afeitar de Eucalipto y Sándalo', 'Higiene de Lujo', 'Mililitros', '0.0003', '0.25'],
        ['Crema de Manos de Seda y Lavanda', 'Higiene de Lujo', 'Mililitros', '0.0002', '0.20'],
        ['Enjuague Bucal Natural de Hierbabuena', 'Higiene de Lujo', 'Mililitros', '0.0001', '0.12'],
        ['Desodorante de Cristal de Alumbre', 'Higiene de Lujo', 'Gramos', '0.0002', '0.18'],
        ['Talco Corporal de Rosas y Caolín', 'Higiene de Lujo', 'Gramos', '0.0002', '0.15'],
        ['Aceite de Baño Espumoso de Ylang-Ylang', 'Higiene de Lujo', 'Mililitros', '0.0004', '0.35'],
        ['Bomba de Baño Efervescente Gold', 'Higiene de Lujo', 'Unidades', '0.0003', '0.22'],

        -- Kits de Regalo (Continuación)
        ['Cofre "Secretos del Amazonas"', 'Kits de Regalo', 'Set', '0.008', '4.50'],
        ['Set de Viaje "Explorador Natural"', 'Kits de Regalo', 'Set', '0.004', '2.20'],
        ['Canasta "Día de Spa en Casa"', 'Kits de Regalo', 'Set', '0.010', '6.00'],
        ['Dúo de Perfumes "Almas Gemelas"', 'Kits de Regalo', 'Set', '0.005', '3.80'],
        ['Kit "Primeros Pasos en Aromaterapia"', 'Kits de Regalo', 'Set', '0.006', '3.50'],
        ['Caja de Lujo "Herencia Ancestral"', 'Kits de Regalo', 'Set', '0.012', '8.00'],
        ['Set de Jabones del Mundo (X6)', 'Kits de Regalo', 'Set', '0.007', '4.20'],
        ['Kit "Energía y Vitalidad"', 'Kits de Regalo', 'Set', '0.005', '3.10'],

        -- Bebidas Saludables (Continuación)
        ['Té Matcha Ceremonial de Grado A', 'Bebidas Saludables', 'Gramos', '0.001', '1.20'],
        ['Infusión de Frutos del Bosque y Hibisco', 'Bebidas Saludables', 'Gramos', '0.0002', '0.15'],
        ['Kombucha de Jengibre y Limón (Pack 4)', 'Bebidas Saludables', 'Set', '0.002', '1.50'],
        ['Polvo para Golden Milk (Cúrcuma Mix)', 'Bebidas Saludables', 'Gramos', '0.0004', '0.35'],
        ['Agua de Coco Orgánica Liofilizada', 'Bebidas Saludables', 'Gramos', '0.0003', '0.25'],
        ['Jarabe de Saúco para Defensas', 'Bebidas Saludables', 'Mililitros', '0.0005', '0.45'],
        ['Concentrado de Aloe y Goji', 'Bebidas Saludables', 'Mililitros', '0.0006', '0.55'],
        ['Té Chai Especiado Artesanal', 'Bebidas Saludables', 'Gramos', '0.0003', '0.28']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT categoryId INTO v_cat_id FROM ProductCategories 
        WHERE categoryName = v_datos[i][2] AND isDeleted = FALSE;
        
        SELECT unitId INTO v_unit_id FROM MeasurementUnits 
        WHERE unitName = v_datos[i][3] AND isDeleted = FALSE;

        IF v_cat_id IS NOT NULL AND v_unit_id IS NOT NULL THEN
            CALL sp_upsert_product(
                v_datos[i][1],          
                v_cat_id,                
                v_unit_id,               
                v_datos[i][4]::DECIMAL,  
                v_datos[i][5]::DECIMAL,  
                v_prod_id                
            );
            RAISE NOTICE 'Producto procesado: % (ID: %)', v_datos[i][1], v_prod_id;
        ELSE
            RAISE WARNING 'No se pudo insertar % por falta de categoría o unidad.', v_datos[i][1];
        END IF;
    END LOOP;
END $$;

-- product_price
DO $$
DECLARE
    v_prod_id     INTEGER;
    v_price_id    INTEGER;
    v_fecha_inicio DATE := '2026-01-01';
    v_datos TEXT[][] := ARRAY[
        ['Aceite de Lavanda de Provenza', '35.50'],
        ['Esencia de Sándalo de Japón', '45.00'],
        ['Extracto de Eucalipto Australiano', '45.75'],
        ['Serum Facial de Algas Rojas', '85.00'],
        ['Crema Hidratante de Karité Dorado', '62.30'],
        ['Vela Artesanal de Vainilla y Mirra', '22.00'],
        ['Difusor Ultrasónico Premium', '110.00'],
        ['Jabón de Carbón Activado y Menta', '12.50'],
        ['Barra de Limpieza de Leche de Burra', '18.00'],
        ['Cápsulas de Cúrcuma Longa', '35.00'],
        ['Polvo de Maca Andina Orgánica', '28.50'],
        ['Perfume "Bruma del Desierto" (Eau de Parfum)', '145.00'],
        ['Agua de Colonia "Jardín Japonés"', '95.00'],
        ['Máscara Capilar de Aceite de Argán', '42.00'],
        ['Shampoo Sólido de Romero y Quina', '15.00'],
        ['Sales de Baño del Mar Muerto', '38.00'],
        ['Loción Corporal de Orquídeas Blancas', '55.00'],
        ['Set de Bienestar "Zen Spirit"', '180.00'],
        ['Caja de Regalo "Ritual de Sueño"', '125.00'],
        ['Elixir de Té Blanco y Jengibre', '20.00'],
        
        ['Aceite de Bergamota de Calabria', '28.00'],
        ['Esencia de Lemongrass de Tailandia', '19.50'],
        ['Aceite de Rosa Mosqueta de Chile', '34.00'],
        ['Extracto de Incienso de Omán', '55.00'],
        ['Esencia de Menta Piperita Americana', '22.00'],
        ['Aceite de Árbol de Té de Australia', '26.00'],
        ['Extracto de Pachulí de Indonesia', '31.50'],
        ['Esencia de Jazmín de Egipto', '68.00'],
        ['Gel de Limpieza de Aloe Vera Real', '18.50'],
        ['Tónico Facial de Agua de Rosas Búlgara', '24.00'],
        ['Exfoliante de Café y Canela', '16.50'],
        ['Mascarilla de Arcilla Blanca del Amazonas', '29.00'],
        ['Crema de Contorno de Ojos con Ácido Hialurónico', '48.00'],
        ['Bálsamo Labial de Cera de Abeja y Miel', '8.50'],
        ['Aceite Corporal de Almendras Dulces', '21.00'],
        ['Protector Solar Mineral de Zinc', '35.00'],
        ['Vela de Soya con Lavanda y Manzanilla', '26.00'],
        ['Mezcla de Aceites "Sueño Profundo"', '32.00'],
        ['Incienso Natural de Palo Santo', '14.00'],
        ['Spray Ambiental de Cítricos Energizantes', '18.00'],
        ['Difusor de Cañas de Canela y Naranja', '38.00'],
        ['Roll-on Anti-Estrés con Vetiver', '24.50'],
        ['Salvia Blanca para Sahumado', '12.00'],
        ['Aceite de Masaje Relajante de Árnica', '28.00'],
        ['Jabón de Avena y Miel Silvestre', '11.50'],
        ['Barra de Jabón de Arcilla Roja', '13.00'],
        ['Jabón Exfoliante de Semillas de Amapola', '12.50'],
        ['Jabón Líquido de Caléndula Orgánica', '15.00'],
        ['Barra de Jabón de Coco y Lima', '10.50'],
        ['Jabón de Manteca de Cacao y Vainilla', '14.00'],
        ['Jabón de Romero y Limón', '11.00'],
        ['Jabón Cremoso de Leche de Cabra', '13.50'],
        ['Cápsulas de Espirulina Azul', '42.00'],
        ['Extracto de Hongo Reishi en Polvo', '58.00'],
        ['Colágeno Hidrolizado Marino', '45.00'],
        ['Cápsulas de Aceite de Krill', '39.00'],
        ['Polvo de Ashwagandha de la India', '32.50'],
        ['Magnesio Quelado de Alta Absorción', '25.00'],
        ['Probióticos Multicepa 50 Billones', '49.00'],
        ['Gotas de Clorofila Líquida Concentrada', '28.00'],
        ['Perfume "Noche en Marrakech"', '165.00'],
        ['Eau de Toilette "Brisas del Mediterráneo"', '85.00'],
        ['Aceite Perfumado "Ámbar Sagrado"', '75.00'],
        ['Perfume Sólido de Sándalo y Oud', '45.00'],
        ['Fragancia "Bosque de Niebla"', '110.00'],
        ['Colonia de Té Verde y Jengibre', '55.00'],
        ['Perfume Unisex "Metal y Seda"', '140.00'],
        ['Extracto de Perfume "Luna de Invierno"', '190.00'],
        ['Acondicionador de Coco y Biotina', '22.00'],
        ['Serum Anti-Frizz de Keratina Vegetal', '38.00'],
        ['Tónico Capilar de Ortiga y Ginseng', '26.00'],
        ['Mascarilla Nutritiva de Palta y Karité', '32.00'],
        ['Shampoo Desintoxicante de Menta y Carbón', '24.00'],
        ['Aceite Pre-Lavado de Neem', '29.50'],
        ['Spray Protector de Calor de Bambú', '21.00'],
        ['Ampollas de Rescate Capilar (Pack 4)', '45.00'],
        ['Gel de Ducha de Orquídea y Vainilla', '19.50'],
        ['Espuma de Afeitar de Eucalipto y Sándalo', '22.00'],
        ['Crema de Manos de Seda y Lavanda', '16.00'],
        ['Enjuague Bucal Natural de Hierbabuena', '14.00'],
        ['Desodorante de Cristal de Alumbre', '12.50'],
        ['Talco Corporal de Rosas y Caolín', '15.00'],
        ['Aceite de Baño Espumoso de Ylang-Ylang', '34.00'],
        ['Bomba de Baño Efervescente Gold', '9.00'],
        ['Cofre "Secretos del Amazonas"', '210.00'],
        ['Set de Viaje "Explorador Natural"', '65.00'],
        ['Canasta "Día de Spa en Casa"', '145.00'],
        ['Dúo de Perfumes "Almas Gemelas"', '120.00'],
        ['Kit "Primeros Pasos en Aromaterapia"', '85.00'],
        ['Caja de Lujo "Herencia Ancestral"', '350.00'],
        ['Set de Jabones del Mundo (X6)', '55.00'],
        ['Kit "Energía y Vitalidad"', '75.00'],
        ['Té Matcha Ceremonial de Grado A', '42.00'],
        ['Infusión de Frutos del Bosque y Hibisco', '18.00'],
        ['Kombucha de Jengibre y Limón (Pack 4)', '24.00'],
        ['Polvo para Golden Milk (Cúrcuma Mix)', '26.50'],
        ['Agua de Coco Orgánica Liofilizada', '19.00'],
        ['Jarabe de Saúco para Defensas', '32.00'],
        ['Concentrado de Aloe y Goji', '38.00'],
        ['Té Chai Especiado Artesanal', '22.50']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT productId INTO v_prod_id 
        FROM Products 
        WHERE productName = v_datos[i][1] AND isDeleted = FALSE;

        IF v_prod_id IS NOT NULL THEN
            CALL sp_set_product_price(
                v_prod_id, 
                v_datos[i][2]::DECIMAL(12,4), 
                v_fecha_inicio, 
                NULL, 
                v_price_id
            );
            RAISE NOTICE 'Precio USD % asignado a % (ID: %)', v_datos[i][2], v_datos[i][1], v_price_id;
        ELSE
            RAISE WARNING 'No se encontró el producto % para asignar precio.', v_datos[i][1];
        END IF;
    END LOOP;
END $$;

-- product_characteristic
DO $$
DECLARE
    v_prod_id  INTEGER;
    v_char_id  INTEGER;
    v_datos TEXT[][] := ARRAY[
        -- Origenes de insumos
        ['Aceite de Lavanda de Provenza', 'Origen', 'Francia'],
        ['Esencia de Sándalo de Japón', 'Origen', 'Kioto, Japón'],
        ['Extracto de Eucalipto Australiano', 'Origen', 'Nueva Gales del Sur'],
        ['Crema Hidratante de Karité Dorado', 'Origen', 'Ghana'],
        ['Sales de Baño del Mar Muerto', 'Origen', 'Jordania'],
        
        -- Beneficios y notas
        ['Serum Facial de Algas Rojas', 'Beneficio', 'Antienvejecimiento'],
        ['Vela Artesanal de Vainilla y Mirra', 'Nota Olfativa', 'Dulce y Amaderado'],
        ['Cápsulas de Cúrcuma Longa', 'Uso', 'Antiinflamatorio Natural'],
        ['Perfume "Bruma del Desierto" (Eau de Parfum)', 'Concentración', '20% Esencia'],
        ['Shampoo Sólido de Romero y Quina', 'Tipo de Cabello', 'Graso / Mixto'],
        
        -- Certificaciones
        ['Polvo de Maca Andina Orgánica', 'Certificación', 'USDA Organic'],
        ['Jabón de Carbón Activado y Menta', 'Certificación', 'Cruelty Free'],
        ['Set de Bienestar "Zen Spirit"', 'Incluye', 'Difusor + 3 Aceites'],
        ['Elixir de Té Blanco y Jengibre', 'Atributo', 'Sin Azúcar Añadida'],

        -- Aceites Esenciales
        ['Aceite de Bergamota de Calabria', 'Origen', 'Italia'],
        ['Esencia de Lemongrass de Tailandia', 'Beneficio', 'Repelente Natural'],
        ['Aceite de Rosa Mosqueta de Chile', 'Certificación', 'Orgánico'],
        ['Extracto de Incienso de Omán', 'Grado', 'Terapéutico'],
        ['Esencia de Menta Piperita Americana', 'Nota', 'Refrescante'],
        ['Aceite de Árbol de Té de Australia', 'Uso', 'Antiséptico'],
        ['Extracto de Pachulí de Indonesia', 'Origen', 'Java'],
        ['Esencia de Jazmín de Egipto', 'Método', 'Extracción por Solvente'],

        -- Cuidado Dermatológico
        ['Gel de Limpieza de Aloe Vera Real', 'Ingrediente', '99% Aloe'],
        ['Tónico Facial de Agua de Rosas Búlgara', 'Origen', 'Valle de las Rosas'],
        ['Exfoliante de Café y Canela', 'Tipo', 'Exfoliante Mecánico'],
        ['Mascarilla de Arcilla Blanca del Amazonas', 'Beneficio', 'Desintoxicante'],
        ['Crema de Contorno de Ojos con Ácido Hialurónico', 'Atributo', 'Vegano'],
        ['Bálsamo Labial de Cera de Abeja y Miel', 'Certificación', 'Cruelty Free'],
        ['Aceite Corporal de Almendras Dulces', 'Prensado', 'En Frío'],
        ['Protector Solar Mineral de Zinc', 'SPF', '50+'],

        -- Aromaterapia
        ['Vela de Soya con Lavanda y Manzanilla', 'Duración', '40 Horas'],
        ['Mezcla de Aceites "Sueño Profundo"', 'Incluye', 'Valeriana y Lavanda'],
        ['Incienso Natural de Palo Santo', 'Cosecha', 'Sustentable'],
        ['Spray Ambiental de Cítricos Energizantes', 'Nota', 'Naranja y Limón'],
        ['Difusor de Cañas de Canela y Naranja', 'Material', 'Vidrio Reciclado'],
        ['Roll-on Anti-Estrés con Vetiver', 'Aplicación', 'Puntos de Pulso'],
        ['Salvia Blanca para Sahumado', 'Origen', 'California'],
        ['Aceite de Masaje Relajante de Árnica', 'Uso', 'Alivio Muscular'],

        -- Jabones Artesanales
        ['Jabón de Avena y Miel Silvestre', 'Piel', 'Sensible'],
        ['Barra de Jabón de Arcilla Roja', 'Mineral', 'Rico en Hierro'],
        ['Jabón Exfoliante de Semillas de Amapola', 'Textura', 'Rugosa'],
        ['Jabón Líquido de Caléndula Orgánica', 'pH', 'Neutro'],
        ['Barra de Jabón de Coco y Lima', 'Aroma', 'Tropical'],
        ['Jabón de Manteca de Cacao y Vainilla', 'Beneficio', 'Ultra-Hidratante'],
        ['Jabón de Romero y Limón', 'Atributo', 'Biodegradable'],
        ['Jabón Cremoso de Leche de Cabra', 'Vitamina', 'Rico en Vitamina A'],

        -- Suplementos Naturales
        ['Cápsulas de Espirulina Azul', 'Contenido', '60 Cápsulas'],
        ['Extracto de Hongo Reishi en Polvo', 'Beneficio', 'Inmunomodulador'],
        ['Colágeno Hidrolizado Marino', 'Origen', 'Pescado Silvestre'],
        ['Cápsulas de Aceite de Krill', 'Nutriente', 'Omega-3'],
        ['Polvo de Ashwagandha de la India', 'Tipo', 'Adaptógeno'],
        ['Magnesio Quelado de Alta Absorción', 'Forma', 'Bisglicinato'],
        ['Probióticos Multicepa 50 Billones', 'Cepas', '15 Variedades'],
        ['Gotas de Clorofila Líquida Concentrada', 'Beneficio', 'Oxigenante'],

        -- Fragancias Premium
        ['Perfume "Noche en Marrakech"', 'Familia', 'Oriental Especiada'],
        ['Eau de Toilette "Brisas del Mediterráneo"', 'Nota Salida', 'Bergamota'],
        ['Aceite Perfumado "Ámbar Sagrado"', 'Base', 'Aceite de Jojoba'],
        ['Perfume Sólido de Sándalo y Oud', 'Presentación', 'Lata de Viaje'],
        ['Fragancia "Bosque de Niebla"', 'Género', 'Unisex'],
        ['Colonia de Té Verde y Jengibre', 'Estilo', 'Casual'],
        ['Perfume Unisex "Metal y Seda"', 'Concepto', 'Contraste Moderno'],
        ['Extracto de Perfume "Luna de Invierno"', 'Concentración', '30%'],

        -- Cuidado Capilar
        ['Acondicionador de Coco y Biotina', 'Beneficio', 'Fortalecedor'],
        ['Serum Anti-Frizz de Keratina Vegetal', 'Protección', 'Humedad'],
        ['Tónico Capilar de Ortiga y Ginseng', 'Uso', 'Anticaída'],
        ['Mascarilla Nutritiva de Palta y Karité', 'Tiempo Uso', '15 Minutos'],
        ['Shampoo Desintoxicante de Menta y Carbón', 'Limpieza', 'Profunda'],
        ['Aceite Pre-Lavado de Neem', 'Tratamiento', 'Cuero Cabelludo'],
        ['Spray Protector de Calor de Bambú', 'Resistencia', 'Hasta 230°C'],
        ['Ampollas de Rescate Capilar (Pack 4)', 'Frecuencia', 'Semanal'],

        -- Higiene de Lujo
        ['Gel de Ducha de Orquídea y Vainilla', 'Textura', 'Satinada'],
        ['Espuma de Afeitar de Eucalipto y Sándalo', 'Efecto', 'Calmante'],
        ['Crema de Manos de Seda y Lavanda', 'Absorción', 'Rápida'],
        ['Enjuague Bucal Natural de Hierbabuena', 'Sin', 'Alcohol'],
        ['Desodorante de Cristal de Alumbre', 'Duración', '24 Horas'],
        ['Talco Corporal de Rosas y Caolín', 'Función', 'Absorbente'],
        ['Aceite de Baño Espumoso de Ylang-Ylang', 'Aroma', 'Sensual'],
        ['Bomba de Baño Efervescente Gold', 'Efecto', 'Brillo Dorado'],

        -- Kits de Regalo
        ['Cofre "Secretos del Amazonas"', 'Origen Insumos', 'Brasil/Perú'],
        ['Set de Viaje "Explorador Natural"', 'Tamaño', 'Travel Size'],
        ['Canasta "Día de Spa en Casa"', 'Piezas', '8 Elementos'],
        ['Dúo de Perfumes "Almas Gemelas"', 'Contenido', '2 x 50ml'],
        ['Kit "Primeros Pasos en Aromaterapia"', 'Incluye', 'Guía de Uso'],
        ['Caja de Lujo "Herencia Ancestral"', 'Edición', 'Limitada'],
        ['Set de Jabones del Mundo (X6)', 'Variedad', 'Multicontinental'],
        ['Kit "Energía y Vitalidad"', 'Objetivo', 'Revitalizante'],

        -- Bebidas Saludables
        ['Té Matcha Ceremonial de Grado A', 'Origen', 'Uji, Japón'],
        ['Infusión de Frutos del Bosque y Hibisco', 'Teína', 'Libre de Teína'],
        ['Kombucha de Jengibre y Limón (Pack 4)', 'Proceso', 'Fermentación Natural'],
        ['Polvo para Golden Milk (Cúrcuma Mix)', 'Preparación', 'Leche Caliente'],
        ['Agua de Coco Orgánica Liofilizada', 'Estado', 'Polvo'],
        ['Jarabe de Saúco para Defensas', 'Vitamina', 'Rico en Vitamina C'],
        ['Concentrado de Aloe y Goji', 'Sabor', 'Frutal'],
        ['Té Chai Especiado Artesanal', 'Especias', 'Cardamomo y Clavo']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        SELECT productId INTO v_prod_id 
          FROM Products 
         WHERE productName = v_datos[i][1] AND isDeleted = FALSE;

        IF v_prod_id IS NOT NULL THEN
            CALL sp_add_product_characteristic(
                v_prod_id, 
                v_datos[i][2], 
                v_datos[i][3], 
                v_char_id
            );
            RAISE NOTICE 'Característica [%: %] añadida a %', v_datos[i][2], v_datos[i][3], v_datos[i][1];
        ELSE
            RAISE WARNING 'Producto % no encontrado para añadir característica.', v_datos[i][1];
        END IF;
    END LOOP;
END $$;

-- permittypes
DO $$
DECLARE
    v_permit_id INTEGER;
    v_datos TEXT[][] := ARRAY[
        ['Registro Sanitario de Salud', 'Permiso obligatorio para productos de cuidado personal y cosméticos (Jabones, Cremas, Perfumes).'],
        ['Permiso de Importación Fitozoosanitario', 'Requerido para el ingreso de materias primas naturales como aceites esenciales y hierbas.'],
        ['Certificación de Libre Venta (CLV)', 'Documento que acredita que el producto se vende libremente en el país de origen.'],
        ['Registro de Suplementos Alimenticios', 'Normativa específica para la comercialización de cápsulas y polvos nutricionales.'],
        ['Certificado de Análisis (COA)', 'Documento técnico que garantiza la composición química y pureza del lote importado.'],
        ['Licencia de Funcionamiento de Bodega', 'Permiso legal para el almacenamiento de sustancias químicas o inflamables (Perfumes).']
    ];
BEGIN
    FOR i IN 1..array_length(v_datos, 1) LOOP
        CALL sp_upsert_permit_type(
            v_datos[i][1], 
            v_datos[i][2], 
            v_permit_id    
        );
        RAISE NOTICE 'Tipo de permiso procesado: % (ID: %)', v_datos[i][1], v_permit_id;
    END LOOP;
END $$;

-- bulkpurchases
DO $$
DECLARE
    v_bulk_id      INTEGER;
    v_prod_id      INTEGER;
    v_supp_id      INTEGER;
    v_unit_id      INTEGER;
    v_country_id   INTEGER;
    v_hub_id       INTEGER;
    v_permit_id    INTEGER;
    v_disp_id      INTEGER;
    v_order_num    VARCHAR(60);
    v_final_stock DECIMAL(12,3);
BEGIN
    -- 1. Compra: Aceite de Lavanda (Francia)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Aceite de Lavanda de Provenza';
    SELECT supplierId INTO v_supp_id FROM Suppliers WHERE supplierName = 'French Fragrance Corp';
    SELECT unitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = 'Litros';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'FR';

    CALL sp_register_bulk_purchase(
        v_prod_id, v_supp_id, 50.000, v_unit_id, 1200.00, v_country_id, 
        46.000, 0.0500, null, 150.00, 200.00, v_bulk_id
    );

    -- 2. Compra: Esencia de Sándalo (Japón)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Esencia de Sándalo de Japón';
    SELECT supplierId INTO v_supp_id FROM Suppliers WHERE supplierName = 'Osaka Essential Oils';
    SELECT unitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = 'Litros';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'JP';

    CALL sp_register_bulk_purchase(
        v_prod_id, v_supp_id, 20.000, v_unit_id, 3500.00, v_country_id, 
        18.500, 0.0250, null , 450.00, 300.00, v_bulk_id
    );

    -- 3. Compra: Serum Facial (España)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Serum Facial de Algas Rojas';
    SELECT supplierId INTO v_supp_id FROM Suppliers WHERE supplierName = 'Madrid Dermatological Sourcing';
    SELECT unitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = 'Unidades';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'ES';

    CALL sp_register_bulk_purchase(
        v_prod_id, v_supp_id, 500.000, v_unit_id, 8500.00, v_country_id, 
        60.000, 0.1500, null, 800.00, 450.00, v_bulk_id
    );

    -- 4. Compra: Cápsulas de Cúrcuma (Alemania)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Cápsulas de Cúrcuma Longa';
    SELECT supplierId INTO v_supp_id FROM Suppliers WHERE supplierName = 'Bavarian Healing Herbs';
    SELECT unitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = 'Unidades';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'DE';

    CALL sp_register_bulk_purchase(
        v_prod_id, v_supp_id, 1000.000, v_unit_id, 4000.00, v_country_id, 
        100.000, 0.2000, null, 200.00, 350.00, v_bulk_id
    );

    -- 5. Compra: Set de Bienestar (USA)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Set de Bienestar "Zen Spirit"';
    SELECT supplierId INTO v_supp_id FROM Suppliers WHERE supplierName = 'Miami Export Logistics';
    SELECT unitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = 'Set';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'US';

    CALL sp_register_bulk_purchase(
        v_prod_id, v_supp_id, 100.000, v_unit_id, 5500.00, v_country_id, 
        250.000, 1.5000, null, 550.00, 600.00, v_bulk_id
    );

    -- Paquetes ya en bodega:
    
    -- Enero 2026
    CALL sp_register_bulk_purchase(
        1, 3, 600.000, 1, 3600.00, 7, 
        300.0, 0.6000, '2026-01-10 08:00:00', 360.00, 420.00, v_bulk_id
    );
    CALL sp_update_bulk_purchase_status(v_bulk_id, 'EN_ALMACEN', '2026-01-10 08:00:00');
    CALL sp_register_import_permit(v_bulk_id, 2, CONCAT('PER-FIT-2601-',v_bulk_id), 'SENASAG Nicaragua', '2026-01-05', '2027-01-05', 95.00, v_permit_id);
    CALL sp_register_inventory_movement(1, v_bulk_id, 'ENTRADA', 600.0,  6.00,  NULL, 'Entrada producto 1', v_hub_id);
    CALL sp_create_dispatch_order(1, 120.0::DECIMAL, 1, 6.00::DECIMAL, v_disp_id, v_order_num);
    CALL sp_update_dispatch_order_status(v_disp_id, 'ENTREGADO_COURIER', '2026-01-20 08:00:00');
    CALL sp_register_inventory_movement(1, v_bulk_id, 'SALIDA', 120.0, 6.00, v_disp_id, 'Despacho a CR', v_hub_id);
    CALL sp_recalculate_inventory_stock(1, v_final_stock);

    CALL sp_register_bulk_purchase(
        2, 5, 450.000, 1, 4050.00, 8, 
        225.0, 0.5000, '2026-01-12 10:00:00', 405.00, 380.00, v_bulk_id
        );
    CALL sp_update_bulk_purchase_status(v_bulk_id, 'EN_ALMACEN', '2026-01-12 10:00:00');
    CALL sp_register_import_permit(v_bulk_id, 2, CONCAT('PER-COA-2601-',v_bulk_id), 'MINSA Nicaragua', '2026-01-07', '2027-01-07', 80.00, v_permit_id);
    CALL sp_register_inventory_movement(2,  v_bulk_id,  'ENTRADA', 450.0,  9.00,  NULL, 'Entrada producto 2',  v_hub_id);
    CALL sp_create_dispatch_order(2, 100.0::DECIMAL, 5, 9.00::DECIMAL, v_disp_id, v_order_num);
    CALL sp_update_dispatch_order_status(v_disp_id, 'ENTREGADO_COURIER', '2026-01-22 09:00:00');
    CALL sp_register_inventory_movement(2, v_bulk_id, 'SALIDA', 100.0, 9.00, v_disp_id, 'Despacho a CO', v_hub_id);
    CALL sp_recalculate_inventory_stock(2, v_final_stock);

    CALL sp_register_bulk_purchase(
        3, 2, 500.000, 2, 6500.00, 3, 
        250.0, 0.5500, '2026-01-14 09:00:00', 650.00, 580.00, v_bulk_id
        );
    CALL sp_update_bulk_purchase_status(v_bulk_id, 'EN_ALMACEN', '2026-01-14 09:00:00');
    CALL sp_register_import_permit(v_bulk_id, 2, CONCAT('PER-SAN-2601-',v_bulk_id), 'MINSA Nicaragua', '2026-01-08', '2027-01-08', 120.00, v_permit_id);
    CALL sp_register_inventory_movement(3,  v_bulk_id,  'ENTRADA', 500.0, 13.00,  NULL, 'Entrada producto 3',  v_hub_id);
    CALL sp_create_dispatch_order(3, 150.0::DECIMAL, 6, 13.00::DECIMAL, v_disp_id, v_order_num);
    CALL sp_update_dispatch_order_status(v_disp_id, 'ENTREGADO_COURIER', '2026-01-23 09:00:00');
    CALL sp_register_inventory_movement(3, v_bulk_id, 'SALIDA', 150.0, 13.00, v_disp_id, 'Despacho a MX', v_hub_id);
    CALL sp_recalculate_inventory_stock(3, v_final_stock);

    CALL sp_register_bulk_purchase(
        4, 1, 300.000, 3, 5400.00, 9, 
        150.0, 0.3500, '2026-01-16 11:00:00', 540.00, 490.00, v_bulk_id
        );
    CALL sp_update_bulk_purchase_status(v_bulk_id, 'EN_ALMACEN', '2026-01-16 11:00:00');
    CALL sp_register_import_permit(v_bulk_id, 1, CONCAT('PER-FIT-2601-',v_bulk_id), 'SENASAG Nicaragua', '2026-01-10', '2027-01-10', 75.00, v_permit_id);
    CALL sp_register_inventory_movement(4,  v_bulk_id,  'ENTRADA', 300.0, 18.00,  NULL, 'Entrada producto 4',  v_hub_id);
    CALL sp_create_dispatch_order(4, 80.0::DECIMAL, 4, 18.00::DECIMAL, v_disp_id, v_order_num);
    CALL sp_update_dispatch_order_status(v_disp_id, 'ENTREGADO_COURIER', '2026-01-24 09:00:00');
    CALL sp_register_inventory_movement(4, v_bulk_id, 'SALIDA', 80.0, 18.00, v_disp_id, 'Despacho a ES', v_hub_id);
    CALL sp_recalculate_inventory_stock(4, v_final_stock);

    CALL sp_register_bulk_purchase(
        5, 4, 800.000, 3, 2400.00, 10, 
        400.0, 1.2000, '2026-01-18 08:00:00', 240.00, 310.00, v_bulk_id
        );
    CALL sp_update_bulk_purchase_status(v_bulk_id, 'EN_ALMACEN', '2026-01-18 08:00:00');
    CALL sp_register_import_permit(v_bulk_id, 1, CONCAT('PER-SUP-2601-',v_bulk_id), 'MINSA Nicaragua', '2026-01-12', '2027-01-12', 110.00, v_permit_id);
    CALL sp_register_inventory_movement(5, v_bulk_id,  'ENTRADA', 800.0,  3.00,  NULL, 'Entrada producto 5',  v_hub_id);
    CALL sp_create_dispatch_order(5, 200.0::DECIMAL, 2, 3.00::DECIMAL, v_disp_id, v_order_num);
    CALL sp_update_dispatch_order_status(v_disp_id, 'ENTREGADO_COURIER', '2026-01-25 09:00:00');
    CALL sp_register_inventory_movement(5, v_bulk_id, 'SALIDA', 200.0, 3.00, v_disp_id, 'Despacho a US', v_hub_id);
    CALL sp_recalculate_inventory_stock(5, v_final_stock);


    RAISE NOTICE 'Carga inicial de compras a granel completada satisfactoriamente.';
END $$;

--importpermits
DO $$
DECLARE
    v_import_id  INTEGER;
    v_bulk_id    INTEGER;
    v_type_id    INTEGER;
BEGIN
    -- 1. Permiso Fitozoosanitario para Aceite de Lavanda (Bulk 1)
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases 
     WHERE productId = (SELECT productId FROM Products WHERE productName = 'Aceite de Lavanda de Provenza')
     ORDER BY arrivalDate DESC LIMIT 1;
    
    SELECT permitTypeId INTO v_type_id FROM PermitTypes WHERE permitTypeName = 'Permiso de Importación Fitozoosanitario';

    IF v_bulk_id IS NOT NULL AND v_type_id IS NOT NULL THEN
        CALL sp_register_import_permit(
            v_bulk_id, v_type_id, 'AGRO-FRA-2026-001'::VARCHAR, 'Ministerio de Agricultura'::VARCHAR, 
            CURRENT_DATE, (CURRENT_DATE + INTERVAL '1 year')::DATE, 75.00::DECIMAL, v_import_id
        );
    END IF;

    -- 2. Certificado de Análisis (COA) para Esencia de Sándalo (Bulk 2)
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases 
     WHERE productId = (SELECT productId FROM Products WHERE productName = 'Esencia de Sándalo de Japón')
     ORDER BY arrivalDate DESC LIMIT 1;
    
    SELECT permitTypeId INTO v_type_id FROM PermitTypes WHERE permitTypeName = 'Certificado de Análisis (COA)';

    IF v_bulk_id IS NOT NULL AND v_type_id IS NOT NULL THEN
        CALL sp_register_import_permit(
            v_bulk_id, v_type_id, 'COA-JPN-9928'::VARCHAR, 'Laboratorios Osaka Tech'::VARCHAR, 
            (CURRENT_DATE - INTERVAL '10 days')::DATE, -- Corrección: Cast a DATE
            (CURRENT_DATE + INTERVAL '2 years')::DATE, 45.00::DECIMAL, v_import_id
        );
    END IF;

    -- 3. Registro Sanitario para Serum Facial (Bulk 3)
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases 
     WHERE productId = (SELECT productId FROM Products WHERE productName = 'Serum Facial de Algas Rojas')
     ORDER BY arrivalDate DESC LIMIT 1;
    
    SELECT permitTypeId INTO v_type_id FROM PermitTypes WHERE permitTypeName = 'Registro Sanitario de Salud';

    IF v_bulk_id IS NOT NULL AND v_type_id IS NOT NULL THEN
        CALL sp_register_import_permit(
            v_bulk_id, v_type_id, 'RS-ESP-D-445'::VARCHAR, 'Ministerio de Salud'::VARCHAR, 
            CURRENT_DATE, (CURRENT_DATE + INTERVAL '5 years')::DATE, 250.00::DECIMAL, v_import_id
        );
    END IF;

    -- 4. Registro de Suplementos para Cúrcuma (Bulk 4)
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases 
     WHERE productId = (SELECT productId FROM Products WHERE productName = 'Cápsulas de Cúrcuma Longa')
     ORDER BY arrivalDate DESC LIMIT 1;
    
    SELECT permitTypeId INTO v_type_id FROM PermitTypes WHERE permitTypeName = 'Registro de Suplementos Alimenticios';

    IF v_bulk_id IS NOT NULL AND v_type_id IS NOT NULL THEN
        CALL sp_register_import_permit(
            v_bulk_id, v_type_id, 'SUP-DEU-881'::VARCHAR, 'Dirección de Regulación Sanitaria'::VARCHAR, 
            CURRENT_DATE, (CURRENT_DATE + INTERVAL '3 years')::DATE, 180.00::DECIMAL, v_import_id
        );
    END IF;

    -- 5. Set de Bienestar (bulk 5)
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases 
     WHERE productId = (SELECT productId FROM Products WHERE productName = 'Set de Bienestar "Zen Spirit"')
     ORDER BY arrivalDate DESC LIMIT 1;
    
    SELECT permitTypeId INTO v_type_id FROM PermitTypes WHERE permitTypeName = 'Certificado de Análisis (COA)';

    IF v_bulk_id IS NOT NULL AND v_type_id IS NOT NULL THEN
        CALL sp_register_import_permit(
            v_bulk_id, v_type_id, 'COA-USA-MIA-2026-005'::VARCHAR, 'FDA / Customs and Border Protection'::VARCHAR, 
            CURRENT_DATE, (CURRENT_DATE + INTERVAL '2 years')::DATE, 180.00::DECIMAL, v_import_id
        );
    END IF;

    RAISE NOTICE 'Permisos de importación vinculados exitosamente.';
END $$;

-- dispatchorders
DO $$
DECLARE
    v_dispatch_id  INTEGER;
    v_order_num    VARCHAR(60);
    v_prod_id      INTEGER;
    v_country_id   INTEGER;
BEGIN
    -- 1. Despacho a MÉXICO: Serum Facial de Algas Rojas
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Serum Facial de Algas Rojas';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'MX';
    
    v_order_num := NULL; -- Limpiar para el siguiente INOUT
    CALL sp_create_dispatch_order(v_prod_id, 100.000::DECIMAL, v_country_id, 12.5000::DECIMAL, v_dispatch_id, v_order_num);
    RAISE NOTICE 'Orden generada: %', v_order_num;

    -- 2. Despacho a PANAMÁ: Jabón de Carbón Activado y Menta
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Jabón de Carbón Activado y Menta';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'PA';
    
    v_order_num := NULL;
    CALL sp_create_dispatch_order(v_prod_id, 250.000::DECIMAL, v_country_id, 4.2500::DECIMAL, v_dispatch_id, v_order_num);
    RAISE NOTICE 'Orden generada: %', v_order_num;

    -- 3. Despacho a COLOMBIA: Cápsulas de Cúrcuma Longa
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Cápsulas de Cúrcuma Longa';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'CO';
    
    v_order_num := NULL;
    CALL sp_create_dispatch_order(v_prod_id, 500.000::DECIMAL, v_country_id, 0.1500::DECIMAL, v_dispatch_id, v_order_num);
    RAISE NOTICE 'Orden generada: %', v_order_num;

    -- 4. Despacho a BRASIL: Perfume "Bruma del Desierto"
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Perfume "Bruma del Desierto" (Eau de Parfum)';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'BR';
    
    v_order_num := NULL;
    CALL sp_create_dispatch_order(v_prod_id, 75.000::DECIMAL, v_country_id, 45.0000::DECIMAL, v_dispatch_id, v_order_num);
    RAISE NOTICE 'Orden generada: %', v_order_num;

    -- 5. Segundo Despacho a COSTA RICA 
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Crema Hidratante de Karité Dorado';
    SELECT countryId INTO v_country_id FROM Countries WHERE isoCode = 'CR';
    
    v_order_num := NULL;
    CALL sp_create_dispatch_order(v_prod_id, 120.000::DECIMAL, v_country_id, 18.0000::DECIMAL, v_dispatch_id, v_order_num);
    RAISE NOTICE 'Orden generada: %', v_order_num;

END $$;

-- inventoryhub:
DO $$
DECLARE
    v_movement_id  INTEGER;
    v_prod_id      INTEGER;
    v_bulk_id      INTEGER;
    v_dispatch_id  INTEGER;
BEGIN
    -- 1. ENTRADA: Aceite de Lavanda (Bulk 1)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Aceite de Lavanda de Provenza';
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases WHERE productId = v_prod_id ORDER BY arrivalDate DESC LIMIT 1;

    CALL sp_register_inventory_movement(
        v_prod_id, 
        v_bulk_id, 
        'ENTRADA'::VARCHAR, 
        50.000::DECIMAL,    
        24.0000::DECIMAL,   
        v_bulk_id,               
        'Carga inicial desde Francia'::VARCHAR, 
        v_movement_id
    );

    -- 2. ENTRADA: Serum Facial de Algas Rojas (Bulk 3)
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Serum Facial de Algas Rojas';
    SELECT bulkId INTO v_bulk_id FROM BulkPurchases WHERE productId = v_prod_id ORDER BY arrivalDate DESC LIMIT 1;

    CALL sp_register_inventory_movement(
        v_prod_id, 
        v_bulk_id, 
        'ENTRADA'::VARCHAR, 
        500.000::DECIMAL, 
        17.0000::DECIMAL, 
        v_bulk_id, 
        'Ingreso de lote desde España'::VARCHAR, 
        v_movement_id
    );

    -- 3. SALIDA: Despacho a Costa Rica (Usando la orden generada anteriormente)
    -- Buscamos el producto y la orden pendiente
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Aceite de Lavanda de Provenza';
    SELECT dispatchOrderId INTO v_dispatch_id FROM DispatchOrders 
     WHERE productId = v_prod_id AND externalOrderNumber LIKE 'EXP-CR-%' 
     ORDER BY createdAt DESC LIMIT 1;

    IF v_dispatch_id IS NOT NULL THEN
        CALL sp_register_inventory_movement(
            v_prod_id, 
            v_bulk_id,              
            'SALIDA'::VARCHAR, 
            15.000::DECIMAL,    
            25.5000::DECIMAL,   
            v_dispatch_id, 
            'Envío a San José, Costa Rica'::VARCHAR, 
            v_movement_id
        );
    END IF;
    RAISE NOTICE 'Movimientos de inventario procesados con éxito.';
END $$;

-- inventorystock
DO $$
DECLARE
    v_prod_id     INTEGER;
    v_final_stock DECIMAL(12,3);
BEGIN
    SELECT productId INTO v_prod_id FROM Products WHERE productName = 'Aceite de Lavanda de Provenza';

    -- Sincroniza la tabla de stock sumando todo el historial de InventoryHub
    CALL sp_recalculate_inventory_stock(
        v_prod_id, 
        v_final_stock 
    );

    RAISE NOTICE 'Stock recalculado exitosamente. Saldo auditado: %', v_final_stock;
END $$;

-- Configuracion inicial:

DO $$
DECLARE
    v_prod_record RECORD;
    v_warehouse_id INTEGER;
    v_stock_id     INTEGER;
    v_initial_qty  CONSTANT INTEGER := 600;
BEGIN
    SELECT warehouseId INTO v_warehouse_id 
    FROM Warehouses 
    WHERE isDeleted = FALSE 
    ORDER BY warehouseId ASC 
    LIMIT 1;

    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró un almacén activo para cargar el stock.';
    END IF;

    RAISE NOTICE 'Iniciando carga de stock en Almacén ID: %', v_warehouse_id;
    FOR v_prod_record IN 
        SELECT productId, productName 
        FROM Products 
        WHERE isDeleted = FALSE
    LOOP
        CALL sp_upsert_inventory_stock(
            v_prod_record.productId, 
            v_warehouse_id, 
            v_initial_qty, 
            v_stock_id
        );

        RAISE NOTICE 'Stock de 600 unidades cargado para: % (ID: %)', 
                     v_prod_record.productName, v_prod_record.productId;
    END LOOP;

    RAISE NOTICE 'Carga masiva completada con éxito.';
END $$;