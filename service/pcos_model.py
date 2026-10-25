"""Serve the repository's pinned Random Forest, including its fitted preprocessing.

The digest is the delivered PACKAGE_CHECKSUMS.json value, verified against the
tracked artifact. There is deliberately no caller-controlled pickle path.
"""
import hashlib
import io
import math
import warnings
from pathlib import Path

MODEL_PATH = Path(__file__).resolve().parents[1] / 'auracare_pcos/models/random_forest.joblib'
MODEL_SHA256 = '102296849d064dab86c97bdc260f99a11af1bf503e7be6acab7cd93f2efab1b1'
METHOD_VERSION = 'trained-random-forest-v1'


class ModelUnavailable(Exception):
    pass


def load_model(path=MODEL_PATH):
    # Verify bytes before joblib executes any artifact content. This establishes
    # identity with the supplied package, not independent clinical validation.
    artifact = path.read_bytes()
    if hashlib.sha256(artifact).hexdigest() != MODEL_SHA256:
        raise ModelUnavailable('Model checksum mismatch')
    import joblib
    from sklearn.exceptions import InconsistentVersionWarning
    from sklearn.calibration import CalibratedClassifierCV
    from sklearn.ensemble import RandomForestClassifier
    from auracare_pcos.pcos_data import FEATURES

    with warnings.catch_warnings():
        warnings.simplefilter('error', InconsistentVersionWarning)
        bundle = joblib.load(io.BytesIO(artifact))
    if (bundle.get('name') != 'random_forest' or bundle.get('features') != FEATURES
            or not isinstance(bundle.get('model'), CalibratedClassifierCV)):
        raise ModelUnavailable('Unexpected model contract')
    pipeline = bundle['model'].calibrated_classifiers_[0].estimator
    if not any(isinstance(step, RandomForestClassifier) for step in pipeline.named_steps.values()):
        raise ModelUnavailable('Expected the supplied Random Forest pipeline')
    if list(bundle['model'].classes_) != [0, 1]:
        raise ModelUnavailable('Unexpected target encoding')
    return bundle


def assess(answers, bundle):
    from auracare_pcos.predict import predict_quiz

    # Abstentions and known-history routing do not require loading a model.
    requires_model = (
        not answers.get('known_pcos_diagnosis', False)
        and answers.get('age') is not None and 18 <= answers['age'] <= 45
        and all(answers.get(key) is not None for key in (
            'regular_periods', 'weight_gain', 'excess_hair',
            'skin_darkening', 'hair_thinning', 'acne'))
    )
    if requires_model and bundle is None:
        raise ModelUnavailable('Model unavailable')
    result = predict_quiz(answers, bundle=bundle)
    score = result.get('experimental_model_score')
    if score is not None and (not math.isfinite(score) or not 0 <= score <= 1):
        raise ModelUnavailable('Invalid model output')
    return {**result, 'method_version': METHOD_VERSION}
