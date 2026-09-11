# RENEW — Android Play Release Runbook

This is the canonical runbook for producing a Google Play upload artifact from the repository.

## Release artifact

The production preset is `Android Release` in `export_presets.cfg`.

It produces:

- `build/RENEW-release.aab`
- ARM64 (`arm64-v8a`)
- Gradle release build
- package ID `com.eghosa.renew`
- Android target SDK 36

The ordinary `Android` preset remains the installable debug APK used by CI and device smoke testing.

## Signing secrets

Never commit the release keystore or passwords. The repository ignores `.release-secrets/`, `*.keystore`, and `*.jks`.

Configure these GitHub Actions repository secrets before producing a store artifact:

- `ANDROID_RELEASE_KEYSTORE_BASE64` — base64-encoded release keystore bytes
- `ANDROID_RELEASE_KEYSTORE_USER` — release key alias
- `ANDROID_RELEASE_KEYSTORE_PASSWORD` — keystore/key password

Godot currently requires the release keystore password and key password to match.

## Versioning

Before every Play release:

1. Increase `version/code` in the `Android Release` preset. It must be strictly greater than every version code already uploaded to Play Console.
2. Update `version/name` to the public version, for example `1.0.0`, `1.0.1`, or `1.1.0`.
3. Commit the version change and run the complete release gate on that exact commit.

## Build workflow

Workflow: `.github/workflows/android-release.yml` (`RENEW Android Play Release`).

It can be run manually or by pushing a `v*` tag. It:

1. installs Java 17 and the Android 16 / API 36 toolchain;
2. installs Godot 4.7.2 and matching export templates;
3. validates the Android release configuration;
4. runs release smoke and full new-game-flow gates;
5. installs the Godot Gradle Android build template;
6. reconstructs the release keystore from GitHub Secrets;
7. exports a signed AAB;
8. uploads `RENEW-Android-Play-release` as a workflow artifact; and
9. removes temporary signing material even if the build fails.

## Release acceptance

Do not upload an AAB to production unless all of these are true for the same release commit:

- `RENEW Release Gate` is green.
- The signed AAB workflow is green.
- The AAB version code/name are correct.
- Physical Android device QA has passed.
- Save/load, background/resume, force-close recovery, touch controls, frame pacing, thermals, and battery behavior have been checked on real devices.
- Store listing, screenshots, content rating, privacy/data-safety declarations, and support information are complete.

## Security rules

- Never print keystore bytes or passwords in workflow logs.
- Never commit a release keystore.
- Keep a secure offline backup of the keystore and credentials.
- Do not replace the signing key after the app is published unless using the official Play App Signing key-rotation/recovery process.
