"""
ETL DAG — Etheria Global (PostgreSQL) + Dynamic Brands (MySQL) → Data Warehouse
Archivo: dags/etl_dw_dag.py

Cómo usarlo:
  1. Copiar este archivo a la carpeta ./dags/ de tu proyecto
  2. Asegurarse de que el airflow_webserver y airflow_scheduler tengan
     instaladas las dependencias extra (ya configuradas en docker-compose):
       pandas, sqlalchemy, psycopg2-binary, mysql-connector-python
  3. El DAG corre automáticamente cada día a las 2 AM (hora CR)
  4. También se puede disparar manualmente desde el UI de Airflow
"""

import logging
from datetime import datetime, timedelta, date

import pandas as pd
from sqlalchemy import create_engine, text

from airflow import DAG
from airflow.operators.python import PythonOperator

# ──────────────────────────────────────────────────────────────
#  CONEXIONES
#  Los hosts deben ser los nombres de servicio del docker-compose
# ──────────────────────────────────────────────────────────────
ETHERIA_URL = "postgresql+psycopg2://etheria:etheria123@db:5432/etheria_global_db"
DYNAMIC_URL = "mysql+mysqlconnector://dynamic:brands123@dynamic_db:3306/dynamic_brands_db"
DW_URL      = "postgresql+psycopg2://analytics_user:dwh_password@data_warehouse:5432/warehouse"

log = logging.getLogger(__name__)


def get_engines():
    return (
        create_engine(ETHERIA_URL),
        create_engine(DYNAMIC_URL),
        create_engine(DW_URL),
    )


# ──────────────────────────────────────────────────────────────
#  HELPER: resolver surrogate key
# ──────────────────────────────────────────────────────────────
def resolve_sk(conn, table, source_col, sk_col, value):
    """Devuelve el surrogate key o -1 si no se encuentra."""
    q = f"SELECT {sk_col} FROM dw.{table} WHERE {source_col} = :v AND (is_current IS NULL OR is_current = TRUE)"
    row = conn.execute(text(q), {"v": value}).fetchone()
    return int(row[0]) if row else -1


def resolve_fecha_sk(conn, dt):
    """Devuelve el fecha_sk para un objeto date o datetime."""
    if dt is None:
        return -1
    if isinstance(dt, datetime):
        dt = dt.date()
    row = conn.execute(
        text("SELECT fecha_sk FROM dw.dim_fecha WHERE fecha = :d"),
        {"d": dt}
    ).fetchone()
    return int(row[0]) if row else -1


# ══════════════════════════════════════════════════════════════
#  PASO 1 — VALIDAR CONEXIONES
# ══════════════════════════════════════════════════════════════
def validar_conexiones(**ctx):
    eth, dyn, dw = get_engines()
    for name, eng in [("Etheria", eth), ("Dynamic", dyn), ("DW", dw)]:
        with eng.connect() as c:
            c.execute(text("SELECT 1"))
        log.info("✅ Conexión OK: %s", name)
    log.info("Todas las conexiones verificadas.")


# ══════════════════════════════════════════════════════════════
#  PASO 2 — CARGAR DIMENSIONES
# ══════════════════════════════════════════════════════════════
def load_dim_pais(**ctx):
    """
    Une Countries de Etheria con Countries de Dynamic usando isoCode.
    Inserta/actualiza dim_pais en el DW.
    """
    eth, dyn, dw = get_engines()

    eth_countries = pd.read_sql(
        "SELECT countryId, countryName, isoCode FROM Countries WHERE isDeleted = FALSE",
        eth
    )
    dyn_countries = pd.read_sql(
        "SELECT countryId, countryName, isoCode FROM Countries WHERE isDeleted = 0",
        dyn
    )

    # Unir por isoCode; prioridad a Etheria
    all_countries = pd.concat([
        eth_countries[["countryName", "isoCode"]],
        dyn_countries[["countryName", "isoCode"]],
    ]).drop_duplicates("isoCode")

    inserted = 0
    with dw.begin() as conn:
        for _, row in all_countries.iterrows():
            exists = conn.execute(
                text("SELECT pais_sk FROM dw.dim_pais WHERE iso_code = :iso"),
                {"iso": row["isoCode"]}
            ).fetchone()
            if not exists:
                conn.execute(text("""
                    INSERT INTO dw.dim_pais (iso_code, country_name)
                    VALUES (:iso, :name)
                """), {"iso": row["isoCode"], "name": row["countryName"]})
                inserted += 1

    log.info("dim_pais: %d filas insertadas", inserted)


