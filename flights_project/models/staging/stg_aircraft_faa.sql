{{ config(materialized='table', schema='stg') }}

WITH dedup_map AS (
    SELECT MFR_RAW, MAX(MFR_CLEAN) AS MFR_CLEAN
    FROM {{ ref('mfr_mapping') }}
    GROUP BY MFR_RAW
)

SELECT
    {{ clean_tail_number('faa.[N-NUMBER]') }} AS Tail_Number,
    COALESCE(map.MFR_CLEAN, UPPER(LTRIM(RTRIM(faa.MFR)))) AS Manufacturer,
    UPPER(LTRIM(RTRIM(faa.MODEL))) AS Model,
    CAST(faa.[TYPE-ENG] AS INT) AS Engine_Type,
    NULLIF(CAST(faa.[NO-SEATS] AS INT), 0) AS Seat_Count,
    UPPER(LTRIM(RTRIM(faa.[AC-WEIGHT]))) AS Weight_Class
FROM {{ source('raw_data', 'Raw_Aircraft_FAA') }} AS faa
LEFT JOIN dedup_map AS map
    ON faa.MFR = map.MFR_RAW
WHERE faa.[N-NUMBER] IS NOT NULL