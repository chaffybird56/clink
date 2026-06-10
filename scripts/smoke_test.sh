#!/usr/bin/env bash
# Non-GUI smoke: Layer 1 validate + Swift unit tests + headless demo.
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
python train/validate_clips.py
test -x ClinkApp/.build/release/Clink
cd ClinkApp
swift test
.build/release/Clink --demo
cd ..
echo "OK: validate_clips + swift test + Clink --demo passed"