def load_dim_producto(**ctx):
    """
    Combina Products + ProductCategories de Etheria con
    ProductCatalog de Dynamic (usando etheriaProductId como llave).
    Aplica SCD Tipo 2 si cambia el precio o el nombre.
    """
    eth, dyn, dw = get_engines()

    products = pd.read_sql("""
        SELECT p.productId, p.productName, pc.categoryName,
               mu.unitName AS baseUnit, p.unitWeightKg, p.unitVolumeM3
        FROM Products p
        JOIN ProductCategories pc ON p.categoryId = pc.categoryId
        JOIN MeasurementUnits mu  ON p.baseUnitId  = mu.unitId
        WHERE p.isDeleted = FALSE
    """, eth)

    prices = pd.read_sql("""
        SELECT productId, salePriceUsd, validFrom, validTo
        FROM ProductPrices
        WHERE (validTo IS NULL OR validTo >= CURRENT_DATE)
          AND validFrom <= CURRENT_DATE
        ORDER BY validFrom DESC
    """, eth)
    prices = prices.drop_duplicates("productId", keep="first")

    catalog = pd.read_sql("""
        SELECT DISTINCT etheriaProductId, brandedName, categoryLabel
        FROM ProductCatalog
        WHERE isDeleted = 0
    """, dyn)
    catalog = catalog.drop_duplicates("etheriaProductId", keep="first")

    merged = products.merge(prices[["productId","salePriceUsd"]], on="productId", how="left")
    merged = merged.merge(catalog, left_on="productId", right_on="etheriaProductId", how="left")
    merged["salePriceUsd"] = merged["salePriceUsd"].fillna(0)

    inserted = updated = 0
    with dw.begin() as conn:
        for _, row in merged.iterrows():
            existing = conn.execute(text("""
                SELECT producto_sk, sale_price_usd, product_name
                FROM dw.dim_producto
                WHERE etheria_product_id = :pid AND is_current = TRUE
            """), {"pid": int(row["productId"])}).fetchone()

            price = float(row["salePriceUsd"]) if pd.notna(row["salePriceUsd"]) else 0.0
            name  = str(row["productName"])

            if existing is None:
                conn.execute(text("""
                    INSERT INTO dw.dim_producto
                        (etheria_product_id, product_name, category_name, base_unit,
                         unit_weight_kg, unit_volume_m3, branded_name, category_label,
                         sale_price_usd, valid_from, is_current)
                    VALUES
                        (:pid, :name, :cat, :unit,
                         :wkg, :vm3, :bname, :clabel,
                         :price, CURRENT_DATE, TRUE)
                """), {
                    "pid":    int(row["productId"]),
                    "name":   name,
                    "cat":    row.get("categoryName") or None,
                    "unit":   row.get("baseUnit") or None,
                    "wkg":    float(row["unitWeightKg"]) if pd.notna(row.get("unitWeightKg")) else None,
                    "vm3":    float(row["unitVolumeM3"]) if pd.notna(row.get("unitVolumeM3")) else None,
                    "bname":  row.get("brandedName") or None,
                    "clabel": row.get("categoryLabel") or None,
                    "price":  price,
                })
                inserted += 1
            else:
                ex_price = float(existing[1]) if existing[1] is not None else 0.0
                ex_name  = existing[2]
                if abs(ex_price - price) > 0.0001 or ex_name != name:
                    # Cerrar registro anterior (SCD2)
                    conn.execute(text("""
                        UPDATE dw.dim_producto
                        SET valid_to = CURRENT_DATE, is_current = FALSE
                        WHERE producto_sk = :sk
                    """), {"sk": int(existing[0])})
                    # Insertar nuevo registro
                    conn.execute(text("""
                        INSERT INTO dw.dim_producto
                            (etheria_product_id, product_name, category_name, base_unit,
                             unit_weight_kg, unit_volume_m3, branded_name, category_label,
                             sale_price_usd, valid_from, is_current)
                        VALUES
                            (:pid, :name, :cat, :unit,
                             :wkg, :vm3, :bname, :clabel,
                             :price, CURRENT_DATE, TRUE)
                    """), {
                        "pid":    int(row["productId"]),
                        "name":   name,
                        "cat":    row.get("categoryName") or None,
                        "unit":   row.get("baseUnit") or None,
                        "wkg":    float(row["unitWeightKg"]) if pd.notna(row.get("unitWeightKg")) else None,
                        "vm3":    float(row["unitVolumeM3"]) if pd.notna(row.get("unitVolumeM3")) else None,
                        "bname":  row.get("brandedName") or None,
                        "clabel": row.get("categoryLabel") or None,
                        "price":  price,
                    })
                    updated += 1

    log.info("dim_producto: %d insertados, %d actualizados (SCD2)", inserted, updated)


