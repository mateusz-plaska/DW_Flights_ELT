{{ config(materialized='table', schema='core') }}

WITH distinct_times AS (
    SELECT DISTINCT
        Scheduled_Hour AS Hour,
        Scheduled_Minute AS Minute
    FROM {{ ref('stg_flights') }}
    WHERE Scheduled_Hour IS NOT NULL
      AND Scheduled_Minute IS NOT NULL
)

SELECT
    (Hour * 100) + Minute AS Time_SK,
    Hour,
    Minute,
    CASE
        WHEN Hour >= 5 AND Hour < 12 THEN 'Morning'
        WHEN Hour >= 12 AND Hour < 17 THEN 'Afternoon'
        WHEN Hour >= 17 AND Hour < 21 THEN 'Evening'
        ELSE 'Night'
    END AS Time_Category
FROM distinct_times