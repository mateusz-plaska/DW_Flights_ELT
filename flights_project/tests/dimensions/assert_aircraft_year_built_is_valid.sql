SELECT Aircraft_SK, Tail_Number, Year_Built
FROM {{ ref('dim_aircraft') }}
WHERE Year_Built IS NOT NULL
  AND (Year_Built < 1900 OR Year_Built > 2024)