#!/usr/bin/env bash
# Non-GUI smoke: Layer 1 validate + Swift binary exists.
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
python train/validate_clips.py
test -x ClinkApp/.build/release/Clink
cd ClinkApp && .build/release/Clink --demo
cd ..
echo "OK: validate_clips + Clink --demo passed"
