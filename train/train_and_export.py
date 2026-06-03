#!/usr/bin/env python3
"""Layer 1: profile centroids, sklearn encoder, Core ML export, validation metrics."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

import numpy as np
from sklearn.metrics import roc_auc_score
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from features import feature_vector, load_mono

ROOT = Path(__file__).resolve().parents[1]
GOLDEN = ROOT / "samples" / "golden"
FAULT = ROOT / "samples" / "fault"
MODELS = ROOT / "models"
PROFILES_DIR = ROOT / "profiles"


def _augment_fault(vec: np.ndarray, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = vec + rng.normal(0, 2.5, size=vec.shape)
    return out.astype(np.float32)


def collect() -> tuple[np.ndarray, np.ndarray, list[str]]:
    X, y, tags = [], [], []
    for wav in sorted(GOLDEN.glob("*.wav")):
        pid = wav.stem
        hvec = feature_vector(load_mono(str(wav)))
        X.append(hvec)
        y.append(0)
        tags.append(f"{pid}:healthy")
        fault = FAULT / f"{pid}.wav"
        if fault.exists():
            fvec = feature_vector(load_mono(str(fault)))
            X.append(fvec)
            y.append(1)
            tags.append(f"{pid}:fault")
            for k in range(4):
                X.append(_augment_fault(fvec, seed=abs(hash(pid)) + k))
                y.append(1)
                tags.append(f"{pid}:fault_aug{k}")
    return np.stack(X), np.array(y), tags


def main() -> None:
    import coremltools as ct

    MODELS.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "profiles" / "manifest.json").read_text())

    X, y, tags = collect()
    print(f"Dataset: {X.shape[0]} clips ({int((y==0).sum())} healthy, {int((y==1).sum())} fault)")

    clf = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(max_iter=500, random_state=42)),
        ]
    )
    clf.fit(X, y)
    train_acc = clf.score(X, y)
    print(f"Train accuracy (sanity): {train_acc:.2f}")

    # Per-profile centroids + distance thresholds on raw 64-d features
    for pid in manifest:
        pack_dir = PROFILES_DIR / pid
        pack_dir.mkdir(parents=True, exist_ok=True)
        h_path = GOLDEN / f"{pid}.wav"
        f_path = FAULT / f"{pid}.wav"
        h_vec = feature_vector(load_mono(str(h_path)))
        healthy_vecs = [h_vec]
        fault_vecs = []
        if f_path.exists():
            fault_vecs.append(feature_vector(load_mono(str(f_path))))

        centroid = np.mean(healthy_vecs, axis=0)
        h_dist = float(np.linalg.norm(h_vec - centroid))
        f_dists = [float(np.linalg.norm(fv - centroid)) for fv in fault_vecs]
        threshold = h_dist * 1.4 + 0.08
        if f_dists:
            mid = float((max(f_dists) + h_dist) / 2)
            # Headroom for Swift Accelerate STFT vs librosa training features.
            threshold = float(max(mid, 0.92 * max(f_dists) + 1.0))

        scaler = clf.named_steps["scaler"]
        h_prob = float(clf.predict_proba(scaler.transform([h_vec]))[0, 0])
        f_prob = (
            float(clf.predict_proba(scaler.transform([fault_vecs[0]]))[0, 0])
            if fault_vecs
            else None
        )

        pack = {
            "id": pid,
            "title": manifest[pid]["title"],
            "blurb": manifest[pid]["blurb"],
            "audience": manifest[pid]["audience"],
            "centroid": centroid.tolist(),
            "distance_threshold": threshold,
            "healthy_ml_probability": h_prob,
            "fault_ml_probability": f_prob,
        }
        (pack_dir / "profile.json").write_text(json.dumps(pack, indent=2))
        print(
            f"  {pid}: dist_thresh={threshold:.3f} "
            f"ML healthy={h_prob:.2f} fault={f_prob}"
        )

    # Distance AUC per pooled clips
    dists, labels = [], []
    for i, tag in enumerate(tags):
        pid = tag.split(":")[0]
        c = np.array(json.loads((PROFILES_DIR / pid / "profile.json").read_text())["centroid"])
        dists.append(float(np.linalg.norm(X[i] - c)))
        labels.append(y[i])
    auc = roc_auc_score(labels, dists)
    print(f"Pooled centroid-distance AUC: {auc:.3f}")

    # Export Core ML (class 0 = healthy)
    import torch
    import torch.nn as nn

    scaler = clf.named_steps["scaler"]
    lr = clf.named_steps["clf"]
    mean = scaler.mean_
    scale = scaler.scale_
    w = (lr.coef_.ravel() / scale).astype(np.float32)
    b = (lr.intercept_.ravel() - np.dot(w, mean)).astype(np.float32)

    class LogisticSigmoid(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.linear = nn.Linear(64, 1)

        def forward(self, x: torch.Tensor) -> torch.Tensor:
            return torch.sigmoid(self.linear(x))

    net = LogisticSigmoid()
    net.linear.weight.data = torch.from_numpy(w.reshape(1, -1))
    net.linear.bias.data = torch.from_numpy(b)
    net.eval()
    example = torch.randn(1, 64)
    traced = torch.jit.trace(net, example)
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="features", shape=(1, 64))],
        outputs=[ct.TensorType(name="healthy_probability")],
        minimum_deployment_target=ct.target.macOS13,
    )
    ml.author = "Clink"
    ml.short_description = "Acoustic health probability from 64-d spectral features"
    pkg_path = MODELS / "ClinkHealth.mlpackage"
    if pkg_path.exists():
        shutil.rmtree(pkg_path)
    ml.save(str(pkg_path))

    # Scaler params for Swift parity
    scaler = clf.named_steps["scaler"]
    swift_scaler = {
        "mean": scaler.mean_.tolist(),
        "scale": scaler.scale_.tolist(),
    }
    (MODELS / "scaler.json").write_text(json.dumps(swift_scaler, indent=2))

    meta = {
        "feature_dim": 64,
        "sample_rate": 22050,
        "duration_s": 2.0,
        "profiles": list(manifest.keys()),
        "class_labels": {"0": "healthy", "1": "fault"},
    }
    (MODELS / "model_meta.json").write_text(json.dumps(meta, indent=2))

    # Bundle model into profiles export folder for app
    app_resources = ROOT / "ClinkApp" / "Sources" / "Clink" / "Resources"
    app_resources.mkdir(parents=True, exist_ok=True)
    app_pkg = app_resources / "ClinkHealth.mlpackage"
    if app_pkg.exists():
        shutil.rmtree(app_pkg)
    shutil.copytree(pkg_path, app_pkg)
    shutil.copy(MODELS / "model_meta.json", app_resources / "model_meta.json")
    shutil.copy(MODELS / "scaler.json", app_resources / "scaler.json")
    mel_fb = MODELS / "mel_filters.json"
    if mel_fb.exists():
        shutil.copy(mel_fb, app_resources / "mel_filters.json")
    for pid in manifest:
        dest = app_resources / "profiles" / pid
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copy(PROFILES_DIR / pid / "profile.json", dest / "profile.json")
        shutil.copy(GOLDEN / f"{pid}.wav", dest / "golden.wav")
        if (FAULT / f"{pid}.wav").exists():
            shutil.copy(FAULT / f"{pid}.wav", dest / "fault.wav")

    print(f"Saved {pkg_path} + app Resources")

    import subprocess
    subprocess.check_call(["python", str(ROOT / "train" / "export_mel_filters.py")])


if __name__ == "__main__":
    main()
