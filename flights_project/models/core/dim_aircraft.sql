{{ config(materialized='table', schema='core') }}

WITH faa AS (
    SELECT * FROM {{ ref('stg_aircraft_faa') }}
),

db AS (
    SELECT * FROM {{ ref('stg_aircraft_db') }}
),

active_aircrafts AS (
    SELECT DISTINCT Tail_Number
    FROM {{ ref('stg_flights') }}
    WHERE Tail_Number IS NOT NULL
),

merged_data AS (
    SELECT
        COALESCE(faa.Tail_Number, db.Tail_Number) AS Tail_Number,
        COALESCE(faa.Manufacturer, db.Manufacturer, 'Unknown') AS Manufacturer,
        COALESCE(faa.Model, db.Model, 'Unknown') AS Model,
        faa.Engine_Type AS Raw_Engine_Type,
        COALESCE(faa.Weight_Class, 'Unknown') AS Raw_Weight_Class,
        db.Year_Built AS Year_Built,
        faa.Seat_Count AS Seat_Count
    FROM faa
    FULL OUTER JOIN db
        ON faa.Tail_Number = db.Tail_Number
    WHERE COALESCE(faa.Tail_Number, db.Tail_Number) IN (SELECT Tail_Number FROM active_aircrafts)
),

business_logic AS (
    SELECT
        CAST(HASHBYTES('MD5', Tail_Number) AS UNIQUEIDENTIFIER) AS Aircraft_SK,
        Tail_Number,
        Manufacturer,
        Model,
        Year_Built,
        Seat_Count,
        CASE
            WHEN Raw_Engine_Type = 0 THEN 'None'
            WHEN Raw_Engine_Type = 1 THEN 'Reciprocating'
            WHEN Raw_Engine_Type = 2 THEN 'Turbo-prop'
            WHEN Raw_Engine_Type = 3 THEN 'Turbo-shaft'
            WHEN Raw_Engine_Type = 4 THEN 'Turbo-jet'
            WHEN Raw_Engine_Type = 5 THEN 'Turbo-fan'
            WHEN Raw_Engine_Type = 6 THEN 'Ramjet'
            WHEN Raw_Engine_Type = 7 THEN '2 Cycle'
            WHEN Raw_Engine_Type = 8 THEN '4 Cycle'
            WHEN Raw_Engine_Type = 10 THEN 'Electric'
            WHEN Raw_Engine_Type = 11 THEN 'Rotary'
            ELSE 'Unknown'
        END AS Engine_Type,

        CASE
            WHEN Raw_Weight_Class = 'CLASS 1' THEN 'Up to 12,499 lbs'
            WHEN Raw_Weight_Class = 'CLASS 2' THEN '12,500 - 19,999 lbs'
            WHEN Raw_Weight_Class = 'CLASS 3' THEN '20,000+ lbs'
            WHEN Raw_Weight_Class = 'CLASS 4' THEN 'UAV up to 55 lbs'
            ELSE 'Unknown'
        END AS Weight_Class,

        CASE
            WHEN Year_Built IS NULL THEN 'Unknown'
            WHEN Year_Built < 1970 THEN 'Old (Pre-1970)'
            WHEN Year_Built <= 1999 THEN 'Legacy (1970-1999)'
            WHEN Year_Built <= 2015 THEN 'Modern (2000-2015)'
            ELSE 'Next-Gen (2016+)'
        END AS Year_Built_Category,

        CASE
            WHEN Seat_Count IS NULL OR Seat_Count = 0 THEN 'Unknown'
            WHEN Seat_Count <= 3 THEN 'Ultra Light (1-3 seats)'
            WHEN Seat_Count <= 20 THEN 'Light (4-20 seats)'
            WHEN Seat_Count <= 100 THEN 'Regional (21-100 seats)'
            WHEN Seat_Count <= 250 THEN 'Narrowbody (100-250 seats)'
            WHEN Seat_Count <= 400 THEN 'Widebody (250-400 seats)'
            ELSE 'Jumbo Jet (400+ seats)'
        END AS Seat_Count_Category

    FROM merged_data
)

SELECT
    CAST(HASHBYTES('MD5', 'UNKNOWN') AS UNIQUEIDENTIFIER) AS Aircraft_SK,
    'UNKNOWN' AS Tail_Number,
    'Unknown' AS Manufacturer,
    'Unknown' AS Model,
    NULL AS Year_Built,
    NULL AS Seat_Count,
    'Unknown' AS Engine_Type,
    'Unknown' AS Weight_Class,
    'Unknown' AS Year_Built_Category,
    'Unknown' AS Seat_Count_Category

UNION ALL

SELECT * FROM business_logic