SELECT Flight_Business_Key
FROM {{ ref('fact_flights') }}
WHERE (Arrival_Delay < 15 OR Arrival_Delay IS NULL)
  AND (
      Weather_Delay != 0
      OR Airline_Delay != 0
      OR Late_Aircraft_Delay != 0
      OR Security_Delay != 0
      OR Air_System_Delay != 0
  )