import os
import urllib.parse
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DB_SERVER   = os.getenv("DB_SERVER",   "localhost,1434")
DB_NAME     = os.getenv("DB_NAME",     "gathel_db")
DB_USER     = os.getenv("DB_USER",     "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Gathel123")

DATABASE_URL = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={DB_SERVER};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};"
    f"PWD={DB_PASSWORD};"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

params = urllib.parse.quote_plus(DATABASE_URL)
connection_string = f"mssql+pyodbc:///?odbc_connect={params}"

engine = create_engine(
    connection_string,
    pool_size=10,
    max_overflow=0,
    pool_timeout=30,
    pool_recycle=1800,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db_connection():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()