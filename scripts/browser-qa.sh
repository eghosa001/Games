#!/usr/bin/env bash
set -euo pipefail

# Browser QA must exercise the exact GitHub Pages artifact produced by the
# Godot Web export workflow, not a stale preview deployment.
URL="${RENEW_BROWSER_URL:-https://eghosa001.github.io/Games/}"
OUT="${RENEW_BROWSER_OUTPUT:-artifacts/browser-qa}"
mkdir -p "$OUT"

cleanup() {
  printf 'Browser QA exit code: %s\n' "$?" > "$OUT/qa-status.txt"
  agent-browser console > "$OUT/final.console.txt" 2>&1 || true
  agent-browser errors > "$OUT/final.errors.txt" 2>&1 || true
  agent-browser get url > "$OUT/final.url.txt" 2>&1 || true
}
trap cleanup EXIT

agent-browser open "$URL"
agent-browser wait 10000
agent-browser screenshot --full "$OUT/startup.png"
agent-browser snapshot -i > "$OUT/startup.snapshot.txt"
agent-browser console > "$OUT/startup.console.txt" 2>&1 || true
agent-browser errors > "$OUT/startup.errors.txt" 2>&1 || true

# Exercise the documented opening loop without assuming DOM selectors.
for key in i a r r r o n; do
  agent-browser press "$key" || true
  sleep 1
done

agent-browser screenshot --full "$OUT/opening-loop.png"
agent-browser snapshot -i > "$OUT/opening-loop.snapshot.txt"
agent-browser console > "$OUT/opening-loop.console.txt" 2>&1 || true
agent-browser errors > "$OUT/opening-loop.errors.txt" 2>&1 || true

# Capture a real phone-sized render after the Pages deployment has settled.
agent-browser set viewport 390 844
agent-browser reload
agent-browser wait 10000
agent-browser screenshot --full "$OUT/mobile-startup.png"
agent-browser snapshot -i > "$OUT/mobile-startup.snapshot.txt"
agent-browser console > "$OUT/mobile-startup.console.txt" 2>&1 || true
agent-browser errors > "$OUT/mobile-startup.errors.txt" 2>&1 || true

# Runtime errors must never be silently accepted as a successful UI check.
if grep -Eiq 'uncaught|exception|failed to load|webassembly|wasm|fatal|ERROR: String formatting error|ERROR: Invalid|ERROR: Parse Error|ERROR: SCRIPT ERROR' "$OUT"/*.console.txt "$OUT"/*.errors.txt; then
  echo "Browser runtime errors detected; inspect artifacts." >&2
  exit 1
fi

# ── Visual pixel assertions ──────────────────────────────────────────────────
# Requires Python 3 + Pillow (pip install Pillow).  Fails the job if any
# region shows ghost-text bleed-through or if the world backdrop never renders.
assert_png() {
  local png="$1" vw="$2" vh="$3" label="$4"
  python scripts/visual_assertions.py "$png" "$vw" "$vh" \
    || { echo "VISUAL ASSERTION FAILED: $label ($png)" >&2; return 1; }
}

# Desktop startup screenshot (full-width capture from GitHub Pages).
if [ -f "$OUT/startup.png" ]; then
  SW=$(python -c "from PIL import Image; img=Image.open('$OUT/startup.png'); print(img.size[0])" 2>/dev/null || echo 1280)
  SH=$(python -c "from PIL import Image; img=Image.open('$OUT/startup.png'); print(img.size[1])" 2>/dev/null || echo 720)
  assert_png "$OUT/startup.png" "$SW" "$SH" "desktop-startup" || exit 1
fi

# Opening-loop screenshot (after key presses, same viewport).
if [ -f "$OUT/opening-loop.png" ]; then
  OW=$(python -c "from PIL import Image; img=Image.open('$OUT/opening-loop.png'); print(img.size[0])" 2>/dev/null || echo 1280)
  OH=$(python -c "from PIL import Image; img=Image.open('$OUT/opening-loop.png'); print(img.size[1])" 2>/dev/null || echo 720)
  assert_png "$OUT/opening-loop.png" "$OW" "$OH" "opening-loop" || exit 1
fi

# Mobile phone-sized capture — runs the same mobile-specific assertions.
assert_png "$OUT/mobile-startup.png" 390 844 "mobile-startup" || exit 1

echo "Visual assertions passed. Artifacts are in $OUT."

# The phone screenshot is expected to be a real 390x844 capture, proving the
# browser actually exercised the compact layout rather than only desktop CSS.
if command -v file >/dev/null 2>&1 && ! file "$OUT/mobile-startup.png" | grep -q '390 x 844'; then
  echo "Mobile QA screenshot is not 390x844; compact-layout test did not run as expected." >&2
  exit 1
fi

echo "Browser QA completed successfully. Artifacts are in $OUT."
