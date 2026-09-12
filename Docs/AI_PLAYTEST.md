# RENEW Android AI Playtester

This repository includes a free, self-hosted Android playtesting pipeline in `.github/workflows/android-ai-playtest.yml`.

## What it does

The workflow builds an x86_64 debug APK specifically for the GitHub Actions Android emulator, installs it, launches `com.eghosa.renew`, records the screen, sends deterministic exploratory taps/swipes/back actions, captures screenshots, collects Android/Godot logs and rendering diagnostics, and generates both Markdown and JSON QA reports.

The runner currently detects:

- launch failures
- crashes, fatal signals, ANRs and Godot runtime error evidence
- blank/near-black screens
- repeated visual stagnation after interactions (possible softlock or unresponsive UI)
- unexpected foreground loss/navigation away from the game
- visual evidence for later UX review

Every run uploads:

- `report.md`
- `report.json`
- `session.mp4`
- `screenshots/`
- `logcat.txt`
- `gfxinfo.txt`
- the QA APK used by the emulator

High/critical findings can automatically create a GitHub issue. The report fingerprint is used to update the same open issue instead of creating duplicates.

## Run from GitHub

Open **Actions → RENEW Android AI Playtest → Run workflow**.

Inputs:

- `steps`: number of exploratory interactions (default 70)
- `seed`: deterministic random seed (default 20260912)
- `create_issue`: enable/disable automatic GitHub bug issue creation

The workflow also runs automatically on pushes to `main` when core game, asset, data, Android export, or playtester files change.

## Reproduce a failing run

Use the same seed printed in the report. Because the exploratory action stream is seeded, the same sequence can be replayed against the same game build.

Example on a machine with Android SDK/adb, Python and Pillow installed, with an emulator/device already running:

```bash
python tools/ai_playtest.py \
  --apk build/RENEW-debug.apk \
  --package com.eghosa.renew \
  --out build/ai-playtest-local \
  --steps 70 \
  --seed 20260912
```

## Scope and limitations

This system is intentionally free and deterministic. It does not pretend to understand the game like a human player. Godot renders most game UI inside one surface, so Android accessibility/UIAutomator cannot reliably identify every Godot control or read every label. The runner therefore combines seeded black-box interaction with screenshots, video, image-change checks, foreground state and runtime diagnostics.

The evidence artifacts are intended to complement the existing Godot unit/release tests. A future layer can add model-based screenshot review or game-specific scripted journeys without replacing this baseline.
