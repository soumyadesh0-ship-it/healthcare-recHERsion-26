# Auracare experimental PCOS quiz

Start with **WALKTHROUGH.md** for all phases, actual results and limitations.
The selected model is Random Forest, trained on 338 development responses; evaluated on 85 held-out responses.
Labels represent reported previous diagnosis, not verified disease status.

## Run locally (Python 3.12 recommended)

```bash
python -m venv .venv
# Windows: .venv\Scripts\Activate.ps1
# macOS/Linux: source .venv/bin/activate
python -m pip install -r requirements.txt
python predict.py --input examples/quiz_answers.json
python -m unittest -v
```

The models are already trained. To reproduce training: `python train.py`.
Open `Auracare_PCOS_Colab.ipynb` in Colab if preferred. It prompts you to upload this ZIP.
Use only trusted joblib files. Keep `data/raw`, predictions, and health records private.
This package is not integrated into Flutter and is not a clinical diagnostic tool.
