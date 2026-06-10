#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv
source .venv/bin/activate
pip install -q -r train/requirements.txt
python train/synthesize.py
python train/download_samples.py
python train/export_mel_filters.py
python train/train_and_export.py
python train/validate_clips.py
python scripts/export_parity_fixture.py
python scripts/update_readme_validation.py