def load_dim_cliente(**ctx):
    """Carga clientes de Dynamic Brands."""
    _, dyn, dw = get_engines()

    customers = pd.read_sql("""
        SELECT c.customerId, c.firstName, c.lastName, c.email,
               co.isoCode
        FROM Customers c
        JOIN Countries co ON c.countryId = co.countryId
        WHERE c.isDeleted = 0
    """, dyn)

    inserted = updated = 0
    with dw.begin() as conn:
        for _, row in customers.iterrows():
            full_name = f"{row['firstName']} {row['lastName']}"
            pais_sk = conn.execute(
                text("SELECT pais_sk FROM dw.dim_pais WHERE iso_code = :iso"),
                {"iso": row["isoCode"]}
            ).fetchone()
            pais_sk = int(pais_sk[0]) if pais_sk else -1

            existing = conn.execute(text("""
                SELECT cliente_sk, email FROM dw.dim_cliente
                WHERE dynamic_cust_id = :cid AND is_current = TRUE
            """), {"cid": int(row["customerId"])}).fetchone()

            if existing is None:
                conn.execute(text("""
                    INSERT INTO dw.dim_cliente
                        (dynamic_cust_id, full_name, email, pais_sk, valid_from, is_current)
                    VALUES (:cid, :name, :email, :pais, CURRENT_DATE, TRUE)
                """), {"cid": int(row["customerId"]), "name": full_name,
                       "email": row["email"], "pais": pais_sk})
                inserted += 1
            elif existing[1] != row["email"]:
                conn.execute(text("""
                    UPDATE dw.dim_cliente
                    SET valid_to = CURRENT_DATE, is_current = FALSE
                    WHERE cliente_sk = :sk
                """), {"sk": int(existing[0])})
                conn.execute(text("""
                    INSERT INTO dw.dim_cliente
                        (dynamic_cust_id, full_name, email, pais_sk, valid_from, is_current)
                    VALUES (:cid, :name, :email, :pais, CURRENT_DATE, TRUE)
                """), {"cid": int(row["customerId"]), "name": full_name,
                       "email": row["email"], "pais": pais_sk})
                updated += 1

    log.info("dim_cliente: %d insertados, %d actualizados", inserted, updated)


def load_dim_proveedor(**ctx):
    eth, _, dw = get_engines()
    suppliers = pd.read_sql("""
        SELECT s.supplierId, s.supplierName, s.isActive, co.isoCode
        FROM Suppliers s
        JOIN Countries co ON s.countryId = co.countryId
        WHERE s.isDeleted = FALSE
    """, eth)

    inserted = 0
    with dw.begin() as conn:
        for _, row in suppliers.iterrows():
            exists = conn.execute(text("""
                SELECT proveedor_sk FROM dw.dim_proveedor
                WHERE etheria_supplier_id = :sid
            """), {"sid": int(row["supplierId"])}).fetchone()
            if not exists:
                pais_sk = conn.execute(
                    text("SELECT pais_sk FROM dw.dim_pais WHERE iso_code = :iso"),
                    {"iso": row["isoCode"]}
                ).fetchone()
                conn.execute(text("""
                    INSERT INTO dw.dim_proveedor
                        (etheria_supplier_id, supplier_name, pais_sk, is_active)
                    VALUES (:sid, :name, :pais, :active)
                """), {
                    "sid":    int(row["supplierId"]),
                    "name":   str(row["supplierName"]),
                    "pais":   int(pais_sk[0]) if pais_sk else -1,
                    "active": bool(row["isActive"]),
                })
                inserted += 1

    log.info("dim_proveedor: %d insertados", inserted)


