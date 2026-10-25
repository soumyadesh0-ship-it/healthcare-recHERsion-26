"""Local prototype inference. Exposes experimental scores, never a diagnosis.

Only load joblib files supplied by a trusted source: pickle can execute code.
"""
from pathlib import Path
import argparse, json, math
import joblib
import pandas as pd
from pcos_data import FEATURES

ROOT = Path(__file__).resolve().parent
BINARY = FEATURES[2:]

def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError('Expected a finite JSON number')
    return float(value)

def predict_quiz(answers, model_path=None):
    if not isinstance(answers, dict):
        raise ValueError('Answers must be a JSON object')
    unknown = set(answers) - set(FEATURES) - {'known_pcos_diagnosis'}
    if unknown:
        raise ValueError(f'Unexpected fields: {sorted(unknown)}')
    known = answers.get('known_pcos_diagnosis', False)
    if not isinstance(known, bool):
        raise ValueError('known_pcos_diagnosis must be true or false')
    if known:
        return {'status': 'tracking_journey', 'message': 'Use the health-history and tracking journey for an existing diagnosis.'}
    if answers.get('age') is None:
        return {'status': 'insufficient_inputs', 'missing': ['age']}
    age = number(answers['age'])
    if not 18 <= age <= 45:
        return {'status': 'outside_experimental_scope', 'message': 'This experiment was trained only on ages 18–45.'}
    missing = [name for name in BINARY if answers.get(name) is None]
    if missing:
        return {'status': 'insufficient_inputs', 'missing': missing,
                'message': 'Unknown answers are not treated as absent symptoms. No score produced.'}
    values = {'age': age}
    for name in BINARY:
        v = answers[name]
        if isinstance(v, bool):
            v = int(v)
        v = number(v)
        if v not in [0, 1]:
            raise ValueError(f'{name} must be 0, 1, true, false, or null')
        values[name] = v
    bmi = answers.get('bmi')
    if bmi is not None:
        bmi = number(bmi)
        if not 10 <= bmi <= 70:
            raise ValueError('BMI must be between 10 and 70 for this experiment')
    values['bmi'] = float('nan') if bmi is None else bmi
    if model_path is None:
        selection = json.loads((ROOT/'models/selected_model.json').read_text())
        model_path = ROOT/'models'/selection['path']
    bundle = joblib.load(model_path)
    if bundle['features'] != FEATURES:
        raise ValueError('Feature contract does not match model')
    score = float(bundle['model'].predict_proba(pd.DataFrame([values], columns=FEATURES))[0,1])
    return {'status': 'experimental_result', 'model': bundle['name'],
        'experimental_model_score': round(score, 6),
        'score_target': 'self_reported_prior_pcos_diagnosis_in_training_sample',
        'bmi_imputed': bmi is None,
        'reported_symptoms': [name for name in BINARY if name != 'regular_periods' and values[name] == 1]
                             + (['irregular_periods'] if values['regular_periods'] == 0 else []),
        'message': 'Experimental symptom summary. This score cannot diagnose or rule out PCOS and is not your clinical probability of PCOS. Discuss persistent concerns with a qualified healthcare professional.'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--model', type=Path)
    args = parser.parse_args()
    try:
        result = predict_quiz(json.loads(args.input.read_text()), args.model)
        print(json.dumps(result, indent=2, allow_nan=False))
    except (ValueError, TypeError) as e:
        parser.exit(2, f'Invalid input: {e}\n')

if __name__ == '__main__':
    main()
