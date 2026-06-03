#!/usr/bin/env bash
# Non-GUI smoke: Layer 1 validate + Swift binary exists.
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
python train/validate_clips.py
test -x ClinkApp/.build/release/Clink
echo "OK: validate_clips passed and Clink binary built"
