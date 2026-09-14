# RENEW Android Release Gate

## Automated in CI

The repository contains an Android export preset and Android export workflow.

- Godot: 4.7.2
- Output: `build/RENEW-debug.apk`
- Package: `com.eghosa.renew`
- ABI: ARM64 (`arm64-v8a`)
- Minimum Android SDK: 24
- Target Android SDK: 35
- Internet permission: disabled
- Network-state permissions: disabled

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

## Physical-device matrix

### Low-end Android

Verify:
- cold launch and first-run flow
- 320/360 px responsive layout where practical
- touch-only journey: Inspect → Acquire → Restore → Open Business → Hire → Buy Inputs → Produce → Price → Sell Goods → Profit/Loss
- active customer demand decreases after a sale and cannot be sold twice
- passive hourly income is visible after owning a passive asset
- five-minute passive settlement does not duplicate on pause/resume
- real calendar rollover advances daily costs/world systems without auto-producing or auto-selling core goods
- scrolling and WORLD tab
- sustained performance target: at least 30 FPS
- no crash, ANR, runaway memory growth, audio glitches, or thermal instability
- save/load completes in under 1 second

### Mid-range Android

Repeat the full touch journey and verify:
- stable 30+ FPS with normal effects/audio
- pause/resume preserves state
- backgrounding and returning does not duplicate passive settlement or active sales
- closing/reopening preserves passive timestamp, daily demand usage and calendar anchor
- offline passive catch-up never exceeds 24 hours
- save/load remains below 1 second

### High-end Android

Repeat the same journey and verify:
- visual/audio quality is stable at the highest practical device refresh/resolution
- no frame pacing regressions or rendering artifacts
- pause/resume, close/reopen, and autosave recovery remain deterministic

## Real-time lifecycle recovery test

1. Start a new game and create a distinctive state.
2. Make at least one active sale and note today's remaining demand.
3. Own at least one passive asset and note its hourly run rate.
4. Save, background and resume the app.
5. Confirm demand usage and the passive settlement clock were not reset or duplicated.
6. Force-close and reopen RENEW.
7. Confirm the latest save restores the same real-time state.
8. If enough real time elapsed, confirm only the elapsed passive amount is credited.
9. Confirm offline catch-up is capped at 24 hours.
10. On a real date rollover, confirm wages/debt/rivals/events/research progress advance while core production and sales remain player-controlled.

## Internet / analytics verification

RENEW currently has no network analytics implementation in `scripts/`, so the Android preset explicitly requests **no Internet permission**. This is the preferred privacy/minimal-permission configuration until a real analytics provider is intentionally added.

If analytics is added later, document the provider and endpoint, add only required permissions, make telemetry non-blocking, and update store/privacy disclosures.

## Release status

Automated export/configuration can be validated in CI. Physical low-, mid- and high-end Android testing must still be performed on real devices before declaring the Android release gate complete.
