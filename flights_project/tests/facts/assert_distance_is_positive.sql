SELECT Flight_Business_Key
FROM {{ ref('fact_flights') }}
WHERE Distance <= 0 OR Distance IS NULL