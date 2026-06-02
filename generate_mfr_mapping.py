import time
import re
import pandas as pd
import numpy as np
from rapidfuzz import fuzz
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


COSINE_SIMILARITY_THRESHOLD = 0.80
FUZZY_MATCH_THRESHOLD = 80

MAJOR_MANUFACTURERS = [
    'BOEING', 'AIRBUS', 'EMBRAER', 'BOMBARDIER', 'ATR', 'SAAB',
    'CESSNA', 'PIPER', 'BEECH', 'HAWKER', 'GULFSTREAM', 'DASSAULT', 'LEARJET',
    'CIRRUS', 'MOONEY', 'GRUMMAN', 'TEXTRON', 'LOCKHEED',
    'BELL', 'ROBINSON', 'SIKORSKY', 'EUROCOPTER', 'AGUSTA'
]

AIRCRAFT_FAMILIES = [
    'BABY ACE', 'VANS', 'ZENITH', 'PITTS', 'GLASAIR', 'LANCAIR',
    'RUTAN', 'SONEX', 'KITFOX', 'THORP', 'PIETENPOL', 'CUBCRAFTERS',
    'AERONCA', 'TAYLORCRAFT', 'STINSON', 'LUSCOMBE', 'CHAMPION'
]


def extract_known_manufacturer(mfr_raw: str) -> str | None:
    if pd.isna(mfr_raw):
        return None

    mfr_upper = str(mfr_raw).upper()

    if 'MCDONNELL' in mfr_upper or 'MDD' in mfr_upper:
        return 'MCDONNELL DOUGLAS'

    for company in MAJOR_MANUFACTURERS + AIRCRAFT_FAMILIES:
        if re.search(rf'\b{company}\b', mfr_upper) or mfr_upper.startswith(company):
            return 'BEECH' if company == 'HAWKER' else company

    return None


def clean_company_suffixes(mfr_raw: str) -> str:
    if pd.isna(mfr_raw):
        return ""

    mfr_upper = str(mfr_raw).upper().strip()
    cleaned = re.sub(
        r'\b(INC|INCORPORATED|CORP|CORPORATION|CO|LLC|LTD|LIMITED|COMPANY|THE|SA|SAS|GMBH|PLC|GROUP|INDUSTRIE|INDUSTRIES|DIVISION|DIV|PHILADELPHIA)\b',
        '',
        mfr_upper
    )
    cleaned = re.sub(r'(LLC|INC|CORP)$', '', cleaned)
    cleaned = re.sub(r'[^\w\s]', '', cleaned)
    return re.sub(r'\s+', ' ', cleaned).strip()


def main():
    print("Rozpoczynam generowanie słownika producentow...")
    start_time = time.time()

    # 1. Load
    df_faa = pd.read_csv('./raw_data/FAA_AC_REGISTRATION_2021.csv', usecols=['MFR'])
    faa = df_faa['MFR'].dropna().astype(str).str.upper().str.strip()

    df_db = pd.read_csv('./raw_data/aircraftDatabase-2024-01.csv',
                        usecols=['manufacturername', 'manufacturericao'], low_memory=False)
    db = df_db['manufacturername'].fillna(df_db['manufacturericao']).dropna().astype(str).str.upper().str.strip()

    all_unique_mfr = pd.concat([faa, db]).unique()
    df_mapping = pd.DataFrame({'MFR_RAW': all_unique_mfr})

    print(f"Zbudowano globalną listę do analizy: {len(df_mapping)} unikalnych nazw.")

    # 2. Extract known manufacturers
    df_mapping['MFR_CLEAN'] = df_mapping['MFR_RAW'].apply(extract_known_manufacturer)

    df_resolved = df_mapping[df_mapping['MFR_CLEAN'].notnull()].copy()
    df_tail = df_mapping[df_mapping['MFR_CLEAN'].isnull()].copy()

    print(f"Złapano {len(df_resolved)} wariacji regułami. Zostało {len(df_tail)} nazw dla ML...")

    # 3. ML
    df_tail['MFR_BASE_CLEAN'] = df_tail['MFR_RAW'].apply(clean_company_suffixes)
    unique_base = df_tail['MFR_BASE_CLEAN'].unique()

    vectorizer = TfidfVectorizer(min_df=1, analyzer='char_wb', ngram_range=(2, 4))
    tfidf_matrix = vectorizer.fit_transform(unique_base)
    similarity_matrix = cosine_similarity(tfidf_matrix)

    golden_mapping = {}
    visited = set()
    sorted_cleans = sorted(unique_base, key=lambda x: (len(x), x))

    for i, target_mfr in enumerate(sorted_cleans):
        if target_mfr in visited:
            continue

        target_idx = np.where(unique_base == target_mfr)[0][0]
        similar_indices = np.where(similarity_matrix[target_idx] > COSINE_SIMILARITY_THRESHOLD)[0]

        cluster = []
        for idx in similar_indices:
            candidate = unique_base[idx]
            if candidate not in visited:
                if fuzz.token_sort_ratio(target_mfr, candidate) > FUZZY_MATCH_THRESHOLD:
                    cluster.append(candidate)
                    visited.add(candidate)

        for mfr in cluster:
            golden_mapping[mfr] = target_mfr

    df_tail['MFR_CLEAN'] = df_tail['MFR_BASE_CLEAN'].map(golden_mapping).fillna(df_tail['MFR_BASE_CLEAN'])
    df_tail = df_tail.drop(columns=['MFR_BASE_CLEAN'])

    # Save
    df_final = pd.concat([df_resolved, df_tail])
    df_final.to_csv('flights_project/seeds/mfr_mapping.csv', index=False)

    print(f"Unikalnych producentów po ML: {df_final['MFR_CLEAN'].nunique()}")
    print(f"-> Zakończono! Całkowity czas: {round(time.time() - start_time, 2)} sek.")


if __name__ == '__main__':
    main()