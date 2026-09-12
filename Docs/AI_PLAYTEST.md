# RENEW Android AI Playtester

This repository includes a free, self-hosted Android playtesting pipeline in `.github/workflows/android-ai-playtest.yml`.

## What it does

The workflow builds an x86_64 debug APK specifically for the GitHub Actions Android emulator, installs it, launches `com.eghosa.renew`, records the screen, and runs a screenshot-guided exploratory agent.

Unlike the original random-only runner, the current agent analyzes the rendered screen after each action. It identifies visually salient regions, combines them with any Android accessibility/UIAutomator controls that Godot exposes, learns which tap regions actually cause useful screen changes, favors productive controls, avoids repeatedly dead areas, and mixes in swipes/back navigation to discover additional paths.

The runner detects or reports:

- launch failures
- crashes, fatal signals, ANRs and Godot runtime error evidence
- blank/near-black screens
- repeated interactions that produce no meaningful visual response
- probable softlocks and large non-responsive areas
- unexpected foreground loss/navigation away from the game
- very limited screen/state progression, indicating discoverability or playability problems
- visually overcrowded screens using screenshot edge-density heuristics
- low-contrast structured screens that may have mobile legibility problems
- number of unique visual states and transitions reached during the run
- which tap regions produced useful responses

## Evidence produced

Every run uploads:

- `report.md`
- `report.json`
- `session.mp4`
- `screenshots/`
- `ui-dumps/`
- `logcat.txt`
- `gfxinfo.txt`
- the QA APK used by the emulator

`report.json` includes the full action timeline, learned tap-region rewards, state-transition coverage, UX metrics, failure findings and deterministic seed.

High/critical findings can automatically create a GitHub issue. The report fingerprint is used to update the same open issue instead of creating duplicates.

## Run from GitHub

Open **Actions → RENEW Android AI Playtest → Run workflow**.

Inputs:

- `steps`: number of screenshot-guided exploratory actions (default 90)
- `seed`: deterministic random seed (default 20260912)
- `create_issue`: enable/disable automatic GitHub bug issue creation

The workflow also runs automatically on pushes to `main` when core game, asset, data, Android export, or playtester files change.

## How the free vision agent works

For each action cycle the runner:

1. captures the current game frame
2. calculates brightness, contrast, edge density, visual complexity and a perceptual state hash
3. divides the screenshot into regions and scores them for local structure/contrast
4. adds any clickable Android accessibility nodes exposed by the running app
5. chooses a target using its current reward history
6. taps, swipes or navigates Back
7. captures the resulting frame
8. measures whether the action caused a meaningful visual transition
9. rewards responsive targets and down-ranks repeated dead targets
10. records newly discovered visual states and transitions

If the agent encounters repeated dead interactions it tries an escape sequence instead of wasting the remainder of the session on one stuck screen.

This provides a lightweight feedback-driven player without any paid AI API, cloud vision service or external model account.

## Reproduce a failing run

Use the same seed printed in the report. The screenshot-guided choices are deterministic for the same build, emulator profile and visual state sequence.

Example on a machine with Android SDK/adb, Python and Pillow installed, with an emulator/device already running:

```bash
python tools/ai_playtest.py \
  --apk build/RENEW-debug.apk \
  --package com.eghosa.renew \
  --out build/ai-playtest-local \
  --steps 90 \
  --seed 20260912
```

## Reading the coverage result

Useful fields in `report.json` include:

- `coverage.unique_visual_states`: visually distinguishable states reached
- `coverage.unique_transitions`: distinct transitions between states
- `coverage.learned_tap_regions`: screen regions the agent attempted
- `coverage.positive_response_regions`: attempted regions that produced useful responses
- `timeline[].changed`: whether an action visibly affected the game
- `timeline[].novel_state`: whether the action discovered a previously unseen state
- `learned_regions`: adaptive reward history used to guide later taps

A run that executes many actions but finds almost no unique states is automatically flagged as a discoverability/playability risk.

## Scope and limitations

This system is intentionally free and runs entirely inside GitHub Actions. Its UX findings are heuristics, so visual-density or legibility warnings should be reviewed alongside the screenshots/video rather than treated as perfect accessibility measurements.

Godot renders much of the game inside one graphics surface, meaning Android accessibility/UIAutomator may expose few or no individual controls. The screenshot-feedback agent is specifically designed to keep exploring in that situation.

The pipeline complements the repository's Godot tests rather than replacing them. Game-specific journeys can also be added later for objectives such as "start a new game", "complete one turn", "open diplomacy", or "reach the first battle" while retaining this general exploratory layer.
