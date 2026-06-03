#!/usr/bin/env python3
"""Verify each profile pack: golden should score healthy, fault should not."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import coremltools as ct

from features import feature_vector, load_mono

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "models" / "ClinkHealth.mlpackage"


def main() -> None:
    model = ct.models.MLModel(str(MODEL_PATH))

    print("Profile validation (healthy PASS, fault FAIL — distance-primary):\n")
    all_ok = True
    for pack_path in sorted((ROOT / "profiles").glob("*/profile.json")):
        pack = json.loads(pack_path.read_text())
        pid = pack["id"]
        centroid = np.array(pack["centroid"])
        thresh = pack["distance_threshold"]

        for label, expect_pass in (("golden", True), ("fault", False)):
            wav = ROOT / "samples" / ("golden" if label == "golden" else "fault") / f"{pid}.wav"
            if not wav.exists():
                continue
            vec = feature_vector(load_mono(str(wav)))
            dist = float(np.linalg.norm(vec - centroid))
            out = model.predict({"features": vec.astype(np.float32).reshape(1, -1)})
            prob = float(out["healthy_probability"].flatten()[0])
            dist_ok = dist <= thresh
            if expect_pass:
                passed = dist_ok
            else:
                passed = not dist_ok
            status = "PASS" if passed else "FAIL"
            if not passed:
                all_ok = False
            print(
                f"  {pid:16} {label:6} {status}  dist={dist:.3f} (≤{thresh:.3f})  "
                f"ml_healthy={prob:.2f}"
            )
    print()
    print("All profiles OK" if all_ok else "Some checks FAILED — tune thresholds in train_and_export.py")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
