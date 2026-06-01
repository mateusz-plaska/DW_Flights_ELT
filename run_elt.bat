@echo off
title Orkiestracja ELT (python + dbt)

echo =======================================================
echo    Rozpoczynam pelny proces ELT
echo =======================================================
echo.

echo [1/4] Aktywacja venv...
call .venv\Scripts\activate.bat

echo.
echo [2/4] Faza EXTRACT: weryfikacja i generowanie slownikow referencyjnych...
IF NOT EXIST "flights_project\seeds\mfr_mapping.csv" (
    echo Plik mfr_mapping.csv nie istnieje. Uruchamiam algorytm...
    python generate_mfr_mapping.py
) ELSE (
    echo Plik mfr_mapping.csv juz istnieje. Pomijam generowanie.
)

echo.
echo [3/4] Faza LOAD: ladowanie surowych danych do bazy...
python load_raw_data.py

echo.
echo [4/4] Faza TRANSFORM: uruchamianie dbt...
cd flights_project
call dbt clean
call dbt build
cd ..

echo.
echo =======================================================
echo    Proces ELT zakonczony sukcesem!
echo =======================================================
pause