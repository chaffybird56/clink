# Clink training (Layer 1)

## Pipeline

1. `synthesize.py` — golden + fault WAV pairs under `samples/`
2. `download_samples.py` — optional Mixkit golden replacements
3. `export_mel_filters.py` — `models/mel_filters.json` for Swift parity
4. `train_and_export.py` — centroids, thresholds, `ClinkHealth.mlpackage`, app resources
5. `validate_clips.py` — golden PASS / fault FAIL

Run all: `bash ../scripts/build_layer1.sh`

## Dependencies

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```
