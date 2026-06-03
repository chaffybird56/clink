# Clink macOS app (Layer 2)

SwiftPM executable with bundled `Resources/` (Core ML model, mel filters, profile packs).

```bash
swift build -c release
.build/release/Clink
```

Resources are populated by `train/train_and_export.py` into `Sources/Clink/Resources/`.