def load_dim_marca(**ctx):
    _, dyn, dw = get_engines()
    brands = pd.read_sql(
        "SELECT brandId, brandName, brandFocus FROM Brands WHERE isDeleted = 0", dyn
    )

    inserted = 0
    with dw.begin() as conn:
        for _, row in brands.iterrows():
            exists = conn.execute(text("""
                SELECT marca_sk FROM dw.dim_marca WHERE dynamic_brand_id = :bid
            """), {"bid": int(row["brandId"])}).fetchone()
            if not exists:
                conn.execute(text("""
                    INSERT INTO dw.dim_marca (dynamic_brand_id, brand_name, brand_focus)
                    VALUES (:bid, :name, :focus)
                """), {"bid": int(row["brandId"]), "name": str(row["brandName"]),
                       "focus": row.get("brandFocus") or None})
                inserted += 1

    log.info("dim_marca: %d insertados", inserted)


def load_dim_courier(**ctx):
    _, dyn, dw = get_engines()
    couriers = pd.read_sql(
        "SELECT courierId, courierName, isActive FROM Couriers WHERE isDeleted = 0", dyn
    )

    inserted = 0
    with dw.begin() as conn:
        for _, row in couriers.iterrows():
            exists = conn.execute(text("""
                SELECT courier_sk FROM dw.dim_courier WHERE dynamic_courier_id = :cid
            """), {"cid": int(row["courierId"])}).fetchone()
            if not exists:
                conn.execute(text("""
                    INSERT INTO dw.dim_courier (dynamic_courier_id, courier_name, is_active)
                    VALUES (:cid, :name, :active)
                """), {"cid": int(row["courierId"]), "name": str(row["courierName"]),
                       "active": bool(row["isActive"])})
                inserted += 1

    log.info("dim_courier: %d insertados", inserted)


