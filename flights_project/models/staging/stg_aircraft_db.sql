{{ config(materialized='table', schema='stg') }}

WITH dedup_raw AS (
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
    CAST(UPPER(REPLACE(db.registration, '-', '')) AS VARCHAR(10)) AS Tail_Number,

    CAST(COALESCE(
        map.MFR_CLEAN,
        UPPER(LTRIM(RTRIM(COALESCE(db.manufacturername, db.manufacturericao))))
    ) AS VARCHAR(30)) AS Manufacturer,

    CAST(UPPER(LTRIM(RTRIM(db.model))) AS VARCHAR(20)) AS Model,

    CASE
        WHEN YEAR(TRY_CAST(NULLIF(LTRIM(RTRIM(db.built)), '0001-01-01') AS DATE)) < 1900 THEN NULL
        ELSE YEAR(TRY_CAST(NULLIF(LTRIM(RTRIM(db.built)), '0001-01-01') AS DATE))
    END AS Year_Built

FROM dedup_raw AS db
LEFT JOIN {{ ref('mfr_mapping') }} AS map
    ON UPPER(LTRIM(RTRIM(COALESCE(db.manufacturername, db.manufacturericao)))) = map.MFR_RAW
WHERE db.rn = 1