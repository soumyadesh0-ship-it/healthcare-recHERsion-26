"""Synthetic request tests; no external authentication or health records used."""
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi.testclient import TestClient
from supabase_auth.errors import AuthApiError

from service.main import app
from service import pcos_model

ROOT = Path(__file__).resolve().parents[1]


class ModelApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bundle = pcos_model.load_model()

    def setUp(self):
        self.answers = json.loads((ROOT / 'auracare_pcos/examples/quiz_answers.json').read_text())
        self.auth_patch = patch('service.main.create_client')
        self.auth = self.auth_patch.start()
        self.addCleanup(self.auth_patch.stop)
        self.auth.return_value.auth.get_user.return_value = SimpleNamespace(
            user=SimpleNamespace(id='00000000-0000-0000-0000-000000000001'))
        self.env = patch.dict('os.environ', {
            'SUPABASE_URL': 'https://example.supabase.co', 'SUPABASE_ANON_KEY': 'test-public-key'})
        self.env.start()
        self.addCleanup(self.env.stop)
        with patch('service.main.pcos_model.load_model', return_value=self.bundle):
            self.client = TestClient(app)
            self.client.__enter__()
        self.addCleanup(self.client.__exit__, None, None, None)

    def post(self, payload=None):
        return self.client.post('/pcos/model-assessment',
            json=self.answers if payload is None else payload,
            headers={'Authorization': 'Bearer synthetic-token'})

    def test_real_inference_and_feature_order(self):
        result = self.post()
        self.assertEqual(result.status_code, 200, result.text)
        data = result.json()
        self.assertEqual(data['status'], 'experimental_result')
        self.assertEqual(data['model'], 'random_forest')
        self.assertEqual(data['method_version'], pcos_model.METHOD_VERSION)
        self.assertTrue(0 <= data['experimental_model_score'] <= 1)
        self.assertEqual(data, self.post(dict(reversed(list(self.answers.items())))).json())
        from auracare_pcos.predict import predict_quiz
        self.assertEqual(data['experimental_model_score'], predict_quiz(self.answers)['experimental_model_score'])
        self.assertEqual(result.headers['cache-control'], 'no-store')
        self.auth.return_value.table.assert_not_called()
        self.auth.return_value.auth.get_user.assert_called_with('synthetic-token')

    def test_auth_required_invalid_and_unavailable(self):
        self.assertEqual(self.client.post('/pcos/model-assessment', json=self.answers).status_code, 401)
        self.auth.return_value.auth.get_user.return_value = None
        self.assertEqual(self.post().status_code, 401)
        self.auth.return_value.auth.get_user.side_effect = AuthApiError('bad token', 401, 'bad_jwt')
        self.assertEqual(self.post().status_code, 401)
        from httpx import ConnectError
        self.auth.return_value.auth.get_user.side_effect = ConnectError('offline')
        self.assertEqual(self.post().status_code, 503)

    def test_missing_answers_optional_bmi_and_routing(self):
        for key in ['age', 'regular_periods', 'acne']:
            response = self.post({**self.answers, key: None}).json()
            self.assertEqual(response['status'], 'insufficient_inputs')
            self.assertIn(key, response['missing'])
            self.assertNotIn('experimental_model_score', response)
        self.assertTrue(self.post({**self.answers, 'bmi': None}).json()['bmi_imputed'])
        self.assertEqual(self.post({'known_pcos_diagnosis': True}).json()['status'], 'tracking_journey')
        for age in [17, 46]:
            self.assertEqual(self.post({**self.answers, 'age': age}).json()['status'], 'outside_experimental_scope')

    def test_invalid_inputs_are_rejected_without_echo(self):
        for key, value in [('age', True), ('age', '28'), ('bmi', 71),
                ('bmi', 9), ('acne', 2), ('acne', 'private-answer'),
                ('weight_gain', 0.5), ('known_pcos_diagnosis', None),
                ('unsupported_field', 'private-answer')]:
            with self.subTest(key=key, value=value):
                response = self.post({**self.answers, key: value})
                self.assertEqual(response.status_code, 422)
                self.assertNotIn('private-answer', response.text)
        # Explicit non-finite JSON numbers are rejected by model validation.
        for value in ['NaN', 'Infinity']:
            response = self.client.post('/pcos/model-assessment',
                content='{"age":' + value + '}',
                headers={'Authorization': 'Bearer synthetic-token', 'Content-Type': 'application/json'})
            self.assertEqual(response.status_code, 422)

    def test_unavailable_artifact_and_no_hidden_fallback(self):
        app.state.pcos_model = None
        self.assertEqual(self.post().status_code, 503)
        self.assertEqual(self.post({'known_pcos_diagnosis': True}).json()['status'], 'tracking_journey')
        with patch('service.main.pcos_model.assess', side_effect=RuntimeError('private-internal-detail')):
            response = self.post()
            self.assertEqual(response.status_code, 503)
            self.assertNotIn('private-internal-detail', response.text)

    def test_trusted_artifact_required_before_deserialization(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'model.joblib'
            path.write_bytes(b'untrusted')
            with patch('joblib.load') as loader:
                with self.assertRaises(pcos_model.ModelUnavailable):
                    pcos_model.load_model(path)
                loader.assert_not_called()
        with patch('service.pcos_model.MODEL_SHA256', 'invalid'):
            with self.assertRaises(pcos_model.ModelUnavailable):
                pcos_model.load_model()

    def test_startup_survives_missing_model_and_wrong_features_are_rejected(self):
        with patch('service.main.pcos_model.load_model', side_effect=FileNotFoundError):
            with TestClient(app) as client:
                response = client.post('/pcos/model-assessment', json=self.answers,
                    headers={'Authorization': 'Bearer synthetic-token'})
                self.assertEqual(response.status_code, 503)
        with patch('joblib.load', return_value={**self.bundle, 'features': ['wrong']}):
            with self.assertRaises(pcos_model.ModelUnavailable):
                pcos_model.load_model()

    def test_legacy_summary_endpoint_unchanged(self):
        self.auth.return_value.table.return_value.insert.return_value.execute.return_value = SimpleNamespace(
            data=[{'id': '00000000-0000-0000-0000-000000000002'}])
        response = self.client.post('/predict-pcos', json={
            'irregular_periods': True, 'acne': False,
            'excess_hair_growth': None, 'scalp_hair_thinning': True},
            headers={'Authorization': 'Bearer synthetic-token'})
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()['risk_score'], 2)
        self.assertEqual(response.json()['method_version'], 'survey-count-v1')
        self.assertNotIn('experimental_model_score', response.json())


if __name__ == '__main__':
    unittest.main()
