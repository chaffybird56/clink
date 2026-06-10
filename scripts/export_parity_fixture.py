#!/usr/bin/env python3
"""Export golden vectors for Swift parity checks (train/features.py).

Writes models/parity_fixture.json and refreshes the committed Swift test
fixtures in ClinkApp/Tests/ClinkCoreTests/Fixtures/ so `swift test` can gate
feature parity without a Python toolchain.
"""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "train"))
from features import feature_vector, load_mono

ROOT = Path(__file__).resolve().parents[1]
pid = sys.argv[1] if len(sys.argv) > 1 else "smoke_alarm_chirp"
golden = ROOT / "samples" / "golden" / f"{pid}.wav"
fault = ROOT / "samples" / "fault" / f"{pid}.wav"
profile = ROOT / "profiles" / pid / "profile.json"

vec = feature_vector(load_mono(str(golden)))
payload = {"profile": pid, "vector": vec.tolist()}

out = ROOT / "models" / "parity_fixture.json"
out.write_text(json.dumps(payload, indent=2))
print(f"Wrote {out} ({len(vec)} dims, norm={float((vec**2).sum())**0.5:.2f})")

fixtures = ROOT / "ClinkApp" / "Tests" / "ClinkCoreTests" / "Fixtures"
fixtures.mkdir(parents=True, exist_ok=True)
(fixtures / "parity_fixture.json").write_text(json.dumps(payload, indent=2))
shutil.copy(golden, fixtures / "golden.wav")
shutil.copy(fault, fixtures / "fault.wav")
shutil.copy(profile, fixtures / "profile.json")
shutil.copy(ROOT / "models" / "mel_filters.json", fixtures / "mel_filters.json")
print(f"Refreshed Swift test fixtures in {fixtures}")