# ══════════════════════════════════════════════════════════════
#  PASO 3 — CARGAR FACTS
# ══════════════════════════════════════════════════════════════
def load_fact_ventas(**ctx):
    """
    Combina Orders + OrderItems + ShippingRecords + WebsiteProducts
    + ProductCatalog para construir fact_ventas.
    """
    _, dyn, dw = get_engines()

    # Extraer datos de Dynamic
    orders = pd.read_sql("""
        SELECT o.orderId, o.customerId, o.orderDate,
               o.totalAmountLocal, o.exchangeRateSnapshot,
               o.totalAmountUsd, o.status AS orderStatus,
               o.currencyId,
               co.isoCode AS countryIso
        FROM Orders o
        JOIN CustomerAddresses ca ON o.customerAddressId = ca.customerAddressId
        JOIN Cities ci ON ca.cityId = ci.cityId
        JOIN Regions r ON ci.regionId = r.regionId
        JOIN Countries co ON r.countryId = co.countryId
        WHERE o.isDeleted = 0
    """, dyn)

    items = pd.read_sql("""
        SELECT oi.orderItemId, oi.orderId, oi.quantity,
               oi.unitPriceLocal, oi.subtotalLocal,
               wp.catalogProductId,
               pc.etheriaProductId, pc.brandId
        FROM OrderItems oi
        JOIN WebsiteProducts wp ON oi.websiteProductId = wp.websiteProductId
        JOIN ProductCatalog pc  ON wp.catalogProductId = pc.catalogProductId
        WHERE oi.isDeleted = 0
    """, dyn)

    shipping = pd.read_sql("""
        SELECT orderId, courierId, shippingCostLocal,
               exchangeRateSnapshot AS shipRateSnapshot,
               estimatedDeliveryDate, actualDeliveryDate,
               status AS shippingStatus
        FROM ShippingRecords
        WHERE isDeleted = 0
    """, dyn)

    currencies = pd.read_sql(
        "SELECT currencyId, currencyCode FROM Currencies", dyn
    )

    # Hacer joins
    df = items.merge(orders, on="orderId", how="left")
    df = df.merge(shipping, on="orderId", how="left")
    df = df.merge(currencies, on="currencyId", how="left")

    # Calcular en USD
    df["subtotal_usd"] = (df["subtotalLocal"] / df["exchangeRateSnapshot"]).round(4)
    df["shipping_cost_usd"] = (
        df["shippingCostLocal"].fillna(0) / df["shipRateSnapshot"].fillna(1)
    ).round(4)
    df["shipping_cost_usd"] = df["shipping_cost_usd"].fillna(0)

    inserted = skipped = 0
    with dw.begin() as conn:
        for _, row in df.iterrows():
            # Verificar idempotencia
            exists = conn.execute(text("""
                SELECT venta_sk FROM dw.fact_ventas
                WHERE dynamic_order_item_id = :iid
            """), {"iid": int(row["orderItemId"])}).fetchone()
            if exists:
                skipped += 1
                continue

            # Resolver surrogate keys
            order_dt = pd.to_datetime(row["orderDate"]).date() if pd.notna(row.get("orderDate")) else date.today()
            fecha_sk  = resolve_fecha_sk(conn, order_dt)

            prod_sk = resolve_sk(conn, "dim_producto", "etheria_product_id",
                                 "producto_sk", int(row["etheriaProductId"]))
            cli_sk  = resolve_sk(conn, "dim_cliente", "dynamic_cust_id",
                                 "cliente_sk",  int(row["customerId"]))
            pais_sk = conn.execute(
                text("SELECT pais_sk FROM dw.dim_pais WHERE iso_code = :iso"),
                {"iso": row.get("countryIso") or "UNK"}
            ).fetchone()
            pais_sk = int(pais_sk[0]) if pais_sk else -1

            marca_sk   = resolve_sk(conn, "dim_marca",   "dynamic_brand_id",  "marca_sk",   int(row["brandId"]))
            courier_sk = resolve_sk(conn, "dim_courier",  "dynamic_courier_id", "courier_sk",
                                    int(row["courierId"]) if pd.notna(row.get("courierId")) else -1)

            # Costo de Etheria para calcular margen
            precio_row = conn.execute(text("""
                SELECT sale_price_usd FROM dw.dim_producto
                WHERE etheria_product_id = :pid AND is_current = TRUE
            """), {"pid": int(row["etheriaProductId"])}).fetchone()
            costo_usd  = float(precio_row[0]) * int(row["quantity"]) if precio_row and precio_row[0] else None
            margen_usd = (float(row["subtotal_usd"]) - costo_usd) if costo_usd is not None else None

            conn.execute(text("""
                INSERT INTO dw.fact_ventas (
                    fecha_sk, producto_sk, cliente_sk, pais_sk, marca_sk, courier_sk,
                    dynamic_order_id, dynamic_order_item_id,
                    quantity, unit_price_local, subtotal_local,
                    currency_code, exchange_rate_usd, subtotal_usd,
                    costo_etheria_usd, margen_bruto_usd, shipping_cost_usd,
                    order_status, shipping_status,
                    estimated_delivery, actual_delivery
                ) VALUES (
                    :fecha_sk, :prod_sk, :cli_sk, :pais_sk, :marca_sk, :courier_sk,
                    :oid, :iid,
                    :qty, :unit_price, :subtotal_local,
                    :cur, :rate, :subtotal_usd,
                    :costo, :margen, :ship_cost,
                    :ostatus, :sstatus,
                    :est_del, :act_del
                )
                ON CONFLICT (dynamic_order_item_id) DO NOTHING
            """), {
                "fecha_sk":      fecha_sk,
                "prod_sk":       prod_sk,
                "cli_sk":        cli_sk,
                "pais_sk":       pais_sk,
                "marca_sk":      marca_sk,
                "courier_sk":    courier_sk if courier_sk != -1 else None,
                "oid":           int(row["orderId"]),
                "iid":           int(row["orderItemId"]),
                "qty":           int(row["quantity"]),
                "unit_price":    float(row["unitPriceLocal"]),
                "subtotal_local":float(row["subtotalLocal"]),
                "cur":           str(row.get("currencyCode") or "USD"),
                "rate":          float(row["exchangeRateSnapshot"]),
                "subtotal_usd":  float(row["subtotal_usd"]),
                "costo":         costo_usd,
                "margen":        margen_usd,
                "ship_cost":     float(row["shipping_cost_usd"]),
                "ostatus":       str(row.get("orderStatus") or ""),
                "sstatus":       str(row.get("shippingStatus") or "") if pd.notna(row.get("shippingStatus")) else None,
                "est_del":       row.get("estimatedDeliveryDate") if pd.notna(row.get("estimatedDeliveryDate")) else None,
                "act_del":       row.get("actualDeliveryDate") if pd.notna(row.get("actualDeliveryDate")) else None,
            })
            inserted += 1

    log.info("fact_ventas: %d insertados, %d ya existían", inserted, skipped)


