# RENEW Android Release Gate

## Automated in CI

The repository now contains a reproducible Android export preset and an Android export workflow.

- Godot: 4.7.2
- Output: `build/RENEW-debug.apk`
- Package: `com.eghosa.renew`
- ABI: ARM64 (`arm64-v8a`)
- Minimum Android SDK: 24
- Target Android SDK: 35
- Internet permission: disabled
- Network-state permissions: disabled
- APK is uploaded as the `RENEW-Android-debug` CI artifact

The debug APK is intended for device QA. A signed store/release build still requires a release keystore and final store signing configuration; secrets must never be committed to the repository.

## Build a debug APK locally

Requirements:
- Godot `4.7.2` executable at the repository root
- Android SDK with platform `android-35` and build tools installed
- Godot `4.7.2` export templates installed at `~/.local/share/godot/export_templates/4.7.2.stable`

Set the SDK path and export:

```sh
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT="$ANDROID_HOME"
./Godot_v4.7.2-stable_linux.x86_64 --headless --path . --export-debug "Android" build/RENEW-debug.apk
```

Verify the result:

```sh
test -s build/RENEW-debug.apk
sha256sum build/RENEW-debug.apk
$ANDROID_HOME/build-tools/35.0.1/apksigner verify --verbose build/RENEW-debug.apk
```

The portable preset intentionally leaves debug keystore fields empty. Godot supplies the debug signing configuration; release keystores belong outside the repository.

## Build through GitHub Actions

Push changes affecting `project.godot`, `export_presets.cfg`, `Assets/`, `scenes/`, or `scripts/` to `main`, or start **RENEW Android Export** manually with `workflow_dispatch`. The workflow installs the Android SDK and matching Godot templates, exports `build/RENEW-debug.apk`, and uploads it as the `RENEW-Android-debug` artifact.

## Physical-device matrix

### Low-end Android

Verify:
- cold launch and first-run flow
- 320/360 px responsive layout where practical
- touch-only journey: Inspect → Acquire → Restore → Open Business → Hire → Buy Inputs → Produce → Price → End Day → Profit/Loss
- scrolling and WORLD tab
- sustained performance target: at least 30 FPS
- no crash, ANR, runaway memory growth, audio glitches, or thermal instability
- save/load completes in under 1 second

### Mid-range Android

Repeat the full touch journey and verify:
- stable 30+ FPS with normal effects/audio
- pause/resume preserves state
- backgrounding and returning does not duplicate actions or advance the game unexpectedly
- closing/reopening restores the latest autosave
- save/load remains below 1 second

### High-end Android

Repeat the same journey and verify:
- visual/audio quality is stable at the highest practical device refresh/resolution
- no frame pacing regressions or rendering artifacts
- pause/resume, close/reopen, and autosave recovery remain deterministic

## Lifecycle recovery test

1. Start a new game.
2. Make a distinctive state change that is visible after reload.
3. Trigger a save/autosave.
4. Pause/background the app and resume.
5. Confirm the state is unchanged and no action fires twice.
6. Force-close the app.
7. Reopen RENEW.
8. Confirm the latest autosave is recovered.
9. Load a known save and confirm the same state is restored.

## Internet / analytics verification

RENEW currently has no network analytics implementation in `scripts/`, so the Android preset explicitly requests **no Internet permission**. This is the preferred privacy/minimal-permission configuration until a real analytics provider is intentionally added.

If analytics is added later:
- document the provider and endpoint
- add only the permissions it actually requires
- make telemetry non-blocking and failure-tolerant
- never prevent gameplay when analytics/network access fails
- update the Android release regression test and privacy/store disclosures

## Release status

Automated export/configuration can be validated in CI. Physical low-, mid-, and high-end Android testing must still be performed on real devices before declaring the Android release gate complete.
