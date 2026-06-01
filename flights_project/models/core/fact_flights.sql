{{ config(materialized='incremental', incremental_strategy='append', schema='core') }}

WITH src_flights AS (
    SELECT
        *,
        CAST((Year * 10000) + (Month * 100) + Day AS VARCHAR(8)) + '_'
            + RIGHT('00' + CAST(Scheduled_Hour AS VARCHAR), 2)
            + RIGHT('00' + CAST(Scheduled_Minute AS VARCHAR), 2) + '_'
            + Airline_Code + '_' + CAST(Flight_Number AS VARCHAR) + '_'
            + Origin_Airport_Code + '_' + Dest_Airport_Code AS Flight_Business_Key
    FROM {{ ref('stg_flights') }}
),

flights_to_load AS (
    SELECT * FROM src_flights f
    {% if is_incremental() %}
    WHERE NOT EXISTS (
        SELECT 1
        FROM {{ this }} existing_flights
        WHERE existing_flights.Flight_Business_Key = f.Flight_Business_Key
    )
    {% endif %}
),

airports AS (
    SELECT Airport_SK, Airport_Code FROM {{ ref('dim_airport') }}
),

aircrafts AS (
    SELECT Aircraft_SK, Tail_Number FROM {{ ref('dim_aircraft') }}
)

SELECT
    f.Flight_Business_Key,

    CAST((f.Year * 10000) + (f.Month * 100) + f.Day AS INT) AS Date_SK,
    CAST((f.Scheduled_Hour * 100) + f.Scheduled_Minute AS INT) AS Time_SK,

    CAST(HASHBYTES('MD5', COALESCE(f.Airline_Code, 'UNKNOWN')) AS UNIQUEIDENTIFIER) AS Airline_SK,
    COALESCE(orig.Airport_SK, CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER)) AS OriginAirport_SK,
    COALESCE(dest.Airport_SK, CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER)) AS DestAirport_SK,
    COALESCE(ac.Aircraft_SK, CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER)) AS Aircraft_SK,
    CAST(HASHBYTES('MD5', COALESCE(f.Cancellation_Reason_Code, 'NOT_CANCELLED')) AS UNIQUEIDENTIFIER) AS CancelReason_SK,
    f.Flight_Number,

    f.Distance,
    f.Air_Time,
    f.Taxi_Out,
    f.Taxi_In,
    f.Arrival_Delay,
    f.Departure_Delay,
    CASE WHEN f.Is_Cancelled = 1 OR f.Is_Diverted = 1 THEN NULL ELSE COALESCE(f.Weather_Delay, 0) END AS Weather_Delay,
    CASE WHEN f.Is_Cancelled = 1 OR f.Is_Diverted = 1 THEN NULL ELSE COALESCE(f.Airline_Delay, 0) END AS Airline_Delay,
    CASE WHEN f.Is_Cancelled = 1 OR f.Is_Diverted = 1 THEN NULL ELSE COALESCE(f.Late_Aircraft_Delay, 0) END AS Late_Aircraft_Delay,
    CASE WHEN f.Is_Cancelled = 1 OR f.Is_Diverted = 1 THEN NULL ELSE COALESCE(f.Security_Delay, 0) END AS Security_Delay,
    CASE WHEN f.Is_Cancelled = 1 OR f.Is_Diverted = 1 THEN NULL ELSE COALESCE(f.Air_System_Delay, 0) END AS Air_System_Delay,

    Is_Cancelled,
    Is_Diverted
FROM flights_to_load f
LEFT JOIN airports orig ON f.Origin_Airport_Code = orig.Airport_Code
LEFT JOIN airports dest ON f.Dest_Airport_Code = dest.Airport_Code
LEFT JOIN aircrafts ac ON f.Tail_Number = ac.Tail_Number