{{ config(materialized='table', schema='stg') }}

WITH dedup_map AS (
    SELECT MFR_RAW, MAX(MFR_CLEAN) AS MFR_CLEAN
    FROM {{ ref('mfr_mapping') }}
    GROUP BY MFR_RAW
),

dedup_raw AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY UPPER(REPLACE(registration, '-', ''))
               ORDER BY built DESC
           ) as rn
    FROM {{ source('raw_data', 'Raw_Aircraft_DB') }}
    WHERE registration IS NOT NULL
      AND UPPER(LTRIM(registration)) LIKE 'N%'
      AND UPPER(LTRIM(RTRIM(registration))) NOT IN ('NSERV', 'NGND', 'NTWR')
      AND registration NOT LIKE '%+%'
)

SELECT
    UPPER(REPLACE(db.registration, '-', '')) AS Tail_Number,

    COALESCE(
        map.MFR_CLEAN,
        UPPER(LTRIM(RTRIM(COALESCE(db.manufacturername, db.manufacturericao))))
    ) AS Manufacturer,

    UPPER(LTRIM(RTRIM(db.model))) AS Model,

    CASE
        WHEN YEAR(TRY_CAST(NULLIF(LTRIM(RTRIM(db.built)), '0001-01-01') AS DATE)) < 1900 THEN NULL
        ELSE YEAR(TRY_CAST(NULLIF(LTRIM(RTRIM(db.built)), '0001-01-01') AS DATE))
    END AS Year_Built

FROM dedup_raw AS db
LEFT JOIN dedup_map AS map
    ON COALESCE(db.manufacturername, db.manufacturericao) = map.MFR_RAW
WHERE db.rn = 1