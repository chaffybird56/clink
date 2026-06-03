#!/usr/bin/env python3
"""Export one golden vector for Swift parity checks (train/features.py)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "train"))
from features import feature_vector, load_mono

ROOT = Path(__file__).resolve().parents[1]
pid = sys.argv[1] if len(sys.argv) > 1 else "smoke_alarm_chirp"
vec = feature_vector(load_mono(str(ROOT / "samples" / "golden" / f"{pid}.wav")))
out = ROOT / "models" / "parity_fixture.json"
out.write_text(json.dumps({"profile": pid, "vector": vec.tolist()}, indent=2))
print(f"Wrote {out} ({len(vec)} dims, norm={float((vec**2).sum())**0.5:.2f})")
