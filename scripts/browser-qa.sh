#!/usr/bin/env bash
set -euo pipefail

URL="${RENEW_BROWSER_URL:-https://games-3lpvuxrii-ogs7.vercel.app/}"
OUT="${RENEW_BROWSER_OUTPUT:-artifacts/browser-qa}"
mkdir -p "$OUT"

# Always leave diagnostics behind, even when navigation or rendering fails.
cleanup() {
  printf 'Browser QA exit code: %s\n' "$?" > "$OUT/qa-status.txt"
  agent-browser console > "$OUT/final.console.txt" 2>&1 || true
  agent-browser errors > "$OUT/final.errors.txt" 2>&1 || true
  agent-browser get url > "$OUT/final.url.txt" 2>&1 || true
}
trap cleanup EXIT

# Godot Web keeps network activity alive, so network-idle is not a valid readiness signal.
agent-browser open "$URL"
agent-browser wait --load load
agent-browser wait 5000
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

# Capture a mobile-sized run as a second visual baseline.
agent-browser set viewport 390 844
agent-browser reload
agent-browser wait --load load
agent-browser wait 5000
agent-browser screenshot --full "$OUT/mobile-startup.png"
agent-browser snapshot -i > "$OUT/mobile-startup.snapshot.txt"
agent-browser console > "$OUT/mobile-startup.console.txt" 2>&1 || true
agent-browser errors > "$OUT/mobile-startup.errors.txt" 2>&1 || true

if grep -Eiq 'uncaught|exception|failed to load|webassembly|wasm|fatal' "$OUT"/*.console.txt "$OUT"/*.errors.txt; then
  echo "Browser runtime errors detected; inspect artifacts." >&2
  exit 1
fi

echo "Browser QA completed successfully. Artifacts are in $OUT."
