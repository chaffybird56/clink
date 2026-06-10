#!/usr/bin/env bash
# Capture README screenshots by launching the app in deterministic --auto states.
# Requires Screen Recording permission for the invoking terminal.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/screenshots
mkdir -p "$OUT"

BIN=ClinkApp/.build/release/Clink
[ -x "$BIN" ] || (cd ClinkApp && swift build -c release)

window_id() {
  .venv/bin/python - <<'EOF'
import Quartz
wins = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
for w in wins:
    if w.get("kCGWindowOwnerName") == "Clink" and w.get("kCGWindowLayer", 1) == 0:
        print(w["kCGWindowNumber"])
        break
EOF
}

capture() {
  local state="$1" profile="$2" out="$3"
  echo "Capturing $out (state=$state profile=$profile)…"
  "$BIN" --auto "$state" --auto-profile "$profile" &
  local pid=$!
  sleep 4
  local wid
  wid=$(window_id)
  if [ -z "$wid" ]; then
    kill "$pid" 2>/dev/null || true
    echo "ERROR: Clink window not found"
    return 1
  fi
  screencapture -o -l "$wid" "$OUT/$out"
  kill "$pid" 2>/dev/null || true
  sleep 1
}

capture healthy smoke_alarm_chirp healthy.png
capture fault garage_door fault.png
capture name-sheet vacuum_cleaner baseline.png

echo "Done → $OUT"
ls -la "$OUT"
