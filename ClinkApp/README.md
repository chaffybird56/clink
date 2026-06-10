# Clink app (Layers 2 + 4)

SwiftPM package with two targets:

| Target | Role |
|--------|------|
| `ClinkCore` (library) | Feature extraction (vDSP), Core ML scoring, profile store, **baseline builder + mic recorder**. Foundation/Accelerate/AVFoundation/CoreML only — compiles for macOS **and iOS**. |
| `Clink` (executable) | SwiftUI macOS app + headless CLI, with bundled `Resources/` (Core ML model, mel filters, profile packs). |

```bash
swift build -c release
.build/release/Clink            # GUI
.build/release/Clink --demo    # headless gate: golden→HEALTHY, fault→FAULT, baseline self-check
```

## Record your baseline (Layer 4)

Create a custom profile from any healthy clip — the centroid is learned from
overlapping 2 s windows and the threshold self-calibrates from intra-clip drift:

```bash
.build/release/Clink --make-profile path/to/healthy.wav --id my_fridge --name "Garage fridge"
```

In the GUI: sidebar → **Your baselines** → *Record baseline (3 s)* or *Baseline
from WAV…*. Custom profiles persist in `~/Library/Application Support/Clink/profiles/`
and can be deleted from the sidebar context menu.

## Tests

```bash
swift test
```

`Tests/ClinkCoreTests` gates Swift↔Python feature parity (committed fixtures from
`scripts/export_parity_fixture.py`), the status-band policy, the baseline builder,
and custom-profile persistence.

Resources are populated by `train/train_and_export.py` into `Sources/Clink/Resources/`.
