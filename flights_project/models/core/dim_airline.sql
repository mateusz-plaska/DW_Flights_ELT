{{ config(materialized='table', schema='core') }}

WITH active_airlines AS (
    SELECT DISTINCT Airline_Code
    FROM {{ ref('stg_flights') }}
    WHERE Airline_Code IS NOT NULL
),

source_data AS (
    SELECT * FROM {{ ref('airlines') }}
    WHERE IATA_CODE IN (SELECT Airline_Code FROM active_airlines)
),

business_logic AS (
    SELECT
        CAST(HASHBYTES('MD5', IATA_CODE) AS UNIQUEIDENTIFIER) AS Airline_SK,
        IATA_CODE AS Airline_Code,
        AIRLINE AS Airline_Name,

        CASE
            WHEN AIRLINE IN ('Southwest Airlines Co.', 'JetBlue Airways', 'Spirit Air Lines', 'Frontier Airlines Inc.', 'Virgin America') THEN 'Low-Cost Carrier (LCC)'
            WHEN AIRLINE IN ('Delta Air Lines Inc.', 'American Airlines Inc.', 'United Air Lines Inc.', 'US Airways Inc.') THEN 'Legacy Carrier'
            WHEN AIRLINE IN ('Skywest Airlines Inc.', 'Atlantic Southeast Airlines', 'American Eagle Airlines Inc.') THEN 'Regional Carrier'
            WHEN AIRLINE IN ('Hawaiian Airlines Inc.', 'Alaska Airlines Inc.') THEN 'Major Carrier'
            ELSE 'Other'
        END AS Carrier_Type

    FROM source_data
)

SELECT
    CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER) AS Airline_SK,
    'UNKNOWN' AS Airline_Code,
    'Unknown' AS Airline_Name,
    'Unknown' AS Carrier_Type

UNION ALL

SELECT * FROM business_logic