"""Run: python -m unittest -v. These are integrity tests, not clinical validation."""
import json, tempfile, unittest
from pathlib import Path
import numpy as np
import pandas as pd
import joblib
from pcos_data import FEATURES, SURVEY_FILE, prepare_survey, fingerprints
from predict import predict_quiz

ROOT = Path(__file__).resolve().parent

class DataAndInferenceTests(unittest.TestCase):
    def setUp(self):
        self.answers = json.loads((ROOT/'examples/quiz_answers.json').read_text())

    def test_source_has_not_changed(self):
        import hashlib
        audit = json.loads((ROOT/'outputs/data_audit.json').read_text())
        for name, digest in audit['raw_file_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/'data/raw'/name).read_bytes()).hexdigest(), digest)

    def test_split_integrity(self):
        manifest = pd.read_csv(ROOT/'outputs/split_manifest.csv')
        dev = set(manifest.loc[manifest.split == 'development','group'])
        test = set(manifest.loc[manifest.split == 'test','group'])
        self.assertFalse(dev & test)
        for _, group in manifest.groupby('split'):
            self.assertEqual(set(group.label.unique()), {0,1})

    def test_unit_ambiguity_and_recomputation(self):
        raw = pd.read_csv(ROOT/'data/raw'/SURVEY_FILE).iloc[:2].copy()
        raw.iloc[0,0] = 24; raw.iloc[1,0] = 25
        raw.iloc[0,1] = 64; raw.iloc[0,2] = 160
        raw.iloc[1,1] = 60; raw.iloc[1,2] = 4.7
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'fixture.csv'; raw.to_csv(path,index=False)
            cleaned, audit = prepare_survey(path)
        self.assertAlmostEqual(cleaned.bmi.iloc[0], 25)
        self.assertTrue(pd.isna(cleaned.bmi.iloc[1]))
        self.assertEqual(audit['bmi_set_missing_due_to_ambiguous_or_invalid_measurements'], 1)

    def test_feature_grouping_does_not_depend_on_label(self):
        frame = pd.DataFrame([{**dict(zip(FEATURES,[24,23,1,0,0,0,0,0])), 'label':label} for label in [0,1]])
        self.assertEqual(fingerprints(frame, FEATURES).nunique(), 1)

    def test_preprocessing_fitted_to_development_only(self):
        frame = pd.read_csv(ROOT/'outputs/prepared_survey.csv')
        manifest = pd.read_csv(ROOT/'outputs/split_manifest.csv')
        development = frame[manifest.split == 'development']
        for name in ['random_forest','logistic_regression']:
            bundle = joblib.load(ROOT/'models'/f'{name}.joblib')
            fitted_pipeline = bundle['model'].calibrated_classifiers_[0].estimator
            np.testing.assert_allclose(fitted_pipeline.named_steps['imputer'].statistics_,
                                       development[FEATURES].median().to_numpy())

    def test_prediction_serialization_and_feature_order(self):
        result = predict_quiz(self.answers)
        reverse = predict_quiz(dict(reversed(list(self.answers.items()))))
        self.assertEqual(result, reverse)
        self.assertTrue(0 <= result['experimental_model_score'] <= 1)
        json.dumps(result, allow_nan=False)

    def test_missing_answer_abstains(self):
        self.answers['regular_periods'] = None
        result = predict_quiz(self.answers)
        self.assertEqual(result['status'], 'insufficient_inputs')
        self.assertNotIn('experimental_model_score', result)

    def test_unknown_bmi_supported(self):
        self.answers['bmi'] = None
        self.assertTrue(predict_quiz(self.answers)['bmi_imputed'])

    def test_minor_and_outside_age_range_abstain(self):
        for age in [16,46]:
            self.answers['age'] = age
            self.assertEqual(predict_quiz(self.answers)['status'], 'outside_experimental_scope')

    def test_existing_diagnosis_routes_to_tracking(self):
        self.assertEqual(predict_quiz({'known_pcos_diagnosis':True})['status'], 'tracking_journey')

    def test_invalid_values_rejected(self):
        for key,value in [('age', True),('bmi',float('nan')),('bmi',900),('acne',2),('weight_gain','yes')]:
            payload = dict(self.answers); payload[key] = value
            with self.assertRaises(ValueError):
                predict_quiz(payload)
        with self.assertRaises(ValueError):
            predict_quiz({**self.answers, 'diagnosis_as_input':1})

if __name__ == '__main__':
    unittest.main()
