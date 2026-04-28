FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema para los drivers
RUN apt-get update && apt-get install -y libpq-dev gcc && rm -rf /var/lib/apt/lists/*

# Instalar librerías de Python
RUN pip install pandas sqlalchemy psycopg2 pymysql

# Copiar el script
COPY ETL.py .

# Comando para ejecutarlo
CMD ["python", "ETL.py"]