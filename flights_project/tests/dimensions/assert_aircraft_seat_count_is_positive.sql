SELECT Aircraft_SK, Tail_Number, Seat_Count
FROM {{ ref('dim_aircraft') }}
WHERE Seat_Count IS NOT NULL
  AND Seat_Count <= 0