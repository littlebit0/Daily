# Agent Memory

This file is a handoff note for agents working on Daily. It records the current
2.x state, completed 2.x work, release status, and safe next steps. Do not add
OAuth client secrets, GitHub tokens, signing certificates, provisioning
profiles, keystore passwords, or private keys to this file.

Historical app-version notes below `2.0.0` were intentionally removed on
2026-06-06 at the user's request.

## Current State

- Repository: `littlebit0/Daily`
- Local macOS path currently used:
  `/Users/kimhwi/Documents/Codex/2026-05-26/littlebit0-daily-https-github-com-littlebit0`
- Windows/Android handoff path used by the previous agent:
  `C:\Users\com\Documents\New project\.codex-tools\portfolio_repos\Daily`
- Branch: `main`
- Current visible app version in repo: `2.0.4`
- Current `pubspec.yaml` version has no `+` suffix.
- Android `2.0.4` artifacts were built with build number `8` via build command
  only.
- Windows `2.0.4` builds must omit `--build-number` so Windows file/product
  versions stay exactly `2.0.4`.
- Latest known release tag: `v2.0.4`.
- Latest local pull on this Mac fast-forwarded to commit
  `be8c639 Release Daily 2.0.4`.

## Project Rules Snapshot

- Daily is a real production app. Do not use temporary workarounds, fake data,
  placeholders, hard-coded behavior, silent feature removals, or feature
  regressions.
- Keep Windows, Android, macOS, and iPhone/iOS behavior aligned for calendar,
  sync, notification, auth, and settings flows.
- Do not commit OAuth secrets, signing material, provisioning profiles,
  Android keystores, GitHub tokens, or private credentials.
- User-facing release names must not expose Flutter `+` build suffixes.
- Read `AGENTS.md` before changing behavior.

## Cross-Platform Sync Rule

- Windows, Android, iPhone/iOS, and macOS must all read and write the same
  Google Drive AppData file set.
- Production OAuth clients should point at the same Google Cloud project /
  Drive AppData namespace. Current iPhone-aligned target uses project number
  `234127810480`.
- Normal production sync uses the v2 Google Drive AppData model:
  - `daily-sync-v2-event-{eventId}.json` per event.
  - `daily-sync-v2-settings.json` for settings.
  - Date-only fields for all-day events.
  - Tombstones for deletes.
  - Event-only uploads for local create/update/delete changes.
- Do not bring back the old monolithic whole-backup file for normal sync.
- Create/update/delete events should perform backup-only event sync.
- App start, sign-in, resume, and best-effort background/exit paths may restore
  remote state as needed.
- A backup-then-restore sync must back up first, wait about 3 seconds, then
  restore.

## 2.0.0+ Work History

- `2.0.0` moved Windows/Android to the shared Google Drive AppData v2 model.
  Release coordination rule: after sync-schema-changing work, do not publish
  only one platform family. Windows/Android artifacts should be uploaded
  together with Mac/iPhone artifacts when the shared sync schema changes.
- Android package identity is `com.littlebit0.dailycalendar`.
- Android/Windows were aligned to the iPhone-source Google Drive AppData
  project `234127810480`.
- Android Google Sign-In default server client uses the 234-project web client.
  Do not revert Android to the old Firebase project metadata.
- Windows uses the 234 Desktop OAuth client and needs its client secret from a
  local environment/config source. Never commit or print that secret.
- All-day event sync was repaired to use date-only semantics so cross-device
  all-day events do not shift by one or two days.
- The active sync backend is Google Drive v2. Firebase/Auth/Firestore legacy
  Dart code and dependencies were later removed from the shared project.

## 2.0.1 Store Prep

- GitHub Actions were added for platform installer generation.
- The `v2.0.1` GitHub release published Android APK, macOS DMG, unsigned iOS
  IPA, Windows ZIP, and SHA-256 sums.
- iOS remains unsigned in CI because Apple signing assets are not stored in the
  repo.
- Daily app icons were generated for iOS, macOS, and Android.
- A Daily-branded iOS launch image was generated.
- `docs/STORE_SUBMISSION.md` documents Apple store submission status.
- Apple archive creation works, but App Store IPA export is blocked until the
  Apple account has a usable App Store Connect provider, Apple Distribution
  certificate, and App Store provisioning profile.

## 2.0.2 Sync/Login Optimization

- Login/connect no longer runs duplicated initial restore/full sync work.
- Connect flow should start listeners, flush pending local v2 event files, then
  restore v2 remote data.
