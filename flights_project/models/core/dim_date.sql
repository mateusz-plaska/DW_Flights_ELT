{{ config(materialized='table', schema='core') }}

WITH distinct_dates AS (
    SELECT DISTINCT
        Year,
        Month,
        Day,
        Day_Of_Week
    FROM {{ ref('stg_flights') }}
    WHERE Year IS NOT NULL
      AND Month IS NOT NULL
      AND Day IS NOT NULL
),

business_logic AS (
    SELECT
        CAST((Year * 10000) + (Month * 100) + Day AS INT) AS Date_SK,
        DATEFROMPARTS(Year, Month, Day) AS Full_Date,
        Year,
        Month,
        Day
    FROM distinct_dates
)

SELECT
    Date_SK,
    Year,
    DATENAME(MONTH, Full_Date) AS Month_Name,
    Day,
    DATEPART(QUARTER, Full_Date) AS Quarter,
    DATENAME(WEEKDAY, Full_Date) AS Day_Name,
    CASE
        WHEN DATEPART(WEEKDAY, Full_Date) IN (1, 7) THEN 1
        ELSE 0
    END AS Is_Weekend,
    CASE
        WHEN Month IN (12, 1, 2) THEN 'Winter'
        WHEN Month IN (3, 4, 5) THEN 'Spring'
        WHEN Month IN (6, 7, 8) THEN 'Summer'
        ELSE 'Autumn'
    END AS Season
FROM business_logic