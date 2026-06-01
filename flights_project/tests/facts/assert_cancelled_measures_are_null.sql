SELECT Flight_Business_Key
FROM {{ ref('fact_flights') }}
WHERE Is_Cancelled = 1
  AND (
      Taxi_Out IS NOT NULL
      OR Taxi_In IS NOT NULL
      OR Arrival_Delay IS NOT NULL
      OR Departure_Delay IS NOT NULL
      OR Weather_Delay IS NOT NULL
      OR Airline_Delay IS NOT NULL
      OR Late_Aircraft_Delay IS NOT NULL
      OR Security_Delay IS NOT NULL
      OR Air_System_Delay IS NOT NULL
  )