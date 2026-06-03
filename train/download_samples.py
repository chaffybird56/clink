#!/usr/bin/env python3
"""
Optional: fetch Mixkit preview clips (Mixkit License) and trim to golden WAVs.
Falls back to synthesize.py output when download or conversion fails.
"""
from __future__ import annotations

import shutil
import tempfile
import urllib.request
from pathlib import Path

from features import DURATION_S, SR, load_mono

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "samples" / "downloaded"
GOLDEN = ROOT / "samples" / "golden"

# Mixkit preview MP3s (royalty-free, no attribution). See mixkit.co/license
CANDIDATES = {
    "box_fan": [
        "https://assets.mixkit.co/active_storage/sfx/1813/1813-preview.mp3",
    ],
    "laptop_fan": [
        "https://assets.mixkit.co/active_storage/sfx/1866/1866-preview.mp3",
    ],
    "vacuum_cleaner": [
        "https://assets.mixkit.co/active_storage/sfx/1834/1834-preview.mp3",
    ],
    "relay_click": [
        "https://assets.mixkit.co/active_storage/sfx/213/213-preview.mp3",
    ],
    "microwave_hum": [
        "https://assets.mixkit.co/active_storage/sfx/1831/1831-preview.mp3",
    ],
}


def try_download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Clink/1.0"})
        with urllib.request.urlopen(req, timeout=25) as resp:
            data = resp.read()
        if len(data) < 2000:
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return True
    except Exception as exc:
        print(f"  skip {url}: {exc}")
        return False


def mp3_to_golden_wav(mp3_path: Path, wav_path: Path) -> bool:
    import librosa
    import soundfile as sf

    try:
        y, _ = librosa.load(str(mp3_path), sr=SR, mono=True, duration=DURATION_S)
        target = int(SR * DURATION_S)
        if len(y) < target:
            y = __import__("numpy").pad(y, (0, target - len(y)))
        y = y[:target]
        peak = max(abs(y.max()), abs(y.min()), 1e-6)
        y = (0.85 * y / peak).astype("float32")
        sf.write(wav_path, y, SR)
        return True
    except Exception as exc:
        print(f"  convert failed {mp3_path.name}: {exc}")
        return False


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, urls in CANDIDATES.items():
        dest_wav = GOLDEN / f"{pid}.wav"
        ok = False
        for url in urls:
            with tempfile.TemporaryDirectory() as tmp:
                mp3 = Path(tmp) / f"{pid}.mp3"
                if not try_download(url, mp3):
                    continue
                if mp3_to_golden_wav(mp3, dest_wav):
                    shutil.copy(dest_wav, OUT / f"{pid}.wav")
                    print(f"  {pid}: golden from Mixkit ({url})")
                    ok = True
                    break
        if not ok:
            print(f"  {pid}: using synthesized samples/golden/{pid}.wav")


if __name__ == "__main__":
    main()
