"""Deterministic, auditable preparation. No learned preprocessing here."""
from pathlib import Path
import hashlib
import numpy as np
import pandas as pd

FEATURES = ['age', 'bmi', 'regular_periods', 'weight_gain', 'excess_hair',
            'skin_darkening', 'hair_thinning', 'acne']
COMMON_FEATURES = [x for x in FEATURES if x != 'regular_periods']
SURVEY_FILE = 'CLEAN- PCOS SURVEY SPREADSHEET.csv'
SURVEY_COLUMNS = {
    'Age (in Years)': 'age', 'Weight (in Kg)': 'weight_kg',
    'Height (in Cm / Feet)': 'height_cm',
    'Have you gained weight recently?': 'weight_gain',
    'Do you have excessive body/facial hair growth ?': 'excess_hair',
    'Are you noticing skin darkening recently?': 'skin_darkening',
    'Do have hair loss/hair thinning/baldness ?': 'hair_thinning',
    'Do you have pimples/acne on your face/jawline ?': 'acne',
    'Are your periods regular ?': 'regular_periods',
    'Have you been diagnosed with PCOS/PCOD?': 'label',
}

def fingerprints(frame, columns):
    """Group identical predictor profiles, even when their labels disagree."""
    return frame[columns].apply(lambda r: hashlib.sha256(
        ','.join('NA' if pd.isna(v) else format(float(v), '.8g') for v in r)
        .encode()).hexdigest(), axis=1)

def prepare_survey(path):
    raw = pd.read_csv(path)
    audit = {'original_rows': len(raw), 'exact_duplicate_rows_removed': int(raw.duplicated().sum())}
    frame = raw.drop_duplicates().rename(columns=SURVEY_COLUMNS).copy()
    for col in SURVEY_COLUMNS.values():
        frame[col] = pd.to_numeric(frame[col], errors='coerce')
    valid_age = frame.age.between(18, 45)
    audit['excluded_outside_age_18_45_or_unknown'] = int((~valid_age).sum())
    frame = frame[valid_age].copy()
    valid_label = frame.label.isin([0, 1])
    audit['excluded_invalid_label'] = int((~valid_label).sum())
    frame = frame[valid_label].copy()
    # These are input-quality bounds, not PCOS diagnostic cutoffs.
    valid_size = frame.height_cm.between(120, 220) & frame.weight_kg.between(25, 250)
    frame['bmi'] = (frame.weight_kg / (frame.height_cm / 100)**2).where(valid_size)
    frame['bmi'] = frame.bmi.where(frame.bmi.between(10, 70))
    audit['bmi_set_missing_due_to_ambiguous_or_invalid_measurements'] = int(frame.bmi.isna().sum())
    audit['bmi_policy'] = 'Recompute from valid kg/cm only; ambiguous units remain missing; no guessed conversions.'
    for col in FEATURES[2:]:
        frame[col] = frame[col].where(frame[col].isin([0, 1]))
    months = pd.to_numeric(frame['After how many months do you get your periods?\n(select 1- if every month/regular)'], errors='coerce')
    audit['regularity_vs_month_interval_disagreements'] = int(
        (((months > 1) & (frame.regular_periods == 1)) |
         ((months == 1) & (frame.regular_periods == 0))).sum())
    audit['period_policy'] = 'Use direct regular-periods answer; exclude interval and bleeding-duration fields. Disagreements retained and reported.'
    frame['source_row'] = frame.index + 2
    frame['group'] = fingerprints(frame, FEATURES)
    audit['conflicting_predictor_groups_retained'] = int((frame.groupby('group').label.nunique() > 1).sum())
    audit['retained_rows'] = len(frame)
    audit['positive_labels'] = int(frame.label.sum())
    audit['negative_labels'] = int((frame.label == 0).sum())
    audit['missing_by_feature'] = frame[FEATURES].isna().sum().to_dict()
    return frame[FEATURES + ['label', 'source_row', 'group']].reset_index(drop=True), audit

def prepare_clinical(path):
    """Different-source stress test only, with no assumed menstrual-code mapping."""
    raw = pd.read_csv(path)
    raw.columns = raw.columns.str.strip()
    columns = {'Age (yrs)': 'age', 'Weight (Kg)': 'weight_kg', 'Height(Cm)': 'height_cm',
               'Weight gain(Y/N)': 'weight_gain', 'hair growth(Y/N)': 'excess_hair',
               'Skin darkening (Y/N)': 'skin_darkening', 'Hair loss(Y/N)': 'hair_thinning',
               'Pimples(Y/N)': 'acne', 'PCOS (Y/N)': 'label'}
    frame = raw.rename(columns=columns)[list(columns.values())].apply(pd.to_numeric, errors='coerce')
    frame = frame[frame.age.between(18, 45) & frame.label.isin([0, 1])].copy()
    valid = frame.height_cm.between(120, 220) & frame.weight_kg.between(25, 250)
    frame['bmi'] = (frame.weight_kg / (frame.height_cm / 100)**2).where(valid)
    frame['bmi'] = frame.bmi.where(frame.bmi.between(10, 70))
    for col in COMMON_FEATURES[2:]:
        frame[col] = frame[col].where(frame[col].isin([0, 1]))
    frame['source_row'] = frame.index + 2
    frame['group'] = fingerprints(frame, COMMON_FEATURES)
    return frame[COMMON_FEATURES + ['label', 'source_row', 'group']].reset_index(drop=True)
