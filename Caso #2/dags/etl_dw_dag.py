"""
============================================================
 ETL — Etheria Global + Dynamic Brands → Data Warehouse
 Archivo  : etl.py
 Destino  : dags/etl.py  (dentro del volumen de Airflow)
 Motor DW : PostgreSQL  (data_warehouse:5432 / warehouse)
 Fuentes  : etheria_db:5432 (PostgreSQL) · dynamic_mysql:3306 (MySQL)
 Creado   : 2026-05-01
============================================================

Ejecutar directamente (fuera de Airflow):
    python etl.py

Como DAG de Airflow usa el PythonOperator y corre cada tarea
en secuencia respetando las dependencias de claves foráneas.

Orden de carga garantizado:
  1. dim_pais
  2. dim_proveedor
  3. dim_marca
  4. dim_courier
  5. dim_cliente
  6. dim_producto    (SCD Tipo 2)
  7. fact_compras
  8. fact_inventario
  9. fact_ventas
"""

from __future__ import annotations

import logging
from datetime import datetime, date, timedelta
from decimal import Decimal

import pandas as pd
from sqlalchemy import create_engine, text

# ─────────────────────────────────────────────────────────────
#  LOGGING
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────
#  CONEXIONES
#  Los hostnames son los nombres de servicio de Docker Compose.
#  Si ejecutas fuera de Docker cambia a 127.0.0.1 y los puertos
#  mapeados en el compose (5433, 3307, 6001).
# ─────────────────────────────────────────────────────────────
ETHERIA_URL = (
    "postgresql+psycopg2://etheria:etheria123@etheria_db:5432/etheria_global_db"
)
DYNAMIC_URL = (
    "mysql+mysqlconnector://dynamic:brands123@dynamic_mysql:3306/dynamic_brands_db"
    "?charset=utf8mb4"
)
DWH_URL = (
    "postgresql+psycopg2://analytics_user:dwh_password@data_warehouse:5432/warehouse"
)

# ─────────────────────────────────────────────────────────────
#  ENGINES (lazy — se crean una vez)
# ─────────────────────────────────────────────────────────────
_engines: dict = {}


def get_engine(name: str):
    if name not in _engines:
        url_map = {
            "etheria": ETHERIA_URL,
            "dynamic": DYNAMIC_URL,
            "dwh": DWH_URL,
        }
        _engines[name] = create_engine(url_map[name], pool_pre_ping=True)
    return _engines[name]


# ─────────────────────────────────────────────────────────────
#  HELPERS GENERALES
# ─────────────────────────────────────────────────────────────

def read_sql(query: str, engine_name: str, params: dict | None = None) -> pd.DataFrame:
    """Lee una query y devuelve un DataFrame."""
    with get_engine(engine_name).connect() as conn:
        return pd.read_sql(text(query), conn, params=params)


def exec_dwh(statement: str, params: dict | None = None) -> None:
    """Ejecuta un statement en el DWH dentro de una transacción."""
    with get_engine("dwh").begin() as conn:
        conn.execute(text(statement), params or {})


def get_fecha_sk(target_date: date | None) -> int:
    """Devuelve el fecha_sk del DWH para una fecha dada. -1 si None."""
    if target_date is None:
        return -1
    df = read_sql(
        "SELECT fecha_sk FROM dw.dim_fecha WHERE fecha = :d",
        "dwh",
        {"d": target_date},
    )
    return int(df["fecha_sk"].iloc[0]) if not df.empty else -1


# ─────────────────────────────────────────────────────────────
#  AUDIT LOG
# ─────────────────────────────────────────────────────────────

def audit_start(dag_name: str, task_name: str) -> int:
    """Abre un registro de auditoría y devuelve el log_id."""
    with get_engine("dwh").begin() as conn:
        result = conn.execute(
            text(
                """
                INSERT INTO etl.audit_log (dag_name, task_name, run_start, status)
                VALUES (:dag, :task, :now, 'RUNNING')
                RETURNING log_id
                """
            ),
            {"dag": dag_name, "task": task_name, "now": datetime.utcnow()},
        )
        return result.scalar()


def audit_end(
    log_id: int,
    status: str,
    rows_extracted: int = 0,
    rows_inserted: int = 0,
    rows_updated: int = 0,
    rows_rejected: int = 0,
    error_message: str | None = None,
) -> None:
    """Cierra un registro de auditoría."""
    now = datetime.utcnow()
    with get_engine("dwh").begin() as conn:
        conn.execute(
            text(
                """
                UPDATE etl.audit_log
                   SET run_end       = :now,
                       duration_secs = EXTRACT(EPOCH FROM (:now - run_start))::INTEGER,
                       status        = :status,
                       rows_extracted = :extracted,
                       rows_inserted  = :inserted,
                       rows_updated   = :updated,
                       rows_rejected  = :rejected,
                       error_message  = :error
                 WHERE log_id = :log_id
                """
            ),
            {
                "now": now,
                "status": status,
                "extracted": rows_extracted,
                "inserted": rows_inserted,
                "updated": rows_updated,
                "rejected": rows_rejected,
                "error": error_message,
                "log_id": log_id,
            },
        )


# ─────────────────────────────────────────────────────────────
#  TAREA 1 — dim_pais
#  Fuente: Etheria.Countries (fuente maestra de países)
# ─────────────────────────────────────────────────────────────

def load_dim_pais() -> None:
    log_id = audit_start("etl_holding", "load_dim_pais")
    inserted = updated = rejected = 0
    try:
        df = read_sql(
            """
            SELECT "isocode" AS iso_code, "countryname" AS country_name
              FROM "countries"
             WHERE "isdeleted" = FALSE
            """,
            "etheria",
        )
        log.info("dim_pais: %d países extraídos de Etheria.", len(df))

        for _, row in df.iterrows():
            try:
                with get_engine("dwh").begin() as conn:
                    result = conn.execute(
                        text(
                            """
                            INSERT INTO dw.dim_pais (iso_code, country_name)
                            VALUES (:iso, :name)
                            ON CONFLICT (iso_code) DO UPDATE
                               SET country_name  = EXCLUDED.country_name,
                                   etl_loaded_at = CURRENT_TIMESTAMP
                            RETURNING (xmax = 0) AS was_inserted
                            """
                        ),
                        {"iso": row["iso_code"], "name": row["country_name"]},
                    )
                    was_inserted = result.scalar()
                    if was_inserted:
                        inserted += 1
                    else:
                        updated += 1
            except Exception as e:
                log.warning("dim_pais: error en %s — %s", row["iso_code"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(df), inserted, updated, rejected)
        log.info("dim_pais OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_pais FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 2 — dim_proveedor
#  Fuente: Etheria.Suppliers + Countries
# ─────────────────────────────────────────────────────────────

def load_dim_proveedor() -> None:
    log_id = audit_start("etl_holding", "load_dim_proveedor")
    inserted = updated = rejected = 0
    try:
        df = read_sql(
            """
            SELECT s."supplierid"   AS etheria_supplier_id,
                   s."suppliername" AS supplier_name,
                   c."isocode"      AS iso_code,
                   s."isactive"     AS is_active
              FROM "suppliers" s
              JOIN "countries" c ON c."countryid" = s."countryid"
             WHERE s."isdeleted" = FALSE
            """,
            "etheria",
        )
        log.info("dim_proveedor: %d proveedores extraídos.", len(df))

        paises = read_sql("SELECT pais_sk, iso_code FROM dw.dim_pais", "dwh")
        pais_map = dict(zip(paises["iso_code"], paises["pais_sk"]))

        for _, row in df.iterrows():
            try:
                pais_sk = pais_map.get(row["iso_code"], -1)
                with get_engine("dwh").begin() as conn:
                    result = conn.execute(
                        text(
                            """
                            INSERT INTO dw.dim_proveedor
                                (etheria_supplier_id, supplier_name, pais_sk, is_active)
                            VALUES (:sid, :name, :psk, :active)
                            ON CONFLICT (etheria_supplier_id) DO UPDATE
                               SET supplier_name  = EXCLUDED.supplier_name,
                                   pais_sk        = EXCLUDED.pais_sk,
                                   is_active      = EXCLUDED.is_active,
                                   etl_loaded_at  = CURRENT_TIMESTAMP
                            RETURNING (xmax = 0) AS was_inserted
                            """
                        ),
                        {
                            "sid": int(row["etheria_supplier_id"]),
                            "name": row["supplier_name"],
                            "psk": pais_sk,
                            "active": bool(row["is_active"]),
                        },
                    )
                    if result.scalar():
                        inserted += 1
                    else:
                        updated += 1
            except Exception as e:
                log.warning("dim_proveedor: error en supplierId=%s — %s", row["etheria_supplier_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(df), inserted, updated, rejected)
        log.info("dim_proveedor OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_proveedor FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 3 — dim_marca
#  Fuente: Dynamic.Brands
# ─────────────────────────────────────────────────────────────

def load_dim_marca() -> None:
    log_id = audit_start("etl_holding", "load_dim_marca")
    inserted = updated = rejected = 0
    try:
        df = read_sql(
            """
            SELECT brandId AS dynamic_brand_id,
                   brandName AS brand_name,
                   brandFocus AS brand_focus
              FROM Brands
             WHERE isDeleted = 0
            """,
            "dynamic",
        )
        log.info("dim_marca: %d marcas extraídas.", len(df))

        for _, row in df.iterrows():
            try:
                with get_engine("dwh").begin() as conn:
                    result = conn.execute(
                        text(
                            """
                            INSERT INTO dw.dim_marca (dynamic_brand_id, brand_name, brand_focus)
                            VALUES (:bid, :name, :focus)
                            ON CONFLICT (dynamic_brand_id) DO UPDATE
                               SET brand_name    = EXCLUDED.brand_name,
                                   brand_focus   = EXCLUDED.brand_focus,
                                   etl_loaded_at = CURRENT_TIMESTAMP
                            RETURNING (xmax = 0) AS was_inserted
                            """
                        ),
                        {
                            "bid": int(row["dynamic_brand_id"]),
                            "name": row["brand_name"],
                            "focus": row["brand_focus"],
                        },
                    )
                    if result.scalar():
                        inserted += 1
                    else:
                        updated += 1
            except Exception as e:
                log.warning("dim_marca: error brandId=%s — %s", row["dynamic_brand_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(df), inserted, updated, rejected)
        log.info("dim_marca OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_marca FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 4 — dim_courier
#  Fuente: Dynamic.Couriers
# ─────────────────────────────────────────────────────────────

def load_dim_courier() -> None:
    log_id = audit_start("etl_holding", "load_dim_courier")
    inserted = updated = rejected = 0
    try:
        df = read_sql(
            """
            SELECT courierId   AS dynamic_courier_id,
                   courierName AS courier_name,
                   isActive    AS is_active
              FROM Couriers
             WHERE isDeleted = 0
            """,
            "dynamic",
        )
        log.info("dim_courier: %d couriers extraídos.", len(df))

        for _, row in df.iterrows():
            try:
                with get_engine("dwh").begin() as conn:
                    result = conn.execute(
                        text(
                            """
                            INSERT INTO dw.dim_courier (dynamic_courier_id, courier_name, is_active)
                            VALUES (:cid, :name, :active)
                            ON CONFLICT (dynamic_courier_id) DO UPDATE
                               SET courier_name  = EXCLUDED.courier_name,
                                   is_active     = EXCLUDED.is_active,
                                   etl_loaded_at = CURRENT_TIMESTAMP
                            RETURNING (xmax = 0) AS was_inserted
                            """
                        ),
                        {
                            "cid": int(row["dynamic_courier_id"]),
                            "name": row["courier_name"],
                            "active": bool(row["is_active"]),
                        },
                    )
                    if result.scalar():
                        inserted += 1
                    else:
                        updated += 1
            except Exception as e:
                log.warning("dim_courier: error courierId=%s — %s", row["dynamic_courier_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(df), inserted, updated, rejected)
        log.info("dim_courier OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_courier FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 5 — dim_cliente  (SCD Tipo 2)
#  Fuente: Dynamic.Customers + Countries
#  Lógica SCD2:
#    - Si el cliente no existe → INSERT nuevo registro current
#    - Si existe pero cambió email o nombre → cierra el anterior
#      (valid_to = hoy - 1) e inserta uno nuevo
#    - Si no cambió → no hace nada
# ─────────────────────────────────────────────────────────────

def load_dim_cliente() -> None:
    log_id = audit_start("etl_holding", "load_dim_cliente")
    inserted = updated = rejected = 0
    today = date.today()
    yesterday = today - timedelta(days=1)

    try:
        src = read_sql(
            """
            SELECT c.customerId                            AS dynamic_cust_id,
                   CONCAT(c.firstName,' ',c.lastName)     AS full_name,
                   c.email,
                   co.isoCode                             AS iso_code
              FROM Customers c
              JOIN Countries co ON co.countryId = c.countryId
             WHERE c.isDeleted = 0
            """,
            "dynamic",
        )
        log.info("dim_cliente: %d clientes extraídos.", len(src))

        paises = read_sql("SELECT pais_sk, iso_code FROM dw.dim_pais", "dwh")
        pais_map = dict(zip(paises["iso_code"], paises["pais_sk"]))

        existing = read_sql(
            """
            SELECT dynamic_cust_id, full_name, email, pais_sk
              FROM dw.dim_cliente
             WHERE is_current = TRUE AND dynamic_cust_id > 0
            """,
            "dwh",
        )
        exist_map = {
            int(r["dynamic_cust_id"]): r
            for _, r in existing.iterrows()
        }

        for _, row in src.iterrows():
            try:
                cid = int(row["dynamic_cust_id"])
                pais_sk = pais_map.get(row["iso_code"], -1)
                full_name = row["full_name"]
                email = row.get("email") or ""

                if cid not in exist_map:
                    # Nuevo cliente
                    with get_engine("dwh").begin() as conn:
                        conn.execute(
                            text(
                                """
                                INSERT INTO dw.dim_cliente
                                    (dynamic_cust_id, full_name, email, pais_sk,
                                     valid_from, is_current)
                                VALUES (:cid, :fn, :em, :psk, :today, TRUE)
                                """
                            ),
                            {"cid": cid, "fn": full_name, "em": email,
                             "psk": pais_sk, "today": today},
                        )
                    inserted += 1
                else:
                    prev = exist_map[cid]
                    changed = (
                        prev["full_name"] != full_name
                        or str(prev["email"] or "") != str(email)
                        or int(prev["pais_sk"]) != pais_sk
                    )
                    if changed:
                        # SCD2: cerrar registro anterior e insertar nuevo
                        with get_engine("dwh").begin() as conn:
                            conn.execute(
                                text(
                                    """
                                    UPDATE dw.dim_cliente
                                       SET valid_to   = :yesterday,
                                           is_current = FALSE
                                     WHERE dynamic_cust_id = :cid AND is_current = TRUE
                                    """
                                ),
                                {"yesterday": yesterday, "cid": cid},
                            )
                            conn.execute(
                                text(
                                    """
                                    INSERT INTO dw.dim_cliente
                                        (dynamic_cust_id, full_name, email, pais_sk,
                                         valid_from, is_current)
                                    VALUES (:cid, :fn, :em, :psk, :today, TRUE)
                                    """
                                ),
                                {"cid": cid, "fn": full_name, "em": email,
                                 "psk": pais_sk, "today": today},
                            )
                        updated += 1
            except Exception as e:
                log.warning("dim_cliente: error customerId=%s — %s", row["dynamic_cust_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(src), inserted, updated, rejected)
        log.info("dim_cliente OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_cliente FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 6 — dim_producto  (SCD Tipo 2)
#  Fuente: Etheria.Products + ProductCategories + MeasurementUnits
#          + ProductPrices (precio vigente hoy)
#          + Dynamic.ProductCatalog (branded_name, category_label)
#
#  Clave natural : etheria_product_id
#  Campos SCD2   : product_name, category_name, base_unit,
#                  unit_weight_kg, unit_volume_m3, branded_name,
#                  category_label, sale_price_usd
# ─────────────────────────────────────────────────────────────

def load_dim_producto() -> None:
    log_id = audit_start("etl_holding", "load_dim_producto")
    inserted = updated = rejected = 0
    today = date.today()
    yesterday = today - timedelta(days=1)

    try:
        # --- Lado Etheria ---
        etheria_df = read_sql(
            """
            SELECT p."productid"                    AS etheria_product_id,
                   p."productname"                  AS product_name,
                   pc."categoryname"                AS category_name,
                   mu."unitname"                    AS base_unit,
                   p."unitweightkg"                 AS unit_weight_kg,
                   p."unitvolumem3"                 AS unit_volume_m3,
                   pp."salepriceusd"                AS sale_price_usd
              FROM "products" p
              JOIN "productcategories" pc ON pc."categoryid" = p."categoryid"
              JOIN "measurementunits"  mu ON mu."unitid"     = p."baseunitid"
              LEFT JOIN LATERAL (
                  SELECT "salepriceusd"
                    FROM "productprices" pp2
                   WHERE pp2."productid" = p."productid"
                     AND pp2."validfrom" <= CURRENT_DATE
                     AND (pp2."validto"  IS NULL OR pp2."validto" >= CURRENT_DATE)
                   ORDER BY pp2."validfrom" DESC
                   LIMIT 1
              ) pp ON TRUE
             WHERE p."isdeleted" = FALSE
            """,
            "etheria",
        )

        # --- Lado Dynamic: nombre de marca para cada etheriaProductId ---
        dynamic_df = read_sql(
            """
            SELECT etheriaProductId AS etheria_product_id,
                   MIN(brandedName)    AS branded_name,
                   MIN(categoryLabel)  AS category_label
              FROM ProductCatalog
             WHERE isDeleted = 0
             GROUP BY etheriaProductId
            """,
            "dynamic",
        )

        src = etheria_df.merge(dynamic_df, on="etheria_product_id", how="left")
        log.info("dim_producto: %d productos extraídos.", len(src))

        # --- Registros actuales en DWH ---
        existing = read_sql(
            """
            SELECT producto_sk, etheria_product_id,
                   product_name, category_name, base_unit,
                   unit_weight_kg, unit_volume_m3,
                   branded_name, category_label, sale_price_usd
              FROM dw.dim_producto
             WHERE is_current = TRUE AND etheria_product_id > 0
            """,
            "dwh",
        )
        exist_map = {
            int(r["etheria_product_id"]): r
            for _, r in existing.iterrows()
        }

        def _changed(prev, row) -> bool:
            """Compara campos SCD2."""
            fields = [
                ("product_name", str),
                ("category_name", str),
                ("base_unit", str),
                ("branded_name", str),
                ("category_label", str),
            ]
            for field, cast in fields:
                if str(prev.get(field) or "") != str(row.get(field) or ""):
                    return True
            # Decimales
            for field in ("unit_weight_kg", "unit_volume_m3", "sale_price_usd"):
                p = Decimal(str(prev.get(field) or 0))
                n = Decimal(str(row.get(field) or 0))
                if abs(p - n) > Decimal("0.0001"):
                    return True
            return False

        for _, row in src.iterrows():
            try:
                pid = int(row["etheria_product_id"])

                if pid not in exist_map:
                    with get_engine("dwh").begin() as conn:
                        conn.execute(
                            text(
                                """
                                INSERT INTO dw.dim_producto (
                                    etheria_product_id, product_name, category_name,
                                    base_unit, unit_weight_kg, unit_volume_m3,
                                    branded_name, category_label, sale_price_usd,
                                    valid_from, is_current
                                ) VALUES (
                                    :pid, :pname, :cat, :unit, :wkg, :vm3,
                                    :bname, :clabel, :price, :today, TRUE
                                )
                                """
                            ),
                            {
                                "pid": pid,
                                "pname": row["product_name"],
                                "cat": row.get("category_name"),
                                "unit": row.get("base_unit"),
                                "wkg": row.get("unit_weight_kg"),
                                "vm3": row.get("unit_volume_m3"),
                                "bname": row.get("branded_name"),
                                "clabel": row.get("category_label"),
                                "price": row.get("sale_price_usd"),
                                "today": today,
                            },
                        )
                    inserted += 1
                elif _changed(exist_map[pid], row):
                    with get_engine("dwh").begin() as conn:
                        conn.execute(
                            text(
                                """
                                UPDATE dw.dim_producto
                                   SET valid_to   = :yesterday, is_current = FALSE
                                 WHERE etheria_product_id = :pid AND is_current = TRUE
                                """
                            ),
                            {"yesterday": yesterday, "pid": pid},
                        )
                        conn.execute(
                            text(
                                """
                                INSERT INTO dw.dim_producto (
                                    etheria_product_id, product_name, category_name,
                                    base_unit, unit_weight_kg, unit_volume_m3,
                                    branded_name, category_label, sale_price_usd,
                                    valid_from, is_current
                                ) VALUES (
                                    :pid, :pname, :cat, :unit, :wkg, :vm3,
                                    :bname, :clabel, :price, :today, TRUE
                                )
                                """
                            ),
                            {
                                "pid": pid,
                                "pname": row["product_name"],
                                "cat": row.get("category_name"),
                                "unit": row.get("base_unit"),
                                "wkg": row.get("unit_weight_kg"),
                                "vm3": row.get("unit_volume_m3"),
                                "bname": row.get("branded_name"),
                                "clabel": row.get("category_label"),
                                "price": row.get("sale_price_usd"),
                                "today": today,
                            },
                        )
                    updated += 1
            except Exception as e:
                log.warning("dim_producto: error productId=%s — %s", row["etheria_product_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(src), inserted, updated, rejected)
        log.info("dim_producto OK — ins:%d  upd:%d  rej:%d", inserted, updated, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("dim_producto FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 7 — fact_compras
#  Fuente: Etheria.BulkPurchases + Suppliers + Countries
#          + ImportPermits (costo de permisos agregado por bulkId)
# ─────────────────────────────────────────────────────────────

def load_fact_compras() -> None:
    log_id = audit_start("etl_holding", "load_fact_compras")
    inserted = rejected = 0

    try:
        src = read_sql(
            """
            SELECT bp."bulkid"          AS etheria_bulk_id,
                   bp."productid"       AS etheria_product_id,
                   bp."supplierid"      AS etheria_supplier_id,
                   oc."isocode"         AS origin_iso,
                   bp."quantitybulk"    AS quantity_bulk,
                   bp."pricebulkusd"    AS price_bulk_usd,
                   bp."importdutyusd"   AS import_duty_usd,
                   bp."freightcostusd"  AS freight_cost_usd,
                   COALESCE(ip.permit_cost, 0) AS permit_cost_usd,
                   bp."status"          AS bulk_status,
                   COALESCE(bp."arrivaldate", bp."createdat") AS ref_date
              FROM "bulkpurchases" bp
              JOIN "countries" oc ON oc."countryid" = bp."origincountryid"
              LEFT JOIN (
                  SELECT "bulkid", SUM("permitcostusd") AS permit_cost
                    FROM "importpermits"
                   WHERE "isdeleted" = FALSE
                   GROUP BY "bulkid"
              ) ip ON ip."bulkid" = bp."bulkid"
             WHERE bp."isdeleted" = FALSE
            """,
            "etheria",
        )
        log.info("fact_compras: %d compras extraídas.", len(src))

        # Mapas de claves SK
        productos = read_sql(
            "SELECT producto_sk, etheria_product_id FROM dw.dim_producto WHERE is_current = TRUE",
            "dwh",
        )
        prod_map = dict(zip(productos["etheria_product_id"].astype(int), productos["producto_sk"].astype(int)))

        proveedores = read_sql(
            "SELECT proveedor_sk, etheria_supplier_id FROM dw.dim_proveedor",
            "dwh",
        )
        prov_map = dict(zip(proveedores["etheria_supplier_id"].astype(int), proveedores["proveedor_sk"].astype(int)))

        paises = read_sql("SELECT pais_sk, iso_code FROM dw.dim_pais", "dwh")
        pais_map = dict(zip(paises["iso_code"], paises["pais_sk"].astype(int)))

        for _, row in src.iterrows():
            try:
                ref_date = row["ref_date"]
                if hasattr(ref_date, "date"):
                    ref_date = ref_date.date()

                fecha_sk     = get_fecha_sk(ref_date)
                producto_sk  = prod_map.get(int(row["etheria_product_id"]), -1)
                proveedor_sk = prov_map.get(int(row["etheria_supplier_id"]), -1)
                pais_origen_sk = pais_map.get(row["origin_iso"], -1)

                price   = float(row["price_bulk_usd"] or 0)
                duty    = float(row["import_duty_usd"] or 0)
                freight = float(row["freight_cost_usd"] or 0)
                permit  = float(row["permit_cost_usd"] or 0)
                landed  = round(price + duty + freight + permit, 2)

                with get_engine("dwh").begin() as conn:
                    conn.execute(
                        text(
                            """
                            INSERT INTO dw.fact_compras (
                                fecha_sk, producto_sk, proveedor_sk, pais_origen_sk,
                                quantity_bulk, price_bulk_usd, import_duty_usd,
                                freight_cost_usd, permit_cost_usd, total_landed_usd,
                                bulk_status, etheria_bulk_id
                            ) VALUES (
                                :fsk, :psk, :prvsk, :orsk,
                                :qty, :price, :duty,
                                :freight, :permit, :landed,
                                :status, :bulk_id
                            )
                            ON CONFLICT (etheria_bulk_id) DO NOTHING
                            """
                        ),
                        {
                            "fsk": fecha_sk,
                            "psk": producto_sk,
                            "prvsk": proveedor_sk,
                            "orsk": pais_origen_sk,
                            "qty": float(row["quantity_bulk"]),
                            "price": price,
                            "duty": duty,
                            "freight": freight,
                            "permit": permit,
                            "landed": landed,
                            "status": row["bulk_status"],
                            "bulk_id": int(row["etheria_bulk_id"]),
                        },
                    )
                inserted += 1
            except Exception as e:
                log.warning("fact_compras: error bulkId=%s — %s", row["etheria_bulk_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(src), inserted, 0, rejected)
        log.info("fact_compras OK — ins:%d  rej:%d", inserted, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("fact_compras FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 8 — fact_inventario
#  Fuente: Etheria.InventoryHub (un registro por movimiento)
# ─────────────────────────────────────────────────────────────

def load_fact_inventario() -> None:
    log_id = audit_start("etl_holding", "load_fact_inventario")
    inserted = rejected = 0

    try:
        src = read_sql(
            """
            SELECT ih."inventoryhubid"  AS etheria_hub_id,
                   ih."productid"       AS etheria_product_id,
                   ih."movementtype"    AS movement_type,
                   ih."quantity"        AS quantity,
                   ih."costperunitusd"  AS cost_per_unit_usd,
                   ih."dispatchorderid" AS etheria_dispatch_id,
                   ih."createdat"       AS created_at
              FROM "inventoryhub" ih
             WHERE ih."isdeleted" = FALSE
            """,
            "etheria",
        )
        log.info("fact_inventario: %d movimientos extraídos.", len(src))

        productos = read_sql(
            "SELECT producto_sk, etheria_product_id FROM dw.dim_producto WHERE is_current = TRUE",
            "dwh",
        )
        prod_map = dict(zip(productos["etheria_product_id"].astype(int), productos["producto_sk"].astype(int)))

        for _, row in src.iterrows():
            try:
                ref_date = row["created_at"]
                if hasattr(ref_date, "date"):
                    ref_date = ref_date.date()

                fecha_sk    = get_fecha_sk(ref_date)
                producto_sk = prod_map.get(int(row["etheria_product_id"]), -1)

                qty  = float(row["quantity"])
                cpu  = float(row["cost_per_unit_usd"])
                total = round(abs(qty) * cpu, 4)

                dispatch_id = (
                    int(row["etheria_dispatch_id"])
                    if row["etheria_dispatch_id"] is not None
                    else None
                )

                with get_engine("dwh").begin() as conn:
                    conn.execute(
                        text(
                            """
                            INSERT INTO dw.fact_inventario (
                                fecha_sk, producto_sk, movement_type,
                                quantity, cost_per_unit_usd, total_cost_usd,
                                etheria_hub_id, etheria_dispatch_id
                            ) VALUES (
                                :fsk, :psk, :mtype,
                                :qty, :cpu, :total,
                                :hub_id, :disp_id
                            )
                            ON CONFLICT (etheria_hub_id) DO NOTHING
                            """
                        ),
                        {
                            "fsk": fecha_sk,
                            "psk": producto_sk,
                            "mtype": row["movement_type"],
                            "qty": qty,
                            "cpu": cpu,
                            "total": total,
                            "hub_id": int(row["etheria_hub_id"]),
                            "disp_id": dispatch_id,
                        },
                    )
                inserted += 1
            except Exception as e:
                log.warning("fact_inventario: error hubId=%s — %s", row["etheria_hub_id"], e)
                rejected += 1

        audit_end(log_id, "SUCCESS", len(src), inserted, 0, rejected)
        log.info("fact_inventario OK — ins:%d  rej:%d", inserted, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("fact_inventario FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  TAREA 9 — fact_ventas
#  Fuente principal: Dynamic.OrderItems (granularidad 1 fila/ítem)
#
#  Joins Dynamic:
#    OrderItems → Orders → Customers → Countries (pais_sk del cliente)
#                       → Currencies → currencyCode
#                       → Websites → Brands (marca_sk)
#    OrderItems → WebsiteProducts → ProductCatalog → etheriaProductId
#    Orders     → ShippingRecords → Couriers (courier_sk, costo, estado, entregas)
#
#  Enriquecimiento desde Etheria:
#    etheriaProductId → ProductPrices (costo vigente Etheria → Dynamic)
#    → costo_etheria_usd → margen_bruto_usd = subtotal_usd − costo_etheria_usd
# ─────────────────────────────────────────────────────────────

def load_fact_ventas() -> None:
    log_id = audit_start("etl_holding", "load_fact_ventas")
    inserted = rejected = 0

    try:
        # ── 1. Extraer de Dynamic ──────────────────────────────────
        dynamic_df = read_sql(
            """
            SELECT
                oi.orderItemId        AS dynamic_order_item_id,
                oi.orderId            AS dynamic_order_id,
                oi.quantity,
                oi.unitPriceLocal     AS unit_price_local,
                oi.subtotalLocal      AS subtotal_local,
                o.orderDate           AS order_date,
                o.exchangeRateSnapshot AS exchange_rate_usd,
                o.status              AS order_status,
                o.etheriaDispatchOrderId AS etheria_dispatch_id,
                cu.currencyCode            AS currency_code,
                cust.customerId       AS dynamic_cust_id,
                co.isoCode            AS pais_iso,
                b.brandId             AS dynamic_brand_id,
                pc.etheriaProductId   AS etheria_product_id,
                -- Shipping (LEFT JOIN porque puede no existir aún)
                sr.courierId          AS courier_id,
                sr.shippingCostLocal  AS shipping_cost_local,
                sr.exchangeRateSnapshot AS ship_rate,
                sr.status             AS shipping_status,
                sr.estimatedDeliveryDate AS estimated_delivery,
                sr.actualDeliveryDate AS actual_delivery
            FROM OrderItems oi
            JOIN Orders           o   ON  o.orderId          = oi.orderId
            JOIN Customers        cust ON cust.customerId    = o.customerId
            JOIN Countries        co   ON  co.countryId      = cust.countryId
            JOIN Currencies       cu   ON  cu.currencyId     = o.currencyId
            JOIN Websites         w    ON  w.websiteId       = o.websiteId
            JOIN Brands           b    ON  b.brandId         = w.brandId
            JOIN WebsiteProducts  wp   ON  wp.websiteProductId = oi.websiteProductId
            JOIN ProductCatalog   pc   ON  pc.catalogProductId = wp.catalogProductId
            LEFT JOIN ShippingRecords sr ON sr.orderId = oi.orderId
            WHERE oi.isDeleted = 0
              AND o.isDeleted  = 0
            """,
            "dynamic",
        )
        log.info("fact_ventas: %d ítems de orden extraídos.", len(dynamic_df))

        # ── 2. Precio de costo Etheria → Dynamic (vigente hoy) ────
        etheria_prices = read_sql(
            """
            SELECT "productid"    AS etheria_product_id,
                   "salepriceusd" AS sale_price_usd
              FROM "productprices"
             WHERE "validfrom" <= CURRENT_DATE
               AND ("validto" IS NULL OR "validto" >= CURRENT_DATE)
            """,
            "etheria",
        )
        # Si hay varios precios vigentes (no debería), tomar el más reciente
        etheria_prices = (
            etheria_prices
            .sort_values("sale_price_usd", ascending=False)
            .drop_duplicates(subset="etheria_product_id")
        )
        price_map = dict(
            zip(
                etheria_prices["etheria_product_id"].astype(int),
                etheria_prices["sale_price_usd"].astype(float),
            )
        )

        # ── 3. Mapas de SK del DWH ────────────────────────────────
        productos = read_sql(
            "SELECT producto_sk, etheria_product_id FROM dw.dim_producto WHERE is_current = TRUE",
            "dwh",
        )
        prod_map = dict(zip(productos["etheria_product_id"].astype(int), productos["producto_sk"].astype(int)))

        clientes = read_sql(
            "SELECT cliente_sk, dynamic_cust_id FROM dw.dim_cliente WHERE is_current = TRUE",
            "dwh",
        )
        cust_map = dict(zip(clientes["dynamic_cust_id"].astype(int), clientes["cliente_sk"].astype(int)))

        paises = read_sql("SELECT pais_sk, iso_code FROM dw.dim_pais", "dwh")
        pais_map = dict(zip(paises["iso_code"], paises["pais_sk"].astype(int)))

        marcas = read_sql("SELECT marca_sk, dynamic_brand_id FROM dw.dim_marca", "dwh")
        marca_map = dict(zip(marcas["dynamic_brand_id"].astype(int), marcas["marca_sk"].astype(int)))

        couriers = read_sql("SELECT courier_sk, dynamic_courier_id FROM dw.dim_courier", "dwh")
        courier_map = dict(zip(couriers["dynamic_courier_id"].astype(int), couriers["courier_sk"].astype(int)))

        # ── 4. Insertar filas ──────────────────────────────────────
        for _, row in dynamic_df.iterrows():
            try:
                order_date = row["order_date"]
                if hasattr(order_date, "date"):
                    order_date = order_date.date()

                fecha_sk    = get_fecha_sk(order_date)
                pid         = int(row["etheria_product_id"]) if row["etheria_product_id"] is not None else -1
                producto_sk = prod_map.get(pid, -1)
                cliente_sk  = cust_map.get(int(row["dynamic_cust_id"]), -1)
                pais_sk     = pais_map.get(row["pais_iso"], -1)
                marca_sk    = marca_map.get(int(row["dynamic_brand_id"]), -1)
                courier_sk  = courier_map.get(int(row["courier_id"]), -1) if row["courier_id"] else None

                # Métricas monetarias
                exchange    = float(row["exchange_rate_usd"] or 1)
                subtotal_l  = float(row["subtotal_local"] or 0)
                subtotal_usd = round(subtotal_l * exchange, 4) if exchange > 0 else 0.0

                # Costo de envío en USD
                ship_cost_local = float(row["shipping_cost_local"] or 0)
                ship_rate       = float(row["ship_rate"] or exchange)
                shipping_usd    = round(ship_cost_local * ship_rate, 4)

                # Costo Etheria y margen
                costo_eth = price_map.get(pid)
                qty = int(row["quantity"])
                costo_eth_total = round(costo_eth * qty, 4) if costo_eth is not None else None
                margen = round(subtotal_usd - costo_eth_total, 4) if costo_eth_total is not None else None

                # Fechas de entrega
                est_del = row.get("estimated_delivery")
                act_del = row.get("actual_delivery")
                if hasattr(est_del, "date"):
                    est_del = est_del.date()
                if hasattr(act_del, "date"):
                    act_del = act_del.date()

                with get_engine("dwh").begin() as conn:
                    conn.execute(
                        text(
                            """
                            INSERT INTO dw.fact_ventas (
                                fecha_sk, producto_sk, cliente_sk, pais_sk,
                                marca_sk, courier_sk,
                                dynamic_order_id, dynamic_order_item_id,
                                quantity, unit_price_local, subtotal_local,
                                currency_code, exchange_rate_usd, subtotal_usd,
                                costo_etheria_usd, margen_bruto_usd,
                                shipping_cost_usd,
                                order_status, shipping_status,
                                estimated_delivery, actual_delivery
                            ) VALUES (
                                :fsk, :psk, :csk, :paisk,
                                :msk, :cousk,
                                :oid, :oiid,
                                :qty, :upl, :subl,
                                :curr, :xrate, :subusd,
                                :costeth, :margen,
                                :shipusd,
                                :ostatus, :sstatus,
                                :estdel, :actdel
                            )
                            ON CONFLICT (dynamic_order_item_id) DO NOTHING
                            """
                        ),
                        {
                            "fsk": fecha_sk,
                            "psk": producto_sk,
                            "csk": cliente_sk,
                            "paisk": pais_sk,
                            "msk": marca_sk,
                            "cousk": courier_sk,
                            "oid": int(row["dynamic_order_id"]),
                            "oiid": int(row["dynamic_order_item_id"]),
                            "qty": qty,
                            "upl": float(row["unit_price_local"]),
                            "subl": subtotal_l,
                            "curr": row["currency_code"],
                            "xrate": exchange,
                            "subusd": subtotal_usd,
                            "costeth": costo_eth_total,
                            "margen": margen,
                            "shipusd": shipping_usd,
                            "ostatus": row["order_status"],
                            "sstatus": row.get("shipping_status"),
                            "estdel": est_del,
                            "actdel": act_del,
                        },
                    )
                inserted += 1
            except Exception as e:
                log.warning(
                    "fact_ventas: error orderItemId=%s — %s",
                    row["dynamic_order_item_id"],
                    e,
                )
                rejected += 1

        audit_end(log_id, "SUCCESS", len(dynamic_df), inserted, 0, rejected)
        log.info("fact_ventas OK — ins:%d  rej:%d", inserted, rejected)
    except Exception as e:
        audit_end(log_id, "ERROR", error_message=str(e))
        log.error("fact_ventas FAILED: %s", e)
        raise


# ─────────────────────────────────────────────────────────────
#  PIPELINE COMPLETO
# ─────────────────────────────────────────────────────────────

TASKS = [
    ("dim_pais",        load_dim_pais),
    ("dim_proveedor",   load_dim_proveedor),
    ("dim_marca",       load_dim_marca),
    ("dim_courier",     load_dim_courier),
    ("dim_cliente",     load_dim_cliente),
    ("dim_producto",    load_dim_producto),
    ("fact_compras",    load_fact_compras),
    ("fact_inventario", load_fact_inventario),
    ("fact_ventas",     load_fact_ventas),
]


def run_etl() -> None:
    log.info("═" * 60)
    log.info("  ETL Holding — iniciando pipeline completo")
    log.info("═" * 60)
    start = datetime.utcnow()
    failed = []

    for name, fn in TASKS:
        log.info("── INICIO  %s", name)
        try:
            fn()
            log.info("── FIN OK  %s", name)
        except Exception as e:
            log.error("── ERROR   %s: %s", name, e)
            failed.append(name)

    elapsed = (datetime.utcnow() - start).total_seconds()
    log.info("═" * 60)
    if failed:
        log.error("Pipeline finalizado con errores en: %s  (%.1fs)", failed, elapsed)
    else:
        log.info("Pipeline finalizado correctamente  (%.1fs)", elapsed)
    log.info("═" * 60)


# ─────────────────────────────────────────────────────────────
#  AIRFLOW DAG (opcional — se activa solo cuando Airflow lo importa)
# ─────────────────────────────────────────────────────────────
try:
    from airflow import DAG
    from airflow.operators.python import PythonOperator

    with DAG(
        dag_id="etl_holding_warehouse",
        description="ETL Etheria + Dynamic Brands → Data Warehouse",
        schedule_interval="*/1 * * * *",      # Todos los días a las 03:00 UTC
        start_date=datetime(2026, 5, 1),
        catchup=False,
        tags=["etl", "holding", "warehouse"],
    ) as dag:

        def make_task(task_name: str, fn):
            return PythonOperator(
                task_id=task_name,
                python_callable=fn,
            )

        t_pais       = make_task("dim_pais",        load_dim_pais)
        t_proveedor  = make_task("dim_proveedor",   load_dim_proveedor)
        t_marca      = make_task("dim_marca",       load_dim_marca)
        t_courier    = make_task("dim_courier",     load_dim_courier)
        t_cliente    = make_task("dim_cliente",     load_dim_cliente)
        t_producto   = make_task("dim_producto",    load_dim_producto)
        t_compras    = make_task("fact_compras",    load_fact_compras)
        t_inventario = make_task("fact_inventario", load_fact_inventario)
        t_ventas     = make_task("fact_ventas",     load_fact_ventas)

        # Dependencias: dimensiones primero, luego hechos
        t_pais       >> [t_proveedor, t_cliente, t_producto]
        t_producto   >> [t_compras, t_inventario, t_ventas]
        t_proveedor  >> t_compras
        t_marca      >> t_ventas
        t_courier    >> t_ventas
        t_cliente    >> t_ventas

except ImportError:
    # Airflow no está instalado — el script corre standalone sin problema
    dag = None  # type: ignore


# ─────────────────────────────────────────────────────────────
#  ENTRY POINT STANDALONE
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    run_etl()