def load_fact_inventario(**ctx):
    """Carga movimientos del InventoryHub de Etheria."""
    eth, _, dw = get_engines()

    hub = pd.read_sql("""
        SELECT ih.inventoryHubId, ih.productId, ih.movementType,
               ih.quantity, ih.costPerUnitUsd, ih.dispatchOrderId,
               ih.createdAt
        FROM InventoryHub ih
        WHERE ih.isDeleted = FALSE
    """, eth)

    inserted = skipped = 0
    with dw.begin() as conn:
        for _, row in hub.iterrows():
            exists = conn.execute(text("""
                SELECT inv_sk FROM dw.fact_inventario WHERE etheria_hub_id = :hid
            """), {"hid": int(row["inventoryHubId"])}).fetchone()
            if exists:
                skipped += 1
                continue

            fecha_sk = resolve_fecha_sk(conn, pd.to_datetime(row["createdAt"]).date())
            prod_sk  = resolve_sk(conn, "dim_producto", "etheria_product_id",
                                  "producto_sk", int(row["productId"]))

            qty   = float(row["quantity"])
            cpu   = float(row["costPerUnitUsd"])
            total = round(qty * cpu, 4)

            conn.execute(text("""
                INSERT INTO dw.fact_inventario
                    (fecha_sk, producto_sk, movement_type, quantity,
                     cost_per_unit_usd, total_cost_usd,
                     etheria_hub_id, etheria_dispatch_id)
                VALUES (:fsk, :psk, :mt, :qty, :cpu, :total, :hid, :did)
                ON CONFLICT (etheria_hub_id) DO NOTHING
            """), {
                "fsk":   fecha_sk,
                "psk":   prod_sk,
                "mt":    str(row["movementType"]),
                "qty":   qty,
                "cpu":   cpu,
                "total": total,
                "hid":   int(row["inventoryHubId"]),
                "did":   int(row["dispatchOrderId"]) if pd.notna(row.get("dispatchOrderId")) else None,
            })
            inserted += 1

    log.info("fact_inventario: %d insertados, %d ya existían", inserted, skipped)


def load_fact_compras(**ctx):
    """Carga las importaciones (BulkPurchases) de Etheria."""
    eth, _, dw = get_engines()

    bulks = pd.read_sql("""
        SELECT bp.bulkId, bp.productId, bp.supplierId,
               bp.quantityBulk, bp.priceBulkUsd,
               bp.importDutyUsd, bp.freightCostUsd,
               bp.status, bp.purchaseDate,
               s.countryId,
               co.isoCode
        FROM BulkPurchases bp
        JOIN Suppliers s  ON bp.supplierId = s.supplierId
        JOIN Countries co ON s.countryId   = co.countryId
        WHERE bp.isDeleted = FALSE
    """, eth)

    # Permisos de importación (costo extra)
    permits = pd.read_sql("""
        SELECT bulkId, SUM(permitCostUsd) AS permit_cost
        FROM ImportPermits
        WHERE isDeleted = FALSE
        GROUP BY bulkId
    """, eth)

    bulks = bulks.merge(permits, on="bulkId", how="left")
    bulks["permit_cost"] = bulks["permit_cost"].fillna(0)

    inserted = skipped = 0
    with dw.begin() as conn:
        for _, row in bulks.iterrows():
            exists = conn.execute(text("""
                SELECT compra_sk FROM dw.fact_compras WHERE etheria_bulk_id = :bid
            """), {"bid": int(row["bulkId"])}).fetchone()
            if exists:
                skipped += 1
                continue

            fecha_sk = resolve_fecha_sk(conn, pd.to_datetime(row["purchaseDate"]).date())
            prod_sk  = resolve_sk(conn, "dim_producto", "etheria_product_id",
                                  "producto_sk", int(row["productId"]))
            prov_sk  = resolve_sk(conn, "dim_proveedor", "etheria_supplier_id",
                                  "proveedor_sk", int(row["supplierId"]))
            pais_row = conn.execute(
                text("SELECT pais_sk FROM dw.dim_pais WHERE iso_code = :iso"),
                {"iso": row["isoCode"]}
            ).fetchone()
            pais_sk = int(pais_row[0]) if pais_row else -1

            duty    = float(row.get("importDutyUsd")  or 0)
            freight = float(row.get("freightCostUsd") or 0)
            permit  = float(row.get("permit_cost")    or 0)
            price   = float(row["priceBulkUsd"])
            total   = round(price + duty + freight + permit, 2)

            conn.execute(text("""
                INSERT INTO dw.fact_compras
                    (fecha_sk, producto_sk, proveedor_sk, pais_origen_sk,
                     quantity_bulk, price_bulk_usd,
                     import_duty_usd, freight_cost_usd, permit_cost_usd,
                     total_landed_usd, bulk_status, etheria_bulk_id)
                VALUES
                    (:fsk, :psk, :prvsk, :paissk,
                     :qty, :price,
                     :duty, :freight, :permit,
                     :total, :status, :bid)
                ON CONFLICT (etheria_bulk_id) DO NOTHING
            """), {
                "fsk":     fecha_sk,
                "psk":     prod_sk,
                "prvsk":   prov_sk,
                "paissk":  pais_sk,
                "qty":     float(row["quantityBulk"]),
                "price":   price,
                "duty":    duty,
                "freight": freight,
                "permit":  permit,
                "total":   total,
                "status":  str(row.get("status") or ""),
                "bid":     int(row["bulkId"]),
            })
            inserted += 1

    log.info("fact_compras: %d insertados, %d ya existían", inserted, skipped)


