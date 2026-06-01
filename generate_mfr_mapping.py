import pandas as pd
import re
import numpy as np
import time
from rapidfuzz import fuzz
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

print("Rozpoczynam generowanie GLOBALNEGO hybrydowego słownika MDM...")
start_time = time.time()

df_faa = pd.read_csv('./raw_data/FAA_AC_REGISTRATION_2021.csv', usecols=['MFR']).dropna()
faa_unique = df_faa['MFR'].dropna()

# B: Wczytanie globalnej bazy i zastosowanie logiki COALESCE (Name -> ICAO)
df_db = pd.read_csv('./raw_data/aircraftDatabase-2024-01.csv', usecols=['manufacturername', 'manufacturericao'], low_memory=False)
db_unique = df_db['manufacturername'].fillna(df_db['manufacturericao']).dropna()

# C: Połączenie obu list i wyciągnięcie unikalnych wartości dla algorytmu
all_unique_mfr = pd.concat([faa_unique, db_unique]).unique()
df_mapping = pd.DataFrame({'MFR_RAW': all_unique_mfr})
total_unique_count = len(df_mapping)
print(f"Zbudowano globalną listę do analizy: {total_unique_count} unikalnych nazw ze świata.")

# =====================================================================
# FAZA 1: GIGANCI
# =====================================================================
MAJOR_PLAYERS = [
    'BOEING', 'AIRBUS', 'EMBRAER', 'BOMBARDIER', 'MCDONNELL', 'ATR', 'SAAB',
    'CESSNA', 'PIPER', 'BEECH', 'HAWKER', 'GULFSTREAM', 'DASSAULT', 'LEARJET',
    'CIRRUS', 'MOONEY', 'GRUMMAN', 'TEXTRON', 'LOCKHEED',
    'BELL', 'ROBINSON', 'SIKORSKY', 'EUROCOPTER', 'AGUSTA'
]


def map_giant(mfr):
    mfr_upper = str(mfr).upper()
    if 'MCDONNELL' in mfr_upper or 'MDD' in mfr_upper: return 'MCDONNELL DOUGLAS'
    for player in MAJOR_PLAYERS:
        if re.search(rf'\b{player}\b', mfr_upper) or mfr_upper.startswith(player):
            if player == 'HAWKER': return 'BEECH'
            return player
    return None


df_mapping['MFR_GIANT'] = df_mapping['MFR_RAW'].apply(map_giant)

# =====================================================================
# FAZA 1.5: SŁOWA KLUCZOWE (RODZINY)
# =====================================================================
KEYWORD_FAMILIES = [
    'BABY ACE', 'VANS', 'ZENITH', 'PITTS', 'GLASAIR', 'LANCAIR',
    'RUTAN', 'SONEX', 'KITFOX', 'THORP', 'PIETENPOL', 'CUBCRAFTERS',
    'AERONCA', 'TAYLORCRAFT', 'STINSON', 'LUSCOMBE', 'CHAMPION'
]


def map_keyword(mfr):
    mfr_upper = str(mfr).upper()
    for kw in KEYWORD_FAMILIES:
        if kw in mfr_upper:
            return kw
    return None


df_mapping['MFR_KEYWORD'] = df_mapping.apply(
    lambda row: map_keyword(row['MFR_RAW']) if pd.isnull(row['MFR_GIANT']) else row['MFR_GIANT'],
    axis=1
)

df_resolved = df_mapping[df_mapping['MFR_KEYWORD'].notnull()].copy()
df_resolved['MFR_CLEAN'] = df_resolved['MFR_KEYWORD']
df_tail = df_mapping[df_mapping['MFR_KEYWORD'].isnull()].copy()

print(f"Złapano {len(df_resolved)} unikalnych wariacji za pomocą reguł twardych.")
print(f"Zostało {len(df_tail)} nazw do puszczenia przez AI...")


# =====================================================================
# FAZA 2: ALGORYTM ML DLA RESZTY
# =====================================================================
def basic_cleanup(mfr):
    mfr_upper = str(mfr).upper().strip()
    cleaned = re.sub(
        r'\b(INC|INCORPORATED|CORP|CORPORATION|CO|LLC|LTD|LIMITED|COMPANY|THE|SA|SAS|GMBH|PLC|GROUP|INDUSTRIE|INDUSTRIES|DIVISION|DIV|PHILADELPHIA)\b',
        '', mfr_upper)
    cleaned = re.sub(r'(LLC|INC|CORP)$', '', cleaned)  # Ucinanie sklejonych koncowek
    cleaned = re.sub(r'[^\w\s]', '', cleaned)
    return re.sub(r'\s+', ' ', cleaned).strip()


df_tail['MFR_BASE_CLEAN'] = df_tail['MFR_RAW'].apply(basic_cleanup)
unique_base = df_tail['MFR_BASE_CLEAN'].unique()

vectorizer = TfidfVectorizer(min_df=1, analyzer='char_wb', ngram_range=(2, 4))
tfidf_matrix = vectorizer.fit_transform(unique_base)
similarity_matrix = cosine_similarity(tfidf_matrix)

golden_mapping = {}
visited = set()
sorted_cleans = sorted(unique_base, key=lambda x: (len(x), x))

for i, target_mfr in enumerate(sorted_cleans):
    if target_mfr in visited: continue

    target_idx = np.where(unique_base == target_mfr)[0][0]
    similar_indices = np.where(similarity_matrix[target_idx] > 0.85)[0]

    cluster = []
    for idx in similar_indices:
        candidate = unique_base[idx]
        if candidate not in visited:
            if fuzz.token_sort_ratio(target_mfr, candidate) > 85:
                cluster.append(candidate)
                visited.add(candidate)

    for mfr in cluster:
        golden_mapping[mfr] = target_mfr

df_tail['MFR_CLEAN'] = df_tail['MFR_BASE_CLEAN'].map(golden_mapping).fillna(df_tail['MFR_BASE_CLEAN'])

# =====================================================================
# FAZA 3: POŁĄCZENIE I ZAPIS
# =====================================================================
df_final = pd.concat([df_resolved, df_tail])
df_final[['MFR_RAW', 'MFR_CLEAN']].to_csv('flights_project/seeds/mfr_mapping.csv', index=False)

print(
    f"Unikalnych producentów ze świata po algorytmie: {df_final['MFR_CLEAN'].nunique()} (wcześniej było {total_unique_count})")
print(f"✅ Zakończono! Całkowity czas: {round(time.time() - start_time, 2)} sek.")