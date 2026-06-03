#!/usr/bin/env python3
"""Generate relatable golden + fault WAV clips (CC0-style originals, synthetic faults)."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import soundfile as sf

from features import DURATION_S, SR

ROOT = Path(__file__).resolve().parents[1]
GOLDEN = ROOT / "samples" / "golden"
FAULT = ROOT / "samples" / "fault"


def _t() -> np.ndarray:
    return np.linspace(0, DURATION_S, int(SR * DURATION_S), endpoint=False)


def _save(path: Path, y: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, np.clip(y, -1, 1), SR)


def box_fan() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    # Household box fan: tonal hum + blade whoosh
    healthy = 0.35 * np.sin(2 * np.pi * 120 * t)
    healthy += 0.12 * np.sin(2 * np.pi * 240 * t)
    healthy += 0.08 * np.random.randn(len(t))
    # Fault: bearing grind + wobble
    fault = healthy.copy()
    fault += 0.15 * np.sin(2 * np.pi * 7 * t) * healthy
    fault += 0.2 * np.sin(2 * np.pi * 900 * t)
    return healthy.astype(np.float32), fault.astype(np.float32)


def laptop_fan() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    # Higher pitch PC/laptop cooler
    healthy = 0.3 * np.sin(2 * np.pi * 420 * t) + 0.1 * np.sin(2 * np.pi * 840 * t)
    healthy += 0.06 * np.random.randn(len(t))
    fault = healthy * (1 + 0.4 * np.sin(2 * np.pi * 12 * t))
    fault += 0.18 * np.sin(2 * np.pi * 2100 * t)
    return healthy.astype(np.float32), fault.astype(np.float32)


def vacuum_cleaner() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    healthy = 0.4 * np.sin(2 * np.pi * 180 * t) + 0.25 * np.random.randn(len(t)) * 0.3
    fault = healthy + 0.25 * np.sin(2 * np.pi * 95 * t)
    fault *= 1 + 0.3 * np.sin(2 * np.pi * 5 * t)
    return healthy.astype(np.float32), fault.astype(np.float32)


def relay_click() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    y = np.zeros_like(t)
    # Crisp relay / turn-signal style clicks every ~0.4 s
    for phase in np.arange(0, DURATION_S, 0.42):
        idx = int(phase * SR)
        burst = int(0.012 * SR)
        y[idx : idx + burst] = 0.9 * np.hanning(burst * 2)[::2][:burst]
    healthy = y.astype(np.float32)
    fault = healthy.copy()
    # Weak/springy: softer clicks + extra bounce
    fault *= 0.55
    for phase in np.arange(0.08, DURATION_S, 0.42):
        idx = int(phase * SR) + int(0.02 * SR)
        burst = int(0.008 * SR)
        if idx + burst < len(fault):
            fault[idx : idx + burst] += 0.35 * np.hanning(burst * 2)[::2][:burst]
    return healthy, fault.astype(np.float32)


def microwave_hum() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    healthy = 0.25 * np.sin(2 * np.pi * 60 * t) + 0.15 * np.sin(2 * np.pi * 180 * t)
    healthy += 0.05 * np.random.randn(len(t))
    fault = healthy + 0.2 * np.sin(2 * np.pi * 400 * t)
    fault += 0.1 * np.random.randn(len(t))
    return healthy.astype(np.float32), fault.astype(np.float32)


PROFILES = {
    "box_fan": {
        "title": "Box fan",
        "blurb": "Bedroom desk fan — everyone knows this hum.",
        "audience": "general",
        "gen": box_fan,
    },
    "laptop_fan": {
        "title": "Laptop / PC fan",
        "blurb": "Cooling fan whine — thermal & power debugging.",
        "audience": "EE / CE / SE",
        "gen": laptop_fan,
    },
    "vacuum_cleaner": {
        "title": "Vacuum cleaner",
        "blurb": "Household motor — clogged or failing bearing.",
        "audience": "general",
        "gen": vacuum_cleaner,
    },
    "relay_click": {
        "title": "Relay / turn signal",
        "blurb": "Electromechanical tick — HIL and automotive-adjacent.",
        "audience": "EE / test",
        "gen": relay_click,
    },
    "microwave_hum": {
        "title": "Microwave / appliance hum",
        "blurb": "Mains hum + magnetron tone — kitchen appliance baseline.",
        "audience": "general",
        "gen": microwave_hum,
    },
}


def main() -> None:
    for pid, meta in PROFILES.items():
        h, f = meta["gen"]()
        _save(GOLDEN / f"{pid}.wav", h)
        _save(FAULT / f"{pid}.wav", f)
        print(f"  synthesized {pid}")

    manifest = {
        pid: {
            "title": meta["title"],
            "blurb": meta["blurb"],
            "audience": meta["audience"],
            "golden_wav": f"samples/golden/{pid}.wav",
            "fault_wav": f"samples/fault/{pid}.wav",
        }
        for pid, meta in PROFILES.items()
    }
    (ROOT / "profiles" / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"Wrote {len(PROFILES)} profile packs")


if __name__ == "__main__":
    main()