- `startListeningOnly()` must not run an automatic initial restore.
- Pending queued/DB-pending event IDs are flushed on startup/background so local
  changes cannot survive restart unsynced.
- Local startup must not open a Google account chooser automatically.
- Logout should not run a full backup-all/full-restore. It should make a short
  pending-change flush attempt, then clear account state.
- Account/auth and Drive API waits should be bounded; user-driven approval
  waits must be separate from short network/token timeouts.
- Dependency cleanup removed inactive Firebase/Firestore code, stale Android
  `google-services.json`, unused direct dependencies, and refreshed Android
  Gradle/Kotlin versions.
- Mac/iPhone agents must run Flutter dependency generation on macOS/iOS before
  the next Apple build so stale native plugin registration is removed.

## 2.0.3 Google Login Follow-Up

- User-driven browser/account/Drive permission approval waits were separated
  from short app-controlled network/token timeouts.
- Browser/account/Drive approval can wait longer, while silent auth, token
  exchange, userinfo, Drive API requests, and logout remain bounded.
- This prevents Windows loopback OAuth or Android Drive approval from timing
  out while the user is still approving.
- Mac/iPhone agents should mirror this distinction if any platform-specific
  auth wrapper has its own timeout.

## 2.0.4 Windows/Android Release

- `v2.0.4` was published after a Windows/Android follow-up release.
- Android/Windows shared month `PageView` uses faster page settling and
  adjacent page preparation.
- Wide month detail loading keeps the panel mounted instead of showing a large
  spinner during range reload.
- Settings notification test layout moves the send button below text on compact
  widths.
- Google Drive local-mode copy was shortened for Korean line breaks.
- Locked categories show a disabled lock icon instead of an apparently tappable
  delete icon.
- Google login hardening verifies Drive authorization immediately after
  Settings > Google login.
- Prompt-driven header requests can recover from an empty local session by
  re-entering sign-in before failing.
- Windows release ZIP staging excludes `.pdb`, `.lib`, and `.exp` files.
- Android/Windows chronic issues such as emulator storage limits, debug/release
  signature mismatch, Windows Computer Use pipe availability, and Windows ZIP
  debug-symbol leakage are platform-only phenomena and should not be treated as
  macOS/iOS defects.

## 2.0.4 Verification Snapshot

- Windows/Android `flutter analyze --no-pub` passed.
- Windows/Android `flutter test --no-pub` passed with 31 tests.
- Android debug APK was rebuilt with test-only build number `8`.
- Smaller x86_64 split APK installed and launched on `emulator-5554`.
- Android monthly swipe was visually settled by the 450 ms capture.
- Settings showed compact notification layout and disabled lock icon for the
  locked holiday category.
- Windows release build succeeded with `daily.exe` file/product version
  `2.0.4`.
- Refreshed Windows ZIP was about 14.4 MB and contained no `.pdb/.lib/.exp`
  entries.
- Windows visual screenshot validation could not be completed in that Codex
  session because Computer Use screenshot capture was unavailable.

## 2.0.4 Release Artifacts

- `dist/release-2.0.4/daily-android-2.0.4.apk`
  - versionName: `2.0.4`
  - versionCode: `8`
  - SHA-256:
    `18080e2fedebbc48a2e685e8d7a529930125b26e795c1af31fc8732b72385681`
- `dist/release-2.0.4/daily-windows-2.0.4.zip`
  - SHA-256:
    `5f465ed937a2afd9079ff7c62b78a68890bc11686073261031fcf4d042faec87`
- `dist/release-2.0.4/SHA256SUMS.txt`

## Mac/iPhone Next Work

