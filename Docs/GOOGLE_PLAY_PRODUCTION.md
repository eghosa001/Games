# RESTORA Google Play production release

This repository is prepared around Godot 4.7.2 and a dedicated **Android Play Store** export preset.

## Technical release baseline

- package: `com.eghosa.renew`
- app name: `Restora`
- architecture: ARM64 enabled, ARMv7/x86 disabled
- minimum SDK: API 24
- target SDK: API 36 (Android 16)
- Play artifact: Android App Bundle (`.aab`)
- production export preset: `Android Play Store`
- version code: `1`
- version name: `1.0.0`
- renderer: OpenGL compatibility
- Android backup: disabled
- immersive/edge-to-edge: enabled
- Internet + network-state permissions: enabled so the production build can support opt-in ads once the provider SDK is installed

Google Play requires new mobile apps and app updates submitted from August 31, 2026 to target Android 16/API 36 or higher. Keep the target API at or above the current Play requirement before every release.

## Release signing

Never commit the release keystore, alias password or keystore password.

Godot supports release signing through the Android export settings or environment variables:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

Use the same production signing identity for all future updates. Store backups outside the repository. If Play App Signing is enabled, keep the upload key protected as well.

## Build a production AAB

The Android Play Store preset uses Gradle because Google Play distribution requires AAB and Android SDK integrations such as advertising/billing need a Gradle-capable Android project.

Install the matching Godot 4.7.2 export templates and the Android Gradle build template, then export without debug:

```text
godot --headless --path . --export-release "Android Play Store" build/Restora-release.aab
```

Do not upload an unsigned, debug-signed or test-key bundle to production.

## Versioning

For every Play upload:

1. increase `version/code` to a value higher than every version previously uploaded,
2. update `version/name` for the public release,
3. run all release tests,
4. export a new signed AAB.

Never reuse an old version code.

## Monetization activation

Monetization is intentionally disabled in source until real account-side configuration exists. Before enabling it:

1. create the Android app in AdMob using package `com.eghosa.renew`,
2. create a Rewarded ad unit,
3. configure Privacy & messaging / UMP in AdMob,
4. create the Premium subscription/product in Play Console,
5. integrate a compatible Godot Android provider for Google Mobile Ads + UMP + Play Billing,
6. make the provider satisfy the contract in `Docs/MONETIZATION.md`,
7. fill the real values in `config/monetization.json`,
8. validate test ads/license testers before production ads or purchases,
9. update Play Data safety based on the exact SDK versions actually included.

Do not use production ads during development testing when the SDK provides test-ad IDs or test-device mode.

## Store listing assets still required in Play Console

These are account/content assets and cannot safely be invented in source:

- app title/short description/full description
- app icon uploaded to Play Console
- phone/tablet screenshots
- feature graphic
- support contact details
- public privacy-policy URL
- category/tags
- content rating questionnaire
- target audience / age declarations
- ads declaration
- Data safety form
- app access declaration if any areas become account-gated
- Play Billing subscription base plan/offer details when Premium is activated

## Privacy requirements

The repository does not currently commit production AdMob IDs or a third-party ad SDK binary. Once AdMob is integrated, use UMP on every launch to refresh consent requirements and expose a privacy-options entry point where required. The public privacy policy and Play Data safety form must accurately reflect all data handled by advertising, billing, analytics, crash-reporting or account SDKs actually shipped.

## Device/release verification

Before moving from internal/closed testing to production, verify at least:

- clean install from Play-generated build,
- launch, save/load and resume after Android pause/background/kill,
- Android back behavior,
- touch targets and portrait/landscape policy on real phones,
- low-memory/background recovery,
- offline gameplay still works when monetization services are unavailable,
- rewarded ad cancellation grants nothing,
- rewarded completion grants exactly once,
- daily sponsored caps cannot be bypassed by reopening the app,
- Premium purchase/restore/revocation/expiry paths,
- consent form and privacy-options behavior in required regions,
- billing tests through Play license testers,
- no test ad IDs or debug flags in the production bundle,
- no release credentials, private keys or service-account files committed to Git.

## Release gate

The normal Android CI workflow exports and validates an installable **debug APK**. It does not prove that a production Play AAB is correctly signed because release credentials are intentionally not stored in the repository.

A Play upload candidate therefore requires all of the following on the exact candidate commit:

1. the repository release gate is green,
2. deep validation appropriate to the release has been completed,
3. a release-signed `Android Play Store` AAB has been exported with the protected upload key,
4. the resulting AAB has been tested through a Play testing track, and
5. the Play Console declarations and store metadata match the SDKs/features actually shipped.
