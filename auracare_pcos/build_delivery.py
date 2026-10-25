"""Generate a readable walkthrough and a Colab entry notebook from actual outputs."""
from pathlib import Path
import json, sys, zipfile, hashlib
ROOT = Path(__file__).resolve().parent

def main():
    m = json.loads((ROOT/'outputs/metrics.json').read_text())
    a = json.loads((ROOT/'outputs/data_audit.json').read_text())
    t = json.loads((ROOT/'outputs/transfer_stress_test.json').read_text())
    rf = m['holdout']['random_forest']; lr = m['holdout']['logistic_regression']
    versions = m['versions']
    import scipy, matplotlib, threadpoolctl
    requirements = '\n'.join([f'numpy=={versions["numpy"]}',f'pandas=={versions["pandas"]}',
        f'scikit-learn=={versions["scikit_learn"]}',f'scipy=={scipy.__version__}',
        f'joblib=={versions["joblib"]}',f'matplotlib=={matplotlib.__version__}',
        f'threadpoolctl=={threadpoolctl.__version__}'])+'\n'
    (ROOT/'requirements.txt').write_text(requirements)
    table = '| Metric | Random Forest | Logistic Regression |\n|---|---:|---:|\n'
    for key,label in [('accuracy','Accuracy'),('sensitivity','Sensitivity / recall'),('specificity','Specificity'),
                      ('precision','Precision'),('f1','F1'),('roc_auc','ROC-AUC'),('average_precision','Average precision'),('brier_score','Brier score (lower is better)')]:
        table += f'| {label} | {rf[key]:.4f} | {lr[key]:.4f} |\n'
    (ROOT/'WALKTHROUGH.md').write_text(f'''# Auracare PCOS quiz: completed experimental training

Prepared 24 October 2026. This is a research prototype for adults aged 18–45.
The model learns association with a **self-reported previous PCOS/PCOD diagnosis**.
It does not establish who currently has PCOS. A zero label means no reported diagnosis,
not a clinically confirmed absence of PCOS. No clinical performance claim follows from this experiment.

## What was completed

- Trained, tuned, and sigmoid-calibrated Random Forest and Logistic Regression.
- Selected Random Forest using nested development predictions, before inspecting the holdout.
- Saved both fitted pipelines. The selected artifact is `models/random_forest.joblib`.
- Evaluated a separate seven-feature transfer model against clinical-source records.
- Added local JSON inference, a quiz question contract, a Colab entry notebook, and integrity tests.
- No Flutter UI, public API, authentication, daily database, or GitHub deployment was created.

## Phase 1: define the task and label

Inputs are questionnaire-compatible symptoms plus age and BMI. Output is an experimental model
score for the training label. It is not a diagnosis, disease severity, fertility forecast, or probability
that an individual has PCOS. Internally, 0.5 is a fixed evaluation threshold, chosen before testing.
It is not a medically validated cutoff. User-facing inference deliberately avoids low/medium/high
risk bands, automatic reassurance, and diagnostic labels.

## Phase 2: inventory and select sources

Source folder: https://drive.google.com/drive/folders/1IS1iTmIPa5KVR73vgO6W2yXHRr38Z2v3

| File | Role in this run | Reason |
|---|---|---|
| CLEAN- PCOS SURVEY SPREADSHEET.csv | Main training/development/holdout | Self-report questions match quiz inputs |
| PCOS_data.csv | Separate transfer stress test only | Different source; clinical fields and uncertain period codes |
| cleaned_pcos_data.csv | Excluded | Reuses clinical cohort; 292 BMI values differ from raw version |
| PCOS_data_without_infertility.xlsx | Excluded | Reuses the 541 clinical profiles; not new participants |
| allData.csv | Excluded from fitting | Different categories, missing values and duplicate responses; needs a separately validated mapping |
| PCOS-Data.csv | Excluded | Ambiguous target codes, including `mb` and `mb n` |
| pcos_dataset.csv | Excluded | Laboratory/follicle-count inputs and unverified provenance |
| updated train dataset.zip | Excluded | Image task; 3,200 JPGs and a label workbook are not quiz answers |

Six CSV text snapshots supplied by Drive are included in `data/raw` for private reproducibility.
Hashes identify those exact local snapshots, not independently verified original publisher releases.
Do not publish/relicense the source data or distribute models commercially without verifying data rights.
The duplicate clinical files are not pooled. No synthetic patients or SMOTE samples were created.

## Phase 3: clean records without inventing answers

The original main survey has **{a['original_rows']} rows**. Remove
**{a['exact_duplicate_rows_removed']} exact duplicate row**, then exclude
**{a['excluded_outside_age_18_45_or_unknown']} records outside ages 18–45**.
This leaves **{a['retained_rows']} rows: {a['positive_labels']} positive labels and {a['negative_labels']} zero labels**.

Height contains values such as 4.7 and 13.46 in a mixed-unit column. We do not guess whether these
mean feet, feet-and-inches, or a typing error. BMI is recomputed as kg / (height in metres squared)
only for plausible stated centimetres (120–220) and kg (25–250), with a broad BMI quality range
of 10–70. These are engineering quality bounds, not disease thresholds. **{a['bmi_set_missing_due_to_ambiguous_or_invalid_measurements']}
BMI values become missing**. During each model fit, missing values are replaced with the training
fold's median and a missing-value indicator is added. Validation/test values never influence the median.

The retained survey has **{a['regularity_vs_month_interval_disagreements']} disagreements** between
the direct regular-periods answer and the separate interval question. The direct answer is used;
the interval and bleeding-duration columns are excluded. These records are retained, not silently
removed to improve scores. Source-row references remain available for investigation.

## Phase 4: construct eight features

| Feature | Encoding / preparation |
|---|---|
| age | Years, experimental scope 18–45 |
| bmi | Recomputed kg/m²; optional at inference |
| regular_periods | 1 = regular, 0 = not regular |
| weight_gain | 1 = reported yes, 0 = reported no |
| excess_hair | 1 = reported yes, 0 = reported no |
| skin_darkening | 1 = reported yes, 0 = reported no |
| hair_thinning | 1 = reported yes, 0 = reported no |
| acne | 1 = reported yes, 0 = reported no |

Blood group, identifiers, prior diagnosis, laboratory values, ultrasound findings, and unsupported
fields are not predictors. Prior diagnosis is the target only. Diet/exercise/mood fields are omitted
from this first specification. Symptom question time windows are vague in the source, which limits
interpretation; do not invent a 7-day or 30-day training window.

At inference, unanswered binary symptom questions produce `insufficient_inputs`, not a zero.
Unknown BMI can be imputed. A reported existing diagnosis routes to a tracking journey without
rescoring. These are prototype interaction rules, not clinical eligibility screening.

## Phase 5: split before learning preprocessing

Identical eight-feature profiles receive the same SHA-256 grouping key. This keeps coarse duplicate
profiles together even if labels conflict. No conflicting profile groups occurred here. This is only
a proxy for patient identity: there are no verified survey patient IDs. Different responses from the
same person could still cross the split.

Using `StratifiedGroupKFold`, seed 42, the first of five folds is fixed as the holdout. We do not try
several splits and choose the best one.

- Development: **{m['split']['development_n']} rows**, including **{m['split']['development_positive']} positive labels**.
- Holdout: **{m['split']['test_n']} rows**, including **{m['split']['test_positive']} positive labels**.
- Identical predictor-group overlap: **0**.

The same partition is used for both model families. The exported models remain fitted on development
data; the holdout was not folded back into training after evaluation.

## Phase 6: train, tune, calibrate, and select

**Random Forest:** 200 trees, balanced class weights, fixed seed, maximum depth candidates
3 / 6 / unrestricted, minimum leaf-size candidates 3 / 8. A tree combines simple feature splits;
the forest averages many trees. Restricting tree depth and leaf size helps control overfitting.

**Logistic Regression:** median imputation, standardization, L2-regularized classifier; C candidates
0.1 / 1 / 10, class weight none / balanced. Scaling is fitted within each training fold.

**Nested validation:** five outer folds within development estimate candidate performance. Within
each outer training fold, three grouped inner folds choose hyperparameters using average precision.
Sigmoid calibration is then fitted with grouped cross-validation inside that outer training fold.
The resulting model predicts the outer validation fold. Thus model tuning and calibration do not
see its outer validation labels. Calibration hyperparameters are not separately tuned.

Combine the outer predictions into out-of-fold (OOF) predictions. Select the family with the higher
development OOF average precision. It was Random Forest:

- Random Forest development OOF AP: **{m['nested_cv']['random_forest']['oof_metrics']['average_precision']:.4f}**.
- Logistic Regression development OOF AP: **{m['nested_cv']['logistic_regression']['oof_metrics']['average_precision']:.4f}**.

After selection, tune each family on all development data using five grouped folds and fit a final
sigmoid-calibrated pipeline. Random Forest's final settings were depth **3**, minimum leaf size **8**.
Logistic Regression's final settings were C **0.1**, without class weighting. Both artifacts are retained
for comparison. The final calibration uses out-of-fold development scores and then refits the
underlying estimator on development data (`ensemble=False`). Calibration does not confer clinical validity.

## Phase 7: final holdout evaluation

{table}

Random Forest correctly classified **{rf['tp']} of {rf['positive_labels']} positive labels**,
missed **{rf['fn']}**, correctly classified **{rf['tn']} zero labels**, and made **{rf['fp']} false-positive
prediction at threshold 0.5. Its sensitivity is **{rf['sensitivity']:.1%}**, which is too low to claim
that a negative quiz result rules out PCOS. An always-zero baseline already obtains
**{m['holdout']['constant_prior_baseline']['accuracy']:.1%} accuracy** because positive labels are less common.

Accuracy measures all correct labels. Sensitivity measures detected positive labels. Specificity
measures correctly predicted zero labels. Precision measures positive labels among positive predictions.
ROC-AUC assesses ranking across thresholds. Average precision summarizes precision/recall ranking
(it is not the trapezoidal PR-AUC). Brier score measures squared probability error, combining aspects
of calibration and discrimination. The five-bin calibration chart is noisy with only 85 observations.

The selected model's holdout sensitivity has a 95% cluster-bootstrap interval of
**{m['selected_holdout_95pct_cluster_bootstrap_intervals']['sensitivity'][0]:.1%}–{m['selected_holdout_95pct_cluster_bootstrap_intervals']['sensitivity'][1]:.1%}**.
This interval resamples holdout predictor groups 1,000 times. It is conditional on the fitted model
and does not cover uncertainty from retraining, recruitment bias, or inaccurate labels.
Small exploratory age subgroups are reported in `metrics.json`; they do not demonstrate fairness.
Permutation importance reports AP drops when a feature is shuffled on the holdout. It is descriptive,
can be unstable for correlated features, and does not establish causes. No model changes were made
in response to these holdout analyses. Any subsequent tuning requires a fresh evaluation set.

![Evaluation plots](outputs/evaluation.png)

## Phase 8: cross-source stress test and its limitation

The clinical source does not have a verified questionnaire-equivalent period-regularity codebook.
Rather than guess, a **separate seven-feature Random Forest** is fitted to survey development data,
omitting period regularity. It is calibrated and tuned only on that development data.

The clinical source has {t['clinical_rows_available']} age-eligible records. Exclude
{t['identical_survey_profiles_excluded']} predictor profile matching any survey profile, leaving
**{t['metrics']['n']} records**. This seven-feature transfer model achieved:

- ROC-AUC: **{t['metrics']['roc_auc']:.4f}**.
- Average precision: **{t['metrics']['average_precision']:.4f}**.
- Sensitivity at 0.5: **{t['metrics']['sensitivity']:.1%}** ({t['metrics']['tp']} / {t['metrics']['positive_labels']}).
- Specificity at 0.5: **{t['metrics']['specificity']:.1%}**.

The low sensitivity is important evidence against generalizing this prototype into clinical screening.
This is not external validation of the main eight-feature model: the feature set differs, label
provenance is unverified, and clinical assessments may differ from self-report. It is an exploratory
stress test illustrating source/measurement differences. Clinical records never tune the main model.

## Phase 9: save the model and test inference

`joblib` saves preprocessing, classifier, and calibration together. Use the provided locked versions;
cross-version pickle compatibility is not guaranteed. Load only trusted artifacts.

```bash
python -m venv .venv
# Windows PowerShell:
.venv\\Scripts\\Activate.ps1
# macOS / Linux alternative:
# source .venv/bin/activate
python -m pip install -r requirements.txt
python train.py
python -m unittest -v
python predict.py --input examples/quiz_answers.json
```

The test suite has 11 tests covering source hashes, split/group isolation, ambiguous unit handling,
BMI recomputation, label-independent grouping, training-only imputer statistics, serialized model
inference, JSON feature ordering, unknown-answer abstention, optional BMI, age limits, known-diagnosis
routing, and malformed input rejection. These are software/data integrity checks, not clinical tests.
The actual example output is saved in `outputs/example_prediction.json`; its inputs are synthetic.

## Phase 10: personalized quiz and Flutter integration

`quiz_contract.json` lists the eight input fields, encoding, and source wording. The six binary symptom
answers are required for scoring; the source did not support confident arbitrary missing-symptom
inference. Follow-ups can personalize the experience without changing the trained feature contract:
ask about an irregular-cycle answer, clarify an unknown answer, and confirm old entries before reuse.
Any newly collected duration/severity answers are initially descriptive only, not hidden model inputs.

The current prototype is Python inference, not a mobile UI. A later authenticated backend can call
`predict_quiz(answers)` and return its JSON to Flutter over HTTPS. Do not place a Python joblib file in
Flutter and expect Dart to execute it. Do not silently reroute personal health records to external AI
services. Persistence, consent, authentication and access controls need separate implementation.

Display a symptom summary with experimental wording. `experimental_model_score` is a developer
output; it must not be displayed as a validated personal probability. Outside the trained age range,
or when core answers are missing, the function returns a status without a score.

## Phase 11: future daily records and retraining

Daily logging can support reminders and descriptive history. The present source is cross-sectional,
so it cannot validate next-day prediction, PCOS progression, or changing disease probabilities.
Do not treat the model's own predictions as clinical labels. Collect consented repeated records with
timestamps, user identifiers, defined symptom windows, and separately verified clinical outcomes.
Later evaluate using user-disjoint and time-aware splits. A large number of days from a few users
is not the same as a large number of independent participants. Retrain offline on a schedule after
reviewing label quality and drift; do not self-update after every daily log.

## Framework, runtime and timing

Python **{versions['python']}**, scikit-learn **{versions['scikit_learn']}**, pandas **{versions['pandas']}**,
NumPy **{versions['numpy']}**, SciPy **{scipy.__version__}**, Matplotlib **{matplotlib.__version__}**,
joblib **{versions['joblib']}**. Testing uses the standard-library `unittest` framework.
No GPU, TensorFlow, neural network, or LLM was used. The current CPU run took
**{m['training_and_evaluation_seconds']} seconds** for training and numerical evaluation before final chart
rendering. Data review, writing code, tests and packaging take additional time. Rerun time depends on
hardware; initial environment installation can take several minutes.

## Read the delivered files

- `README.md`: short execution guide.
- `WALKTHROUGH.md`: this full explanation.
- `Auracare_PCOS_Colab.ipynb`: upload the ZIP into Colab, then train/test/predict.
- `pcos_data.py`: deterministic preprocessing and feature mapping.
- `train.py`: nested validation, tuning, calibration, holdout scoring, transfer stress test and charts.
- `predict.py`: validated local JSON inference.
- `test_pipeline.py`: integrity tests.
- `models/`: two fitted models and selected-model metadata.
- `outputs/`: audit, metrics, split manifest, predictions, confidence intervals, importance and plots.
- `data/raw/`: private source CSV snapshots; contains health records, do not commit publicly.

## Technical references

- https://scikit-learn.org/stable/common_pitfalls.html
- https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.StratifiedGroupKFold.html
- https://scikit-learn.org/stable/modules/calibration.html
- https://scikit-learn.org/stable/modules/model_evaluation.html
- https://www.monash.edu/medicine/mchri/pcos/guideline

Remaining work before real-user assessment: establish source permissions and label provenance,
clinical review of the questionnaire and result wording, recruitment of an independent target-user
cohort including clinically assessed non-PCOS participants, prospective evaluation, and privacy controls.
''', encoding='utf-8')
    (ROOT/'README.md').write_text('''# Auracare experimental PCOS quiz

Start with **WALKTHROUGH.md** for all phases, actual results and limitations.
The selected model is Random Forest, trained on 338 development responses; evaluated on 85 held-out responses.
Labels represent reported previous diagnosis, not verified disease status.

## Run locally (Python 3.12 recommended)

```bash
python -m venv .venv
# Windows: .venv\\Scripts\\Activate.ps1
# macOS/Linux: source .venv/bin/activate
python -m pip install -r requirements.txt
python predict.py --input examples/quiz_answers.json
python -m unittest -v
```

The models are already trained. To reproduce training: `python train.py`.
Open `Auracare_PCOS_Colab.ipynb` in Colab if preferred. It prompts you to upload this ZIP.
Use only trusted joblib files. Keep `data/raw`, predictions, and health records private.
This package is not integrated into Flutter and is not a clinical diagnostic tool.
''', encoding='utf-8')
    questions = [
        ('age','Age (in Years)','number','18–45'),
        ('bmi','Calculated from weight in kg and height in cm','number_or_null','10–70; null allowed'),
        ('regular_periods','Are your periods regular ?','binary','1=yes; 0=no; null=unknown'),
        ('weight_gain','Have you gained weight recently?','binary','1=yes; 0=no; null=unknown'),
        ('excess_hair','Do you have excessive body/facial hair growth ?','binary','1=yes; 0=no; null=unknown'),
        ('skin_darkening','Are you noticing skin darkening recently?','binary','1=yes; 0=no; null=unknown'),
        ('hair_thinning','Do have hair loss/hair thinning/baldness ?','binary','1=yes; 0=no; null=unknown'),
        ('acne','Do you have pimples/acne on your face/jawline ?','binary','1=yes; 0=no; null=unknown')]
    contract = {'version':'experimental-1','scope':'adults 18–45; research prototype',
       'questions':[dict(zip(['key','source_wording','type','encoding'],q)) for q in questions],
       'missing_policy':'A null binary answer produces insufficient_inputs; null BMI uses development-trained imputation.',
       'target':'Self-reported prior PCOS diagnosis; not verified disease',
       'optional_routing_field':{'known_pcos_diagnosis':'Boolean; true skips scoring and routes to tracking.'},
       'personalization_rules':[{'if':'known_pcos_diagnosis is true','then':'tracking journey, no score'},
                               {'if':'regular_periods is 0','then':'Offer descriptive cycle-history follow-up; do not add it to model features'},
                               {'if':'any required binary answer is null','then':'Ask for clarification or return insufficient_inputs'},
                               {'if':'reusing previous answers','then':'Ask the user to confirm/update; do not interpret missing daily logs as symptom absence'}],
       'note':'This is a field/routing specification, not an implemented Flutter UI or clinically reviewed questionnaire.'}
    (ROOT/'quiz_contract.json').write_text(json.dumps(contract,indent=2))
    def md(s): return {'cell_type':'markdown','metadata':{},'source':s.splitlines(True)}
    def code(s): return {'cell_type':'code','metadata':{},'source':s.splitlines(True),'execution_count':None,'outputs':[]}
    cells = [md('# Auracare PCOS quiz training\nUpload the supplied ZIP. It includes trained artifacts and source snapshots. Use only your trusted package.\n\nExperimental prior-diagnosis labels; not a diagnosis. Read WALKTHROUGH.md.'),
        code("from google.colab import files\nfrom pathlib import Path\nimport zipfile, os\nuploaded = files.upload()\narchive = next(name for name in uploaded if name.endswith('.zip'))\ndestination = Path('/content/auracare_experiment')\ndestination.mkdir(exist_ok=True)\nwith zipfile.ZipFile(archive) as z:\n    for info in z.infolist():\n        target = (destination / info.filename).resolve()\n        if not target.is_relative_to(destination.resolve()):\n            raise ValueError('Unsafe archive path')\n    z.extractall(destination)\nos.chdir(destination / 'auracare_pcos')\nprint(Path.cwd())\n"),
        md('Install the exact training dependencies. A Colab runtime restart may be required if other packages were imported first.'),
        code("import subprocess, sys\nsubprocess.run([sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'], check=True)\n"),
        md('Inspect the audit and prepared data. Rerun training to reproduce preprocessing, development selection, calibration and the untouched holdout evaluation.'),
        code("subprocess.run([sys.executable, 'train.py'], check=True)\n"),
        code("import json\nfrom IPython.display import display, Markdown, Image\nmetrics = json.loads(Path('outputs/metrics.json').read_text())\nprint(json.dumps({'selected_model':metrics['selected_model'],'holdout':metrics['holdout']}, indent=2))\ndisplay(Image('outputs/evaluation.png'))\n"),
        md('Run software/data integrity tests. These do not constitute clinical validation.'),
        code("subprocess.run([sys.executable, '-m', 'unittest', '-v'], check=True)\n"),
        md('Test a synthetic questionnaire response. Edit the example JSON to try other valid inputs. Missing core symptom answers abstain.'),
        code("subprocess.run([sys.executable, 'predict.py', '--input', 'examples/quiz_answers.json'], check=True)\n"),
        code("display(Markdown(Path('WALKTHROUGH.md').read_text()))\n"),
        md('Optional: download the regenerated outputs and fitted model files.'),
        code("import shutil\narchive = shutil.make_archive('/content/auracare_retrained', 'zip', root_dir=Path.cwd().parent, base_dir=Path.cwd().name)\nfiles.download(archive)\n")]
    notebook = {'nbformat':4,'nbformat_minor':5,
        'metadata':{'kernelspec':{'display_name':'Python 3','language':'python','name':'python3'},'language_info':{'name':'python','version':'3.12'}},
        'cells':cells}
    for i, cell in enumerate(cells): cell['id'] = f'auracare-{i:02d}'
    (ROOT/'Auracare_PCOS_Colab.ipynb').write_text(json.dumps(notebook,indent=2))
    manifest = {'drive_folder':'https://drive.google.com/drive/folders/1IS1iTmIPa5KVR73vgO6W2yXHRr38Z2v3',
        'files': [{'name':name,'drive_file_id':id} for name,id in [
          ('CLEAN- PCOS SURVEY SPREADSHEET.csv','1tkH2HoVDLLDwFnTxX9DE0MFS3LePdPGF'),
          ('PCOS_data.csv','1IrtxAX5x0QhCSvycn6VKWoWes67d7vfN'),
          ('cleaned_pcos_data.csv','10WiG53FyAyPTDfxJdgylzcacd_-fsxKk'),
          ('PCOS-Data.csv','1DlQKRcNXHaqao5Wayr4tv-PUMK02NXul'),
          ('allData.csv','1xMseAChHHJdID0SyNfVRBt_1xnbDPHdy'),
          ('pcos_dataset.csv','1XbDlVGdvAOFl1mam1vuC8GDrk9-BhI7H')]]}
    (ROOT/'data/SOURCE_MANIFEST.json').write_text(json.dumps(manifest,indent=2))

if __name__ == '__main__':
    main()
