from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def saludo():
    print("¡Hola Justin, el entorno de Airflow está listo!")

with DAG(
    dag_id='prueba_tecnica_tec',
    start_date=datetime(2024, 5, 1),
    schedule_interval='@once',
    catchup=False
) as dag:

    tarea_test = PythonOperator(
        task_id='saludar_en_consola',
        python_callable=saludo
    )