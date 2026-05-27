# Agent Memory

This file is a handoff note for the next agent working on Daily. It records the
current state, completed work, changed areas, release status, and safe next
steps. Do not add OAuth client secrets, GitHub tokens, signing certificates, or
keystore passwords to this file.

## Current State

- Repository: `littlebit0/Daily`
- Local path used for this work:
  `/Users/kimhwi/Documents/Codex/2026-05-26/littlebit0-daily-https-github-com-littlebit0`
- Branch: `main`
- Latest release work commit before this handoff:
  `964de71742adfc7dd3ea4babd2d57f3b80585874`
- Release tag pushed to GitHub: `v1.1.0+1`
- GitHub SSH authentication was configured and verified for user `littlebit0`.
- GitHub CLI authentication was completed with `repo` scope in a temporary
  config directory.

## Completed Work

- Pulled and analyzed the Daily Flutter project.
- Implemented and verified iOS/macOS Google login support.
- Stabilized macOS Desktop OAuth login flow.
- Added iOS URL scheme and client ID configuration for Google login.
- Fixed local-mode data reset behavior when keychain entitlement is unavailable.
- Split local account reset behavior from Google account withdrawal behavior.
- Changed logout behavior so it asks the user before signing out:
  - Continue locally with existing data.
  - Sync one last time, sign out, and return to the welcome screen.
- Updated tests around onboarding, settings, logout, local reset, and account
  deletion flows.
- Added/updated Apple build documentation and Swift Package Manager lock files.
- Built and verified macOS and iOS release artifacts.

## Main Files Changed In Release Work

- `.gitignore`
- `PROJECT_ANALYSIS.md`
- `README.md`
- `analysis_options.yaml`
- `docs/APPLE_BUILD_SETUP.md`
- `docs/GOOGLE_DRIVE_SYNC_SETUP.md`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/Info.plist`
- `lib/app/daily_app.dart`
- `lib/core/settings/settings_repository.dart`
- `lib/core/sync/google_drive_auth_service.dart`
- `lib/features/onboarding/presentation/welcome_page.dart`
- `lib/features/settings/presentation/settings_page.dart`
- `macos/Runner.xcodeproj/project.pbxproj`
- `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `macos/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/GoogleService-Info.plist`
- `macos/Runner/Info.plist`
- `macos/Runner/Release.entitlements`
- `pubspec.yaml`
- `pubspec.lock`
- `test/widget_test.dart`
- `tool/flutter.sh`

## Verification Completed

- `./tool/flutter.sh analyze` passed.
- `./tool/flutter.sh test` passed.
- macOS release build completed.
- macOS app code-sign verification passed for the local build.
- macOS DMG verification with `hdiutil verify` passed.
- iOS release build completed with `--no-codesign`.
- iOS unsigned IPA ZIP structure check passed.

## Release Artifacts

- macOS DMG:
  `dist/daily-macos-1.1.0+1.dmg`
- iOS unsigned IPA:
  `dist/daily-ios-1.1.0+1-unsigned.ipa`

SHA-256:

- macOS DMG:
  `0dcb4a1bdc3315b91c6b3c89c2e507333613d200b3b5f41cf112b783de6d862d`
- iOS unsigned IPA:
  `a5668c2401564589f48cbb0edbd97e88b56f048cd75861a7f34a8d29e0345c0d`

Important caveat: the iOS IPA is unsigned. Actual device installation,
TestFlight, or App Store distribution still requires Apple Developer signing.

## GitHub Release Status

- A draft GitHub release exists for tag `v1.1.0+1`.
- Title: `Daily 1.1.0+1`
- Uploaded assets:
  - `daily-macos-1.1.0+1.dmg`
  - `daily-ios-1.1.0+1-unsigned.ipa`
- The release is still a draft. The user must explicitly confirm before it is
  published as a public release.
- Expected public URL after publishing:
  `https://github.com/littlebit0/Daily/releases/tag/v1.1.0+1`

## Known Local Workspace Notes

These untracked local files existed during handoff and were intentionally not
staged:

- `.flutter-plugins-dependencies 2`
- `ios/Flutter/Generated 2.xcconfig`
- `ios/Flutter/flutter_export_environment 2.sh`

They look like accidental duplicate/generated files and should be reviewed or
removed only after confirming they are not user-created work.

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`. Do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, and OAuth secrets out of the repository.
- Google project number currently referenced by project docs:
  `234127810480`.

## Recommended Next Steps

1. If the user confirms, publish the draft GitHub release for `v1.1.0+1`.
2. Clean or ignore the duplicate generated Flutter files after checking they
   are not needed.
3. Continue the pending design task: redesign Daily with an Apple-like visual
   language and apply it consistently across iOS, macOS, Android, and Windows.
4. After design changes, run `./tool/flutter.sh analyze` and
   `./tool/flutter.sh test`.
5. For release-quality iOS distribution, configure Apple Developer signing and
   create a signed IPA or TestFlight upload.
