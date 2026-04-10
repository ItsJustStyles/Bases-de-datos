- Database engine: PostgreSQL 18
- Database name: etheria_global_db
- Context: Sistema encargado de una cadena de suministro. Donde se importan productos naturales y curativos exóticos de todo el mundo (bebidas, alimentos, cosmética dermatológica, capilar, aromaterapia, jabones y aceites esenciales).

# Tables

## Products_bulk

- products_bulk_id
    - tipo: serial
    - pk: si
    - descripcion: identificador del bulk de los productos

- quantity_product
    - tipo: Decimal(10,3)
    - pk: no
    - descripcion: la cantidad granel del producto del bulk

- measurementUnitId
    - tipo: integer (FK)
    - pk: no
    - descripcion: la unidad en la que esta el granel del producto

- individual_product_id
    - tipo: integer (FK)
    - pk: no 
    - descripcion: productos individuales del bulk

- price_bulk
    - tipo: Decimal(12,2)
    - pk: no
    - descripcion: precio de un bulk de productos en dolares

- origin_country
    - tipo: varchar(60)
    - pk: no
    - descripcion: pais de origen de un bulk de productos

- weight_bulk
    - tipo: Decimal(10, 3)
    - pk: no
    - descripcion: el peso del bulk en kilogramos

- volume_bulk
    - tipo: DECIMAL(10, 4)
    - pk: no
    - descripcion: el volumen que ocupa el bulk en metros cubicos

- arrival_date 
    - tipo: Timestamp
    - pk: no
    - descripcion: fecha y hora en la que llego el bulk

- supplier_id
    - tipo: integer (FK)
    - pk: no
    - descripcion: a quien se le compro el bulk

- is_deleted
    - tipo: boolean
    - pk: no
    - descripcion: indica si el registro fue borrado

- updatedAt
    - tipo: timestamp
    - pk: no
    - descripcion: fecha y hora de la ultima modificacion

- createdAt
    - tipo: timestamp
    - pk: no
    - descripcion: fecha y hora en la que se registro el bulk

## Individual_product

- individual_product_id
    - tipo: serial
    - pk: si
    - descripcion: identificador de los productos individuales

- name
    - tipo: varchar()
    - pk: no
    - descripcion: el volumen que ocupa el bulk en metros cubicos

## MeasurementUnits


## Supplier