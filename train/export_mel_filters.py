#!/usr/bin/env python3
"""Export mel filterbank for Swift feature parity."""
import json
from pathlib import Path

import librosa
import numpy as np

from features import N_FFT, N_MELS, SR

fb = librosa.filters.mel(sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmax=8000)
out = Path(__file__).resolve().parents[1] / "models" / "mel_filters.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"n_fft": N_FFT, "n_mels": N_MELS, "filters": fb.tolist()}))
print(f"Wrote {out}")
