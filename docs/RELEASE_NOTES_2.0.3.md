# Daily 2.0.3 Release Notes

## Scope

This update is for the Android and Windows builds only. macOS and iOS artifacts
are not rebuilt in this Windows/Android pass.

## Changes

- Fixed the month grid layout when lunar dates are visible.
  - The solar day number and lunar label now share a fixed header row.
  - Today's highlighted date no longer shifts vertically compared with normal
    dates.
  - Event span flags start closer to the day header to reduce wasted vertical
    space.
- Added persistent repository agent rules in `AGENTS.md`.
- Removed inactive Firebase/Auth/Firestore code and dependencies from the
  Windows/Android shared Flutter project.
- Removed stale Android Firebase metadata from the old `424765276744` project.
- Removed unused direct dependencies and made the native SQLite bundle explicit.
- Updated `flutter_secure_storage` to `10.3.1`.
- Updated Android Gradle Plugin to `8.13.2` and Kotlin to `2.3.21`.
- Migrated Android Kotlin JVM target configuration to the Kotlin
  `compilerOptions` DSL.
- Fixed Google login approval timeouts on Android and Windows.
  - User-driven browser/account/Drive permission approval can now wait up to 2
    minutes.
  - Silent auth, token exchange, userinfo, Drive API requests, and logout remain
    bounded at 10 seconds or less.

## Verification

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android debug APK build with `--build-name=2.0.3 --build-number=7`
- Android install/update, launch, and fatal-log smoke check
- Windows debug build with `--build-name=2.0.3` so Windows file/product
  versions do not include a `+` suffix.
- Windows relaunch smoke check

## Artifacts

- `daily-android-2.0.3.apk`
- `daily-windows-2.0.3.zip`
- Android package: `com.littlebit0.dailycalendar`
- Android versionName: `2.0.3`
- Android versionCode: `7`
- Windows product/MSIX version: `2.0.3.0`

SHA-256:

- `daily-android-2.0.3.apk`:
  `a9a73c94065658846cb351aa642c6afd7544d01ffba8bb8ff664ac73ba69de63`
- `daily-windows-2.0.3.zip`:
  `e308bc9fb50b33834a2ea7af951bf17aefb179df0cd29330c90143a5b8771a6e`
