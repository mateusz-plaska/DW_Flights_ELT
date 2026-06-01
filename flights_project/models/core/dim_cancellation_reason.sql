{{ config(materialized='table', schema='core') }}

WITH distinct_reasons AS (
    SELECT DISTINCT
        Cancellation_Reason_Code AS Reason_Code
    FROM {{ ref('stg_flights') }}
)

SELECT
    CAST(HASHBYTES('MD5', COALESCE(Reason_Code, 'NOT_CANCELLED')) AS UNIQUEIDENTIFIER) AS CancelReason_SK,
    Reason_Code,
    CASE
        WHEN Reason_Code = 'A' THEN 'Airline'
        WHEN Reason_Code = 'B' THEN 'Weather'
        WHEN Reason_Code = 'C' THEN 'National Air System'
        WHEN Reason_Code = 'D' THEN 'Security'
        WHEN Reason_Code IS NULL THEN 'Not Cancelled'
        ELSE 'Unknown'
    END AS Reason_Description
FROM distinct_reasons
