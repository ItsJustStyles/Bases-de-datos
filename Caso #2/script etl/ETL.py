import pandas as pd
from sqlalchemy import create_engine

def ejecutar_etl_gerencial():
    print("🚀 Iniciando ETL para Reporte Gerencial...")

    try:
        # 1. CONEXIONES (Red interna de Docker)
        # Se usan los nombres de servicio 'db' y 'dynamic_db' definidos en el docker-compose
        engine_pg = create_engine('postgresql://etheria:etheria123@db:5432/etheria_global_db')
        engine_my = create_engine('mysql+pymysql://dynamic:brands123@dynamic_db:3306/dynamic_brands_db')

        # 2. EXTRACCIÓN DE DATOS
        print("📥 Extrayendo datos de Etheria y Dynamic Brands...")
        
        query_costos = """
        SELECT 
            b.productId, 
            c.categoryName,
            SUM(b.priceBulkUsd) / SUM(b.quantityBulk) as costo_base_usd,
            SUM(b.importDutyUsd + b.freightCostUsd) / SUM(b.quantityBulk) as gastos_importacion_usd
        FROM BulkPurchases b
        JOIN Products p ON b.productId = p.productId
        JOIN ProductCategories c ON p.categoryId = c.categoryId
        GROUP BY b.productId, c.categoryName
        """
        df_logistica = pd.read_sql(query_costos, engine_pg)

        query_ventas = """
        SELECT 
            pc.etheriaProductId,
            b.brandName,
            co.countryName as pais_venta,
            wpp.salePriceLocal,
            curr.currencyCode,
            er.rateToUsd
        FROM ProductCatalog pc
        JOIN Brands b ON pc.brandId = b.brandId
        JOIN WebsiteProducts wp ON pc.catalogProductId = wp.catalogProductId
        JOIN WebsiteProductPrices wpp ON wp.websiteProductId = wpp.websiteProductId
        JOIN Currencies curr ON wpp.currencyId = curr.currencyId
        JOIN Countries co ON curr.countryId = co.countryId
        JOIN ExchangeRates er ON curr.currencyId = er.currencyId
        WHERE er.rateDate = CURDATE() OR er.rateDate = (SELECT MAX(rateDate) FROM ExchangeRates)
        """
        df_comercial = pd.read_sql(query_ventas, engine_my)

        # 3. TRANSFORMACIÓN
        print("🔧 Transformando datos y unificando monedas...")
        
        # NORMALIZACIÓN: Forzamos todas las columnas a minúsculas para evitar KeyErrors
        # Esto soluciona el fallo de 'productId' vs 'productid' entre Postgres y MySQL
        df_logistica.columns = df_logistica.columns.str.lower()
        df_comercial.columns = df_comercial.columns.str.lower()

        # Unir bases de datos usando los nombres normalizados en minúsculas
        df_final = pd.merge(
            df_comercial, 
            df_logistica, 
            left_on='etheriaproductid', 
            right_on='productid'
        )

        # R1: Rentabilidad Real (Conversión de moneda local a USD)
        df_final['venta_usd'] = df_final['salepricelocal'] * df_final['ratetousd']
        df_final['costo_total_usd'] = df_final['costo_base_usd'] + df_final['gastos_importacion_usd']
        df_final['utilidad_neta_usd'] = df_final['venta_usd'] - df_final['costo_total_usd']

        # R2: ROI por marca (IA Effectiveness)
        df_final['roi_marca'] = (df_final['utilidad_neta_usd'] / df_final['costo_total_usd']) * 100

        # R3: Consolidación final (Selección de columnas para el reporte)
        reporte_gerencial = df_final[[
            'categoryname', 'brandname', 'pais_venta', 'currencycode', 
            'venta_usd', 'costo_total_usd', 'utilidad_neta_usd', 'roi_marca'
        ]]

        # 4. CARGA (LOAD)
        print("📥 Cargando resultados en la tabla 'reporte_gerencial_holding'...")
        # Guardamos en Postgres (Etheria) para que Metabase lo visualice directamente
        reporte_gerencial.to_sql('reporte_gerencial_holding', engine_pg, if_exists='replace', index=False)

        print("✨ Proceso completado. Datos listos en Metabase.")

    except Exception as e:
        print(f"❌ Error en el ETL: {e}")

if __name__ == "__main__":
    ejecutar_etl_gerencial()