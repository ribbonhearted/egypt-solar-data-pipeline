#imports
import requests
import time
import logging
from config import CITIES
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from psycopg2.extras import Json
from datetime import datetime
import psycopg2
import os
from datetime import timedelta


headers = {
    'accept': 'application/json',
}

#fetch data for one city
def fetch_solar(lat, lon, start, end):
    params = {
        'start': start,
        'end': end,
        'latitude': lat,
        'longitude': lon,
        'community': 're',
        'parameters': 'ALLSKY_SFC_SW_DWN,T2M,WS10M',
        'format': 'json',
        'header': 'true',
        'time-standard': 'utc',
    }

    response = requests.get('https://power.larc.nasa.gov/api/temporal/hourly/point', params=params, headers=headers, timeout =60)

    #check status code
    response.raise_for_status()

    #create json object
    results_json = response.json()

    return results_json

def store_solar(data_interval_start=None, data_interval_end=None):
    start = data_interval_start.strftime('%Y%m%d')
    end = (data_interval_end - timedelta(days=1)).strftime('%Y%m%d')    
    # Connect to PostgreSQL container (host is service name in Docker Compose)
    conn = psycopg2.connect(
        host="postgres",
        database= os.getenv("WAREHOUSE_DB"),
        user= os.getenv("POSTGRES_USER"),
        password= os.getenv("POSTGRES_PASSWORD")
    )
    cur = conn.cursor()

    for city, coords in CITIES.items():
        try:
            # Fetch and log solar data
            solar = fetch_solar(coords['lat'],coords['lon'], start, end)
            logging.info(f"Fetched {city}: {len(solar['properties']['parameter']['ALLSKY_SFC_SW_DWN'])} hours")

            # Insert solar data into the nasa_power table
            insert_query = """
            INSERT INTO bronze.nasa_power (city, latitude, longitude, start_date, end_date,response)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (city, start_date, end_date) DO NOTHING
            """
            cur.execute(insert_query, (
                city,
                coords['lat'],
                coords['lon'],
                start,
                end,
                Json(solar)
            ))
            conn.commit()
            logging.info(f"Inserted solar for {city} successfully.")
        except Exception as e:
            conn.rollback()
            logging.error(f"Error with {city}: {e}")
            
        time.sleep(1)

    cur.close()
    conn.close()

# Define Airflow DAG
default_args = {
    "start_date": datetime(2025, 1, 1),
}

# DAG definition: runs monthly, one run per month since start_date (backfill)
with DAG(
    dag_id="ingest_nasa_power",
    schedule="@monthly",
    default_args=default_args,
    catchup=True,
    max_active_runs=1,
    template_searchpath="/opt/airflow/sql",
) as dag:
    
    store_solar_task = PythonOperator(
        task_id="store_solar",
        python_callable=store_solar
    )

    create_tables = SQLExecuteQueryOperator(
        task_id="create_tables",
        conn_id="solar_dw",
        sql=[
            "bronze/ddl_bronze.sql",
            "silver/ddl_silver.sql",
            "silver/proc_load_silver.sql",
            "gold/ddl_gold.sql",
        ],
    )

    load_silver = SQLExecuteQueryOperator(
        task_id="load_silver",
        conn_id="solar_dw",
        sql="CALL silver.load_silver();",
    )

    create_tables >> store_solar_task >> load_silver