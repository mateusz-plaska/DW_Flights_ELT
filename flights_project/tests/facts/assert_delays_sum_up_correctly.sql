SELECT
    Flight_Business_Key,
    Arrival_Delay,
    Weather_Delay,
    Airline_Delay,
    Late_Aircraft_Delay,
    Security_Delay,
    Air_System_Delay
FROM {{ ref('fact_flights') }}
WHERE Arrival_Delay >= 15
  AND Arrival_Delay != (Weather_Delay + Airline_Delay + Late_Aircraft_Delay + Security_Delay + Air_System_Delay)