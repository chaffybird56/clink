"""Shared audio features for training and Swift parity (64-d vector)."""
from __future__ import annotations

import numpy as np

SR = 22_050
DURATION_S = 2.0
N_MELS = 32
HOP = 512
N_FFT = 2048


def load_mono(path: str, sr: int = SR) -> np.ndarray:
    import librosa

    y, _ = librosa.load(path, sr=sr, mono=True, duration=DURATION_S)
    target = int(sr * DURATION_S)
    if len(y) < target:
        y = np.pad(y, (0, target - len(y)))
    return y[:target].astype(np.float32)


def feature_vector(y: np.ndarray, sr: int = SR) -> np.ndarray:
    import librosa

    mel = librosa.feature.melspectrogram(
        y=y, sr=sr, n_fft=N_FFT, hop_length=HOP, n_mels=N_MELS, fmax=8000
    )
    log_mel = librosa.power_to_db(mel, ref=np.max)
    means = log_mel.mean(axis=1)
    stds = log_mel.std(axis=1)
    vec = np.concatenate([means, stds]).astype(np.float32)
    return vec


def feature_matrix(paths: list[str]) -> np.ndarray:
    return np.stack([feature_vector(load_mono(p)) for p in paths], axis=0)
