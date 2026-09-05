#!/usr/bin/env bash
set -euo pipefail

URL="${RENEW_BROWSER_URL:-https://games-3lpvuxrii-ogs7.vercel.app/}"
OUT="${RENEW_BROWSER_OUTPUT:-artifacts/browser-qa}"
mkdir -p "$OUT"

agent-browser open "$URL"
agent-browser wait --load-state complete
agent-browser screenshot --full-page "$OUT/startup.png"
agent-browser snapshot -i > "$OUT/startup.snapshot.txt"
agent-browser console > "$OUT/startup.console.txt" || true
agent-browser errors > "$OUT/startup.errors.txt" || true

# Exercise the documented opening loop without assuming DOM selectors.
for key in i a r r r o n; do
  agent-browser press "$key" || true
  sleep 1
done

agent-browser screenshot --full-page "$OUT/opening-loop.png"
agent-browser snapshot -i > "$OUT/opening-loop.snapshot.txt"
agent-browser console > "$OUT/opening-loop.console.txt" || true
agent-browser errors > "$OUT/opening-loop.errors.txt" || true

# Capture a mobile-sized run as a second visual baseline.
agent-browser set viewport 390 844
agent-browser reload
agent-browser wait --load-state complete
agent-browser screenshot --full-page "$OUT/mobile-startup.png"
agent-browser snapshot -i > "$OUT/mobile-startup.snapshot.txt"
agent-browser console > "$OUT/mobile-startup.console.txt" || true
agent-browser errors > "$OUT/mobile-startup.errors.txt" || true

if grep -Eiq 'uncaught|exception|failed to load|webassembly|wasm|fatal' "$OUT"/*.console.txt "$OUT"/*.errors.txt; then
  echo "Browser runtime errors detected; inspect artifacts." >&2
  exit 1
fi

echo "Browser QA completed successfully. Artifacts are in $OUT."
