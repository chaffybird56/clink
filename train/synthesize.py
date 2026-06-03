#!/usr/bin/env python3
"""Generate distinct golden + fault WAV clips (synthetic faults paired with downloads)."""
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


def smoke_alarm_chirp() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    y = np.zeros_like(t)
    # Low-battery style chirp: short 3.2 kHz bursts every ~0.55 s
    for phase in np.arange(0.05, DURATION_S, 0.55):
        idx = int(phase * SR)
        burst = int(0.045 * SR)
        tone = 0.75 * np.sin(2 * np.pi * 3200 * np.linspace(0, burst / SR, burst, endpoint=False))
        env = np.hanning(burst)
        if idx + burst < len(y):
            y[idx : idx + burst] = tone * env
    healthy = y.astype(np.float32)
    fault = healthy.copy()
    # Weak battery: slower chirp, lower pitch, uneven level
    fault *= 0.45
    fault += 0.12 * np.sin(2 * np.pi * 2100 * t)
    for phase in np.arange(0.12, DURATION_S, 0.78):
        idx = int(phase * SR)
        burst = int(0.06 * SR)
        if idx + burst < len(fault):
            fault[idx : idx + burst] += 0.25 * np.sin(2 * np.pi * 1800 * np.linspace(0, burst / SR, burst))
    return healthy, fault.astype(np.float32)


def garage_door() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    # Opener motor ramp + rail rumble + end-stop clunk
    ramp = np.clip(t / 0.35, 0, 1) * np.clip((DURATION_S - t) / 0.25, 0, 1)
    healthy = 0.32 * ramp * np.sin(2 * np.pi * 95 * t)
    healthy += 0.18 * ramp * np.sin(2 * np.pi * 190 * t)
    healthy += 0.08 * ramp * np.random.randn(len(t))
    clunk_idx = int(0.85 * SR)
    burst = int(0.02 * SR)
    if clunk_idx + burst < len(healthy):
        healthy[clunk_idx : clunk_idx + burst] += 0.65 * np.hanning(burst * 2)[::2][:burst]
    healthy = healthy.astype(np.float32)
    fault = healthy.copy()
    # Grinding belt + double clunk (misaligned track)
    fault += 0.22 * ramp * np.sin(2 * np.pi * 47 * t)
    fault += 0.15 * ramp * np.sin(2 * np.pi * 430 * t)
    fault[clunk_idx : clunk_idx + burst] *= 1.4
    clunk2 = int(1.15 * SR)
    if clunk2 + burst < len(fault):
        fault[clunk2 : clunk2 + burst] += 0.5 * np.hanning(burst * 2)[::2][:burst]
    return healthy, fault.astype(np.float32)


def vacuum_cleaner() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    healthy = 0.4 * np.sin(2 * np.pi * 180 * t) + 0.25 * np.random.randn(len(t)) * 0.3
    fault = healthy + 0.25 * np.sin(2 * np.pi * 95 * t)
    fault *= 1 + 0.3 * np.sin(2 * np.pi * 5 * t)
    return healthy.astype(np.float32), fault.astype(np.float32)


def relay_click() -> tuple[np.ndarray, np.ndarray]:
    t = _t()
    y = np.zeros_like(t)
    for phase in np.arange(0, DURATION_S, 0.42):
        idx = int(phase * SR)
        burst = int(0.012 * SR)
        y[idx : idx + burst] = 0.9 * np.hanning(burst * 2)[::2][:burst]
    healthy = y.astype(np.float32)
    fault = healthy.copy()
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
    "smoke_alarm_chirp": {
        "title": "Smoke alarm chirp",
        "blurb": "Periodic low-battery chirp — sharp, recognizable signature.",
        "audience": "general / safety",
        "gen": smoke_alarm_chirp,
    },
    "garage_door": {
        "title": "Garage door opener",
        "blurb": "Motor ramp + rail + end-stop — mechanical sequence, not fan noise.",
        "audience": "general / home",
        "gen": garage_door,
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