# ══════════════════════════════════════════════════════════════
#  PASO 4 — AUDITORÍA
# ══════════════════════════════════════════════════════════════
def registrar_auditoria(**ctx):
    _, _, dw = get_engines()
    start = ctx["data_interval_start"] or datetime.utcnow()
    end   = datetime.utcnow()
    dur   = int((end - start).total_seconds())

    with dw.begin() as conn:
        conn.execute(text("""
            INSERT INTO etl.audit_log
                (dag_name, task_name, run_start, run_end, duration_secs, status)
            VALUES (:dag, :task, :start, :end, :dur, 'SUCCESS')
        """), {
            "dag":   ctx["dag"].dag_id,
            "task":  "pipeline_completo",
            "start": start,
            "end":   end,
            "dur":   dur,
        })
    log.info("✅ ETL completado en %d segundos", dur)


# ══════════════════════════════════════════════════════════════
#  DEFINICIÓN DEL DAG
# ══════════════════════════════════════════════════════════════
default_args = {
    "owner":            "data-team",
    "retries":          2,
    "retry_delay":      timedelta(minutes=3),
    "email_on_failure": False,
}

with DAG(
    dag_id          = "etl_dw_etheria_dynamic",
    default_args    = default_args,
    description     = "ETL diario Etheria (PG) + Dynamic (MySQL) → Data Warehouse",
    schedule_interval = "0 2 * * *",    # 2 AM diario
    start_date      = datetime(2024, 5, 1),
    catchup         = False,
    tags            = ["etl", "data-warehouse", "etheria", "dynamic"],
) as dag:

    t_validar = PythonOperator(
        task_id         = "validar_conexiones",
        python_callable = validar_conexiones,
    )

    # ── Dimensiones (pueden correr casi en paralelo) ──
    t_pais       = PythonOperator(task_id="load_dim_pais",       python_callable=load_dim_pais)
    t_marca      = PythonOperator(task_id="load_dim_marca",      python_callable=load_dim_marca)
    t_courier    = PythonOperator(task_id="load_dim_courier",    python_callable=load_dim_courier)
    t_proveedor  = PythonOperator(task_id="load_dim_proveedor",  python_callable=load_dim_proveedor)
    # producto y cliente dependen de que dim_pais ya exista
    t_producto   = PythonOperator(task_id="load_dim_producto",   python_callable=load_dim_producto)
    t_cliente    = PythonOperator(task_id="load_dim_cliente",    python_callable=load_dim_cliente)

    # ── Facts ──
    t_ventas     = PythonOperator(task_id="load_fact_ventas",     python_callable=load_fact_ventas)
    t_inventario = PythonOperator(task_id="load_fact_inventario", python_callable=load_fact_inventario)
    t_compras    = PythonOperator(task_id="load_fact_compras",    python_callable=load_fact_compras)

    # ── Auditoría ──
    t_audit = PythonOperator(task_id="registrar_auditoria", python_callable=registrar_auditoria)

    # ── Dependencias ──────────────────────────────────────────
    #
    #  validar → pais, marca, courier, proveedor
    #         → (pais done) → producto, cliente
    #         → (dims done) → ventas, inventario, compras
    #         → audit
    #
    t_validar >> [t_pais, t_marca, t_courier, t_proveedor]
    t_pais    >> [t_producto, t_cliente]

    [t_producto, t_cliente, t_marca, t_courier, t_proveedor] >> t_ventas
    [t_producto, t_proveedor] >> t_compras
    t_producto >> t_inventario

    [t_ventas, t_inventario, t_compras] >> t_audit
