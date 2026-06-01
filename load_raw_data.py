import pandas as pd
from sqlalchemy import create_engine, text
import time

SERVER = 'DESKTOP-UNHFKQ2'
PORT = '1433'
DATABASE = 'Flights_DW'
DRIVER = 'ODBC Driver 17 for SQL Server'

conn_str = f"mssql+pyodbc://@{SERVER}:{PORT}/{DATABASE}?driver={DRIVER.replace(' ', '+')}"
engine = create_engine(conn_str, fast_executemany=True)


def load_large_csv(file_path, table_name, columns_to_keep, schema='stg', chunksize=150000):
    print(f"Loading {file_path} into table {schema}.{table_name}...")
    start_time = time.time()

    with engine.begin() as conn:
        conn.execute(text(f"IF SCHEMA_ID('{schema}') IS NULL EXEC('CREATE SCHEMA [{schema}]')"))

    chunk_iter = pd.read_csv(file_path, chunksize=chunksize, low_memory=False, usecols=columns_to_keep)

    for i, chunk in enumerate(chunk_iter):
        mode = 'replace' if i == 0 else 'append'
        chunk.to_sql(name=table_name, con=engine, schema=schema, if_exists=mode, index=False)
        print(f"  -> Loaded chunk {i + 1} ({len(chunk)} rows)")

    print(f"Successfully loaded {table_name}. Operation time: {round(time.time() - start_time, 2)} seconds\n")


if __name__ == '__main__':
    airport_columns = ['IATA_CODE', 'AIRPORT', 'CITY', 'STATE', 'COUNTRY']
    faa_aircraft_columns = ['N-NUMBER', 'MFR', 'MODEL', 'TYPE-ENG', 'AC-WEIGHT', 'NO-SEATS']
    db_aircraft_columns = ['registration', 'manufacturericao', 'manufacturername', 'model', 'built']
    flight_columns = [
        'YEAR', 'MONTH', 'DAY', 'DAY_OF_WEEK', 'AIRLINE', 'FLIGHT_NUMBER', 'TAIL_NUMBER', 'ORIGIN_AIRPORT',
        'DESTINATION_AIRPORT', 'SCHEDULED_DEPARTURE', 'DEPARTURE_DELAY', 'TAXI_OUT', 'AIR_TIME', 'DISTANCE',
        'TAXI_IN', 'ARRIVAL_DELAY', 'DIVERTED', 'CANCELLED', 'CANCELLATION_REASON', 'AIR_SYSTEM_DELAY',
        'SECURITY_DELAY', 'AIRLINE_DELAY', 'LATE_AIRCRAFT_DELAY', 'WEATHER_DELAY'
    ]

    load_large_csv('./raw_data/airports.csv', 'Raw_Airports', airport_columns)
    load_large_csv('./raw_data/FAA_AC_REGISTRATION_2021.csv', 'Raw_Aircraft_FAA', faa_aircraft_columns)
    load_large_csv('./raw_data/aircraftDatabase-2024-01.csv', 'Raw_Aircraft_DB', db_aircraft_columns)

    load_large_csv('./raw_data/flights.csv', 'Raw_Flights', flight_columns)