- 2026-06-06 Mac/iPhone pass after pulling `be8c639`:
  - Removed pre-`2.0.0` handoff history from this file at the user's request.
  - Ran `./tool/flutter.sh pub get`; macOS generated plugin registration now
    reflects the Firebase/Firestore dependency cleanup.
  - iOS generated plugin registration was already clean.
  - Removed stale Firebase/Firestore-related SwiftPM pins from iOS/macOS
    `Package.resolved` files. The remaining pins are the GoogleSignIn-required
    AppAuth/AppCheck/GTM/GoogleUtilities/Promises set.
  - Settings > Google login now verifies Drive authorization once, then runs
    the initial pending-change flush/restore without asking for another
    interactive Drive permission prompt. This reduces duplicated consent work
    during login.
  - Verification passed: `./tool/flutter.sh analyze --no-pub`,
    `./tool/flutter.sh test --no-pub` with 31 tests, and iOS release
    no-codesign build with `--build-name=2.0.4 --build-number=8`.
  - Connected iPhone `김휘의 iPhone`
    (`415EDAF7-A303-50FD-8344-351D7BF59153`) was installed with the latest
    development-signed `2.0.4 (8)` build and launched successfully.
  - `./tool/run_macos.sh` initially failed because stale `/tmp/daily-flutter-build`
    macOS output still contained removed Firebase-era SPM artifacts such as
    `absl.framework`. Removing `/tmp/daily-flutter-build/macos` and rerunning
    fixed the issue.
  - macOS debug app was rebuilt, signed with
    `Apple Development: kimhee8953@naver.com (739BC896PZ)`, installed to
    `~/Applications/Daily.app`, launched successfully, and the process was
    observed running.
  - macOS UX test found that closing the last Daily window could leave the
    process running with no visible window. `macos/Runner/AppDelegate.swift`
    now terminates after the last window closes so relaunch returns to a normal
    visible app window.
  - iOS/macOS UI smoke found the chat send button appeared actionable while the
    input was empty. `ChatInputBar` now listens to text changes and disables
    the send button until non-empty text is present.
  - macOS Google desktop OAuth token exchange failed after browser login. The
    auth service now reads macOS Desktop OAuth config from
    `~/Library/Application Support/Daily/google_desktop_oauth.json` (or the
    existing `GOOGLE_DESKTOP_OAUTH_CONFIG` override) and uses the config
    redirect host when starting loopback OAuth. A local user-only config file
    was installed on this Mac with `0600` permissions; it is not in git and
    must not be committed or printed because it contains the Desktop OAuth
    client secret.
  - After that macOS OAuth fix, Settings > Google login was re-tested on this
    Mac. Browser login returned to Daily, the account email was shown, and the
    sync status displayed completion instead of "Google 토큰 요청 실패".
  - Verification passed after the macOS OAuth fix:
    `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
    with 31 tests.
  - iPhone 17 simulator UX smoke resumed after interruption:
    - Home month view rendered correctly with Dynamic Island safe-area spacing,
      visible event chips, no text overlap, and disabled empty-input send
      button.
    - Typing into the bottom schedule input enabled the send button. Submitting
      text opened the confirmation bottom sheet with readable title/date/
      category/reminder copy and non-overlapping `취소`/`등록` actions.
    - Cancelling the sheet did not create a test event and returned to the
      calendar.
    - View-mode menu displayed `주`/`월`/`일` without clipping; week view
      switched successfully and showed stable day cards plus the bottom input
      area.
    - More menu displayed `빠른 보기`/`필터`/`검색`/`설정` without clipping.
      Search and Settings screens opened, and the account/sync section was
      readable with non-overlapping sync/logout/withdraw controls. Destructive
      account controls were not pressed.
    - No additional iPhone simulator UX defect was found that required a code
      change in this pass.
- User still needs to perform the actual iPhone Google login flow on the
  installed latest build and report whether it still stays on
  "계정 백업 확인 중".
- If iPhone still hangs, instrument the login path around:
  - `GoogleDriveAuthService.signIn()`
  - `authorizationHeaders(promptIfNecessary: true)`
  - `GoogleDriveSyncService.startListeningOnly()`
  - `syncPendingChangesNow(promptIfNecessary: true, restoreAfterBackup: true)`
- Confirm iOS/macOS do not duplicate Drive consent requests during sign-in.
- Confirm iOS/macOS do not run both listener startup restore and a separate full
  sync during connect.
- Confirm iOS/macOS keep user approval waits separate from short network/token
  waits.
- Verify same shared Flutter behavior on iOS/macOS where relevant:
  natural month swipe settling, stable month detail loading, compact settings
  layout, locked category affordance, and robust Google Drive authorization
  validation.
- Perform actual UX/UI demonstration testing on simulator/device where
  available and fix bugs, vulnerabilities, optimization needs, delays, and
  UX/UI issues found.

## Recommended Next Steps

1. Build and install the latest `2.0.4` code onto the connected iPhone.
2. Re-test Google login and identify the exact phase if the UI remains stuck.
3. Run `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
   after any shared-code changes.
4. Verify iOS simulator, connected iPhone, and macOS app against the same Google
   account.
5. If releasing a shared sync-affecting update, publish Windows/Android and
   Mac/iPhone artifacts together.
6. For App Store distribution, finish Apple Developer/App Store Connect provider
   activation and configure Apple Distribution signing/provisioning.

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`; do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, OAuth secrets, and private config files out of the repository.
- The current iPhone-first Drive sync target uses project number
  `234127810480` for iOS, Android, and Windows Desktop OAuth.
