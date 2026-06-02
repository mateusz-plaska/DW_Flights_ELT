{{ config(materialized='table', schema='stg') }}

SELECT
    CAST({{ clean_tail_number('faa.[N-NUMBER]') }} AS VARCHAR(10)) AS Tail_Number,
    CAST(COALESCE(map.MFR_CLEAN, UPPER(LTRIM(RTRIM(faa.MFR)))) AS VARCHAR(30)) AS Manufacturer,
    CAST(UPPER(LTRIM(RTRIM(faa.MODEL))) AS VARCHAR(20)) AS Model,
    CAST(faa.[TYPE-ENG] AS INT) AS Engine_Type,
    NULLIF(CAST(faa.[NO-SEATS] AS INT), 0) AS Seat_Count,
    UPPER(LTRIM(RTRIM(faa.[AC-WEIGHT]))) AS Weight_Class
FROM {{ source('raw_data', 'Raw_Aircraft_FAA') }} AS faa
LEFT JOIN {{ ref('mfr_mapping') }} AS map
    ON UPPER(LTRIM(RTRIM(faa.MFR))) = map.MFR_RAW
WHERE faa.[N-NUMBER] IS NOT NULL