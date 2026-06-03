#!/usr/bin/env python3
"""Headless local demo: same scoring logic as the macOS app (distance-primary)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "train"))

import coremltools as ct
import numpy as np
from features import feature_vector, load_mono


def score(profile: dict, wav: Path, model) -> str:
    vec = feature_vector(load_mono(str(wav)))
    centroid = np.array(profile["centroid"])
    dist = float(np.linalg.norm(vec - centroid))
    thresh = profile["distance_threshold"]
    out = model.predict({"features": vec.astype(np.float32).reshape(1, -1)})
    prob = float(out["healthy_probability"].flatten()[0])
    if dist <= thresh:
        status = "HEALTHY"
    elif dist <= thresh * 1.2:
        status = "WATCH"
    else:
        status = "FAULT"
    return f"{status:7}  dist={dist:.2f} (≤{thresh:.2f})  ml={prob:.0%}  file={wav.name}"


def main() -> None:
    model = ct.models.MLModel(str(ROOT / "models" / "ClinkHealth.mlpackage"))
    print("Clink local demo (app-equivalent scoring)\n")
    for pack_path in sorted((ROOT / "profiles").glob("*/profile.json")):
        pack = json.loads(pack_path.read_text())
        pid = pack["id"]
        print(f"=== {pack['title']} ({pid}) ===")
        for label in ("golden", "fault"):
            wav = ROOT / "samples" / label / f"{pid}.wav"
            print(f"  {label:6} -> {score(pack, wav, model)}")
        print()


if __name__ == "__main__":
    main()
