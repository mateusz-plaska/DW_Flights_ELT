{{ config(materialized='table', schema='core') }}

WITH source_data AS (
    SELECT
        CAST(HASHBYTES('MD5', IATA_Code) AS UNIQUEIDENTIFIER) AS Airport_SK,
        IATA_Code AS Airport_Code,
        Airport_Name,
        City,
        State,
        Country
    FROM {{ ref('stg_airports') }}
)

SELECT
    CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER) AS Airport_SK,
    'UNKNOWN' AS Airport_Code,
    'Unknown' AS Airport_Name,
    'Unknown' AS City,
    'Unknown' AS State,
    'Unknown' AS Country

UNION ALL

SELECT * FROM source_data