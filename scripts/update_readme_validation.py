#!/usr/bin/env python3
"""Refresh validation table in README.md from validate_clips output."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRAIN = ROOT / "train"


def capture_table() -> str:
    import sys

    sys.path.insert(0, str(TRAIN))
    from features import feature_vector, load_mono
    import numpy as np
    import coremltools as ct

    model = ct.models.MLModel(str(ROOT / "models" / "ClinkHealth.mlpackage"))
    lines = ["| Profile | Clip | Result | Distance | Threshold | ML healthy |",
             "|---------|------|--------|----------|-----------|------------|"]
    for pack_path in sorted((ROOT / "profiles").glob("*/profile.json")):
        pack = json.loads(pack_path.read_text())
        pid = pack["id"]
        title = pack["title"]
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
            passed = (dist <= thresh) if expect_pass else (dist > thresh)
            lines.append(
                f"| {title} | {label} | {'PASS' if passed else 'FAIL'} | "
                f"{dist:.2f} | {thresh:.2f} | {prob:.0%} |"
            )
    return "\n".join(lines)


def main() -> None:
    table = capture_table()
    readme = (ROOT / "README.md").read_text()
    pattern = r"<!-- VALIDATION:START -->.*?<!-- VALIDATION:END -->"
    block = f"<!-- VALIDATION:START -->\n{table}\n<!-- VALIDATION:END -->"
    if not re.search(pattern, readme, re.DOTALL):
        raise SystemExit("README missing validation markers")
    readme = re.sub(pattern, block, readme, count=1, flags=re.DOTALL)
    (ROOT / "README.md").write_text(readme)
    print("Updated README validation table")


if __name__ == "__main__":
    main()
