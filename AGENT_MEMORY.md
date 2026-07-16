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
- 2026-07-02 App Review response work:
  - Apple rejected iOS `2.0.5(10)` on 2026-06-25 for Guideline 5.1.2(i)
    because App Privacy metadata indicated data used for tracking, and for
    Guideline 4.8 because Google login appeared to be a primary account login
    without an equivalent login option.
  - Code was updated to clarify that Daily can be fully used without an
    account and that Google is only an optional Google Drive AppData backup/
    sync connection:
    - Welcome copy now says all calendar features work without an account.
    - Initial Google action now says `Google Drive 백업 복원`.
    - Settings action now says `Google Drive 연결`; disconnect/delete wording
      no longer presents this as Daily account login/withdrawal.
  - `docs/STORE_SUBMISSION.md` now includes App Review reply drafts for both
    5.1.2(i) and 4.8 plus the exact App Privacy label corrections.
  - `docs/PRIVACY_POLICY.md` now says optional Google Drive connection rather
    than optional Google sign-in.
  - Verification after these changes passed:
    `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
    with 31 tests.
  - App Store Connect still must be updated manually:
    - App Privacy: collected data can remain Email Address, User ID, and Other
      User Content for app functionality, linked to identity when Drive sync is
      enabled, but `Used for Tracking` must be `No`.
    - Reply to App Review explaining Daily has no primary account requirement;
      local mode is full-featured, and Google authorization is only optional
      Google Drive AppData backup/sync.
- 2026-07-02 iOS/macOS App Review UX smoke/debug continuation:
  - Shared code still had user-facing error/status strings that said
    `Google 로그인` or `다시 로그인` inside the auth/sync services. These could
    appear after failed Drive authorization and undermine the App Review 4.8
    explanation.
  - Updated `GoogleDriveAuthService` and `GoogleDriveSyncService` messages to
    describe the flow as `Google Drive 연결`, `권한 승인`, or `다시 연결`.
  - Fixed a desktop OAuth error wording bug where macOS token request failures
    could incorrectly say `Windows Google 로그인...`; desktop OAuth errors now
    use a platform label (`macOS`, `Windows`, or `데스크톱`).
  - Added a focused sync test to ensure missing Google auth headers show
    `Google Drive 연결이 필요합니다.` and do not issue Drive requests.
  - Verification passed after this continuation:
    `./tool/flutter.sh analyze --no-pub`,
    `./tool/flutter.sh test --no-pub`, and
    `./tool/flutter.sh test --no-pub test/core/sync/google_drive_sync_service_test.dart`.
    The full suite now has 32 tests.
  - macOS debug app was rebuilt and launched through `./tool/run_macos.sh`.
    It was signed with the local Apple Development identity and opened one
    visible `Daily` window from `~/Applications/Daily.app`. Calendar month
    view and Settings entry rendered correctly. No duplicate Daily process was
    left by the launcher.
  - iOS Simulator `iPhone 17 Pro Max` on iOS 26.5 was booted and ran the app.
    The first-run screen showed the corrected copy:
    account-free full calendar use and optional `Google Drive 백업 복원`.
    Local start entered the calendar, the More menu showed Settings, and
    Settings opened with normal notification/calendar controls.
  - iOS notification permission appeared after local start. The agent asked for
    explicit confirmation before pressing `허용` because it changes notification
    permission state. The prompt was not accepted by the agent.
  - Automated iOS GUI scrolling is limited in this environment: Computer Use
    currently exposes click/state but no drag/scroll tool, and `simctl ui` has
    no touch scroll command. Lower Settings sections were therefore confirmed
    through shared Flutter code and widget tests rather than iOS GUI scrolling
    in this pass.
- 2026-07-02 Android/Windows parity and handoff:
  - The user clarified that only Android/Windows-related remote changes should
    be considered, not a full pull/merge. `git fetch origin` was run and
    `git diff --name-status HEAD..origin/main -- android windows` showed no
    remote Android/Windows platform file changes to import.
  - Android and Windows platform files did not need code changes. The actual
    parity fixes are in shared Flutter auth/sync code and Android/Windows
    release docs:
    - User-facing auth/sync failures now say `Google Drive 연결`, `권한 승인`,
      or `다시 연결` instead of presenting the flow as a Daily account login.
    - Windows Desktop OAuth token/configuration errors now use the correct
      platform label and describe Google Drive connection failures.
    - Android Play submission copy now states that local mode is fully usable
      without an account and Google Drive AppData sync is optional.
    - Android release checklist now tests local start, optional Google Drive
      restore, connection disconnect choices, and Drive backup deletion instead
      of old logout/member-withdrawal wording.
    - Google Drive setup and progress docs now describe Android/Windows as the
      same optional Drive AppData v2 sync model used by iPhone/macOS.
  - Verified by search that the Android/Windows target docs and shared app code
    no longer contain the old `Google 로그인`, `회원탈퇴`, `Google login`,
    `Google Sign-In`, or `membership withdrawal` wording, except code symbols
    such as `GoogleSignInAccount` in implementation files.
  - Windows still needs a real Windows machine test after this commit:
    - build with `.\tool\flutter.ps1 build windows --release --no-pub`
    - launch the release app
    - confirm local mode starts without an account
    - confirm Google Drive connection opens the desktop OAuth browser flow
    - confirm invalid/missing Desktop OAuth secret errors show Google Drive
      connection wording, not Google login wording
    - confirm connect, manual sync, disconnect choice, and Drive backup deletion
      match Android/iPhone/macOS behavior.
  - Android still needs real-device or emulator smoke after this commit:
    - clean install the release/AAB-equivalent build
    - confirm local mode starts without an account
    - confirm optional Google Drive connection and v2 AppData restore
    - confirm create/update/delete sync, notification permission, disconnect
      choices, and Drive backup deletion.

- 2026-07-04 Sign in with Apple implementation for App Review 4.8:
  - Added real Sign in with Apple support for Apple platforms through
    `sign_in_with_apple` 8.1.0.
  - New shared auth files:
    - `lib/core/auth/apple_account.dart`
    - `lib/core/auth/apple_sign_in_service.dart`
  - Apple login is exposed on iOS/macOS only. The welcome screen now shows
    `Apple로 계속` above local start and optional Google Drive restore.
  - Apple sign-in requests only email and full name scopes, stores the returned
    local Apple user identifier plus optional email/name, and preserves the
    stored email/name on later Apple sign-ins because Apple only returns them
    on first authorization.
  - Settings now has an Apple login section on iOS/macOS. Apple logout removes
    only the Apple local session and keeps local events/settings. Local reset
    clears Apple login state too.
  - iOS and macOS native entitlements now include
    `com.apple.developer.applesignin = Default`, and both Xcode projects mark
    the Sign in with Apple capability.
  - iOS App Store IPA was built as `2.0.5(14)` and copied to:
    `dist/transporter-upload/Daily-iOS-Transporter-2.0.5-build14.ipa`
  - IPA verification:
    - bundle id: `com.littlebit0.daily`
    - version: `2.0.5`
    - build: `14`
    - signed entitlement includes
      `com.apple.developer.applesignin = Default`
    - SHA-256:
      `eda05bbb359449569e888524a539c387aa142c6f30da1896b506cecaec9cd7ba`
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub` (33 tests)
    - `./tool/flutter.sh build ios --simulator --debug --no-pub`
    - iOS Simulator `Daily Store 6.5` launched the fresh app and the first
      screen showed the new `Apple로 계속` button.
    - `./tool/flutter.sh build ipa --release --no-pub --build-name=2.0.5
      --build-number=14`
  - macOS Apple-login signing follow-up on 2026-07-04:
    - The first local macOS app installed to `/Users/kimhwi/Applications`
      was ad-hoc signed, so Apple login failed immediately with
      AuthenticationServices authorization error 1000 / AuthKit -7026.
    - The macOS Runner target was corrected to use Daily's Apple developer
      team `A6Y73X2ZLS` instead of the stale `739BC896PZ` team.
    - `xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration`
      registered this Mac and generated
      `Mac Team Provisioning Profile: com.littlebit0.daily.macos`.
    - A signed Debug build succeeded and was installed to
      `/Users/kimhwi/Applications/Daily.app`.
    - Installed macOS app verification:
      - bundle id: `com.littlebit0.daily.macos`
      - TeamIdentifier: `A6Y73X2ZLS`
      - signed entitlement includes
        `com.apple.developer.applesignin = Default`
    - The app process launched successfully from the signed install. The actual
      Apple ID approval step should be completed by the user; do not enter or
      submit Apple ID credentials on the user's behalf.

- 2026-07-04 macOS local data reset follow-up:
  - User reported an error when pressing Settings > `로컬 데이터 초기화`.
  - Screenshot inspection showed Settings stuck in a busy state with
    `Google Drive 연결` spinning and `로컬 데이터 초기화` disabled, not a visible
    error dialog.
  - macOS logs showed repeated native notification authorization failures from
    `com.littlebit0.daily.macos`.
  - Root cause found in shared Settings code: local reset awaited event reminder
    and morning briefing notification cancellation before clearing local data.
    On macOS, that cancellation can initialize native notifications and request
    authorization, so notification permission/signing state could block or fail
    local data reset.
  - Fix: local reset now attempts notification cleanup with a short bounded
    timeout and does not let notification cleanup failures stop local event,
    settings, Apple-session, or Google-account reset work.
  - Added widget coverage that intentionally makes notification cleanup throw
    during local reset and verifies the app still clears data and returns to the
    welcome screen.
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub test/widget_test.dart`
    - local unsigned macOS debug build via `xcodebuild` with signing disabled
    - rebuilt app installed to `/Users/kimhwi/Applications/Daily.app` and
      launched successfully
  - Destructive GUI reset was not pressed during this pass because it would
    delete the user's current local Daily data.

- 2026-07-04 Google Drive auth-cancel UX follow-up:
  - User requested no new upload/distribution artifacts until explicitly asked;
    only bug fixing, feature testing, and debug/simulator runs should continue.
  - Fixed a Google Drive login cancellation bug where starting Google Drive
    connection from an unlinked state and then closing/leaving the login window
    could leave the connect/restore button stuck in a loading-disabled state.
  - Desktop OAuth now has a real pending sign-in cancellation signal. When the
    app resumes while a desktop browser OAuth request is pending, the local
    callback server wait is canceled and the UI returns to an actionable state.
  - Welcome and Settings Google Drive flows now track stale connection attempts
    so a canceled or late-completing auth Future cannot re-disable the button or
    accidentally continue restore/sync work.
  - iOS native Google Sign-In cancellation remains handled by the plugin's
    canceled/error return path; the desktop resume-cancel hook is only used for
    desktop OAuth.
  - Added widget coverage for both first-run `Google Drive 백업 복원` and Settings
    `Google Drive 연결` buttons to verify they re-enable after the auth window is
    abandoned.
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub test/widget_test.dart`
    - `./tool/flutter.sh test --no-pub`
    - `./tool/flutter.sh build ios --simulator --debug --no-pub`
  - Installed and launched the debug simulator build on `Daily Store 6.5`
    (`2D0F9792-793F-4F86-95A9-02A7462060FA`). This was not an upload artifact.

- 2026-07-04 physical iPhone install follow-up:
  - User asked to install Daily on the physical iPhone, with no new upload
    artifacts.
  - The connected device is `김휘의 iPhone`, UDID
    `00008150-00012D5421F3401C`, CoreDevice id
    `415EDAF7-A303-50FD-8344-351D7BF59153`, running iOS `26.5.1`.
  - Fixed iOS project signing for physical-device builds by setting
    `DEVELOPMENT_TEAM = A6Y73X2ZLS` on the Runner Debug/Profile/Release build
    configurations in `ios/Runner.xcodeproj/project.pbxproj`.
  - `./tool/flutter.sh build ios --debug --no-pub` succeeded, and the resulting
    `build/ios/iphoneos/Runner.app` has the expected team id and
    `com.apple.developer.applesignin = Default` entitlement.
  - `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration
    Debug -destination id=00008150-00012D5421F3401C
    -allowProvisioningUpdates build` also succeeded.
  - Installation is currently blocked before app transfer: the iPhone is only
    visible over `localNetwork`/Wi-Fi and CoreDevice does not expose the
    `Install Application` capability (`com.apple.coredevice.feature.installapp`).
    `devicectl device install app` and `flutter install` both fail for that
    reason.
  - `xcrun xcdevice wait --usb --timeout=5 00008150-00012D5421F3401C` did not
    find the device over USB. Next retry should use a USB cable, keep the iPhone
    unlocked, trust the Mac if prompted, then rerun installation.
  - Follow-up wireless check: `xcrun xcdevice enable --timeout=15
    00008150-00012D5421F3401C` completed, but CoreDevice still did not expose
    `Install Application`. The current Wi-Fi/localNetwork connection can launch,
    uninstall, view screen, and transfer files, but cannot install app bundles.
  - Practical wireless install alternatives are TestFlight over-the-air or
    Ad Hoc/release-testing OTA distribution with a signed IPA and manifest.
    Both require a distributable build artifact, so do not use them until the
    user explicitly permits a new upload/distribution build.
  - After the user connected USB, `xcrun xcdevice wait --usb --timeout=20
    00008150-00012D5421F3401C` succeeded and CoreDevice reported
    `transportType: wired`, but `Install Application` was still absent.
  - Root cause now appears to be incomplete Xcode first-run platform setup:
    Xcode 26.6 is showing the "Select the components you want to get started
    with" dialog. iOS 26.5 platform support (`8.52 GB`) is selected but not
    installed. watchOS/tvOS/visionOS were deselected in the dialog so only iOS
    remains selected.
  - Do not click `Download & Install` through GUI without explicit user
    confirmation because it downloads/installs Xcode platform support.
  - Follow-up correction: Xcode first-run/platform support was ultimately not
    the blocker. Xcode 26.6 showed iOS 26.5 SDK installed, and
    `xcodebuild -checkFirstLaunchStatus` was clean. The real blocker was a
    stale CoreDevice/DDI pairing state after USB/wireless switching.
  - Tried `xcodebuild test`; this first exposed missing `DEVELOPMENT_TEAM` on
    `RunnerTests`, so `A6Y73X2ZLS` was added to RunnerTests Debug/Profile/Release
    build configurations. The next test attempt still failed at install with
    `Install Application not available`, confirming it was not an app build
    error.
  - Rebooted the physical iPhone with `devicectl device reboot`, waited for USB,
    then ran `devicectl manage pair --device 00008150-00012D5421F3401C`.
    Device moved from `unavailable` to `connected (no DDI)`.
  - Running `devicectl device info ddiServices` then re-enabled DDI; capability
    list finally included `Install Application`.
  - Installed `build/ios/iphoneos/Runner.app` successfully:
    bundle id `com.littlebit0.daily`, version `2.0.5`, bundle version `2.0.5`.
    Then launched the app on `김휘의 iPhone` via `devicectl device process launch`.

- 2026-07-04 version scheme update and iPhone reinstall:
  - User defined the new public version scheme: an App Store-style
    `2.0.5(14)` should be represented in-project as `2.5.14`; similarly
    `3.0.2(20)` becomes `3.2.20`.
  - Going forward, do not use a separate user-facing build-number suffix.
    Use the mapped version string itself as both the display version and bundle
    version where the platform allows it.
  - Updated common Flutter version to `2.5.14` in `pubspec.yaml`.
  - Updated Windows MSIX metadata to `2.5.14.0` and output name
    `daily-windows-2.5.14`.
  - Updated stale iOS/macOS RunnerTests Xcode `MARKETING_VERSION` and
    `CURRENT_PROJECT_VERSION` values to `2.5.14`.
  - Rebuilt iOS debug app successfully and verified
    `CFBundleShortVersionString = 2.5.14` and `CFBundleVersion = 2.5.14`.
  - Uninstalled the previous physical iPhone Daily install (`2.0.5/2.0.5`) and
    installed the new build. Device app listing confirms Daily
    `Version 2.5.14`, `Bundle Version 2.5.14`.
  - Launch attempt after install was denied because the physical iPhone was
    locked, not because of an app build failure.
  - Follow-up crash diagnosis: the installed iPhone app kept quitting because
    it was a Flutter `--debug` build installed directly with `devicectl`.
    Console log showed:
    `Cannot create a FlutterEngine instance in debug mode without Flutter
    tooling or Xcode.`
  - Fix was not app-code related: rebuilt iOS as a standalone launchable app
    with `./tool/flutter.sh build ios --release --no-pub`, then uninstalled the
    debug install and reinstalled `build/ios/iphoneos/Runner.app`.
  - Verified release install on the physical iPhone:
    - App listing: Daily `Version 2.5.14`, `Bundle Version 2.5.14`
    - Normal `devicectl device process launch` succeeded
    - Process list showed one live Runner process from the new install path
  - For future physical iPhone installs intended for normal Home Screen use,
    do not install `--debug` builds directly. Use release/profile or launch
    debug builds only through `flutter run`/Xcode.

- 2026-07-04 iOS 2.5.14 Transporter IPA and login screenshot:
  - User confirmed the iPhone build is now normal and requested Transporter IPA
    plus a login-screen screenshot using the App Store allowed size.
  - Built App Store IPA with `./tool/flutter.sh build ipa --release --no-pub`.
    Flutter validation reported:
    - Version Number: `2.5.14`
    - Build Number: `2.5.14`
    - Bundle Identifier: `com.littlebit0.daily`
  - Copied IPA to
    `dist/transporter-upload/Daily-iOS-Transporter-2.5.14.ipa`.
  - Verified IPA `Info.plist`:
    - `CFBundleShortVersionString = 2.5.14`
    - `CFBundleVersion = 2.5.14`
  - Rebuilt and installed simulator app on `Daily Store 6.5`
    (`2D0F9792-793F-4F86-95A9-02A7462060FA`) after uninstalling existing
    simulator app data.
  - Captured login/start screen at the App Store-accepted size:
    `dist/app-store-screenshots/ios-login/daily-login-1242x2688.png`
    (`1242 x 2688`).

- 2026-07-04 macOS month-grid drag range creation fix:
  - User reported that continuous/multi-day event creation by dragging on
    macOS did not work.
  - Root cause found in `CalendarMonthGrid`: desktop pointer drag selection and
    touch long-press selection shared the same `_rangeStart`/`_rangeEnd` state,
    so Flutter's `GestureDetector` long-press cancellation could clear the
    desktop drag range before the pointer-up event finished it.
  - Fix:
    - Desktop primary-button drag and touch long-press range selection now have
      separate active-state guards.
    - Long-press cancel no longer clears an active desktop drag range.
    - Pointer move no longer treats a missing primary-button bit as an immediate
      finish, because desktop test/engine move events can vary there while the
      pointer-up event is the reliable completion signal.
    - The month `PageView` no longer accepts desktop pointer drags, so dragging
      across the month grid is reserved for range creation instead of also
      trying to page months.
  - Added widget coverage in `test/features/calendar/calendar_month_grid_test.dart`
    for primary mouse drag from May 4 to May 8 creating a normalized date range.
  - Verification passed:
    - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub` (37 tests)
  - Local macOS test install:
    - Closed/replaced the existing `/Users/kimhwi/Applications/Daily.app`
      bundle without deleting app data.
    - Installed an Xcode development-signed Debug build from the current code.
    - Installed app verification: version `2.5.14`, bundle version `2.5.14`,
      bundle id `com.littlebit0.daily.macos`, TeamIdentifier `A6Y73X2ZLS`,
      Sign in with Apple entitlement present.
    - Launched `/Users/kimhwi/Applications/Daily.app`; process was running as
      `/Users/kimhwi/Applications/Daily.app/Contents/MacOS/Daily`.
  - GitHub issue #6 UI follow-up:
    - User approved applying the fix to both macOS and iOS.
    - The date-range selection UI now renders as a continuous row-level
      highlight instead of per-day separated selected cells.
    - The highlight is implemented in shared Flutter code, so macOS and iOS use
      the same behavior. It rounds only the true range start/end and uses flat
      edges when the selected range continues across week rows.
    - Added widget coverage that verifies a May 4-May 8 drag shows a single
      wide `selected-range-2026-5-4` highlight while still creating the correct
      normalized date range.
    - Verification passed:
      - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
      - `./tool/flutter.sh analyze --no-pub`
      - `./tool/flutter.sh test --no-pub` (37 tests)
      - `./tool/flutter.sh build ios --simulator --debug --no-pub`
      - Installed/launched the updated simulator app on `Daily Store 6.5`
        (`2D0F9792-793F-4F86-95A9-02A7462060FA`).
      - Rebuilt and installed the updated macOS app to
        `/Users/kimhwi/Applications/Daily.app`; verified version `2.5.14`,
        bundle version `2.5.14`, TeamIdentifier `A6Y73X2ZLS`, and Sign in with
        Apple entitlement, then launched it.
    - Follow-up after user verification:
      - User confirmed the range creation worked but reported that selected
        ranges over holidays still did not visibly change color.
      - Root cause: holiday day-cell backgrounds were opaque and covered the
        row-level selected-range highlight painted underneath them.
      - Fix: day cells inside an active range now keep their own selected/holiday
        backgrounds transparent so the continuous range highlight remains
        visible over holiday dates too.
      - Added widget coverage with a holiday on May 6 inside a May 4-May 8 drag
        range. The test verifies the wide selected-range highlight exists and
        the holiday cell background becomes transparent while the range is
        active.
      - Verification passed:
        - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
        - `./tool/flutter.sh analyze --no-pub`
        - `./tool/flutter.sh test --no-pub` (37 tests)
        - `./tool/flutter.sh build ios --simulator --debug --no-pub`
        - Installed/launched the updated simulator app on `Daily Store 6.5`
          (`2D0F9792-793F-4F86-95A9-02A7462060FA`).
        - Rebuilt and installed the updated macOS app to
          `/Users/kimhwi/Applications/Daily.app`; verified version `2.5.14`,
          bundle version `2.5.14`, TeamIdentifier `A6Y73X2ZLS`, Sign in with
          Apple entitlement, then launched it.
        - Built a signed iOS release app with
          `./tool/flutter.sh build ios --release --no-pub` and installed it on
          the connected physical iPhone `김휘의 iPhone`
          (`415EDAF7-A303-50FD-8344-351D7BF59153`).
        - Physical iPhone app listing confirmed Daily version `2.5.14`, bundle
          version `2.5.14`.
        - Launch from `devicectl` was denied only because the iPhone was locked;
          installation itself succeeded.
  - GitHub issue #4:
    - Issue title: `일정 시작 전 알림 건의`.
    - User approved implementing multiple start-before reminders and also asked
      that delivered push/local notifications must not disappear merely because
      Daily is opened.
    - Implemented multiple event reminders in shared Flutter code:
      - Added `CalendarEvent.reminderMinutesBeforeList` and
        `EventDraft.reminderMinutesBeforeList`.
      - Kept `reminderMinutesBefore` as a compatibility getter/input so old
        callers and old sync data still read as one selected reminder.
      - Added Drift schema v4 column `reminder_minutes_before_list` and migrated
        legacy `reminder_minutes_before` into `[value]`.
      - Google Drive v2 event JSON now writes `reminderMinutesBeforeList` while
        still writing/reading legacy `reminderMinutesBefore`.
      - Event editor now shows multi-select reminder chips plus custom reminder
        input instead of a single reminder dropdown.
      - Notification scheduling now creates one stable notification id per
        event/reminder-minute pair so selected reminders do not overwrite each
        other.
      - Cancel/reschedule paths pass old+new reminder minutes to remove stale
        pending reminders, including custom minute values.
    - Delivered-notification retention:
      - macOS native notification bridge now has `cancelPending`.
      - iOS AppDelegate now registers the same `daily/native_notifications`
        channel for `cancelPending`.
      - Daily cancellation/reschedule flows use pending-only cancellation on
        iOS/macOS, so already delivered notifications in Notification Center are
        left for the user to clear manually.
      - Android/Windows continue to use the plugin cancellation fallback because
        the current plugin API does not expose a pending-only cancellation path.
    - Verification passed:
      - `./tool/flutter.sh analyze --no-pub`
      - `./tool/flutter.sh test --no-pub test/features/events/event_editor_dialog_test.dart test/features/events/reminder_minutes_test.dart test/core/notifications/reminder_delivery_plan_test.dart test/features/chat/rule_based_schedule_parser_test.dart`
      - `./tool/flutter.sh test --no-pub` (41 tests)
      - `./tool/flutter.sh build ios --debug --simulator --no-pub`
      - `GOOGLE_DESKTOP_CLIENT_SECRET=... ./tool/flutter.sh build macos --debug --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...`
    - Needs manual UX smoke verification on macOS and iOS after install:
      - Create/edit an event with multiple reminders selected.
      - Confirm pending reminders are scheduled.
      - Confirm a delivered Daily notification remains in Notification Center
        after opening Daily until the user dismisses it.

## Recommended Next Steps

1. Upload `dist/transporter-upload/Daily-iOS-Transporter-2.0.5-build14.ipa`
   with Transporter and select build `2.0.5(14)` in App Store Connect.
2. In App Review Notes for build 14, state that Sign in with Apple was added:
   users can continue with Apple, use local-only mode, or optionally connect
   Google Drive AppData for backup/sync.
3. For macOS Apple-login verification, use the signed install at
   `/Users/kimhwi/Applications/Daily.app`. Do not replace it with an ad-hoc
   `CODE_SIGNING_ALLOWED=NO` build when testing Apple login.
4. Run `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
   after any shared-code changes.
5. If releasing a shared sync-affecting update, publish Windows/Android and
   Mac/iPhone artifacts together.

## Batch Verification Checklist

- GitHub issue #4 multiple reminders:
  - On macOS and iOS, create a normal timed event with multiple reminders
    selected, including at least one custom minute value.
  - Reopen/edit the event and confirm all selected reminder chips are preserved.
  - Confirm the event syncs between macOS and iOS with the same reminder list.
  - Wait for at least two reminder times and confirm separate OS Notification
    Center alerts are delivered.
  - Open Daily after a notification has arrived and confirm the delivered
    notification stays in Notification Center until the user dismisses it.
  - Change the event reminder list and confirm removed reminders no longer fire.
  - Delete the event and confirm future pending reminders for that event stop
    firing.
- GitHub issue #5 search/calendar UX:
  - Status: implementation is in place, but user explicitly asked to defer
    hands-on UX testing until all current issue fixes are complete.
  - On macOS and iOS, tap the search icon and confirm the search field opens
    inline above the calendar instead of navigating to a separate page.
  - Confirm the calendar is pushed down with an animation while the search panel
    is open.
  - Type a query and confirm full-calendar search results appear below the
    inline search field; selecting a result should move the calendar to that
    event's date and close the search panel.
  - Confirm the filter sheet still controls the current-view search/filter
    behavior separately from the inline full search.
  - On iOS, confirm month previous/next buttons are not shown and month movement
    is done by swiping the calendar.
  - On iOS, confirm search, filter, and settings buttons are visible directly in
    the header instead of hidden behind a more menu.
  - On macOS and iOS, confirm the persistent bottom chat input is gone.
  - On macOS and iOS, confirm the bottom bar has `빠른 보기`, `주/월/일`, and
    `LLM` controls.
  - Press `LLM` and confirm the existing LLM schedule input opens in a bottom
    sheet and can still create an event.
  - On macOS and iOS, confirm week and day event lists scroll when they contain
    more events than fit.
  - On macOS month view, confirm two-finger/trackpad or horizontal mouse wheel
    scrolling moves between months.
- GitHub issue #8 version display:
  - Status: implementation is in place, but hands-on settings UI verification
    is deferred until the current issue batch is ready for one test pass.
  - Open Settings on macOS and iOS and confirm an `앱 정보` section appears near
    the bottom.
  - Confirm the `Daily 버전` tile displays the app version as `2.5.14` or the
    current package version without a `+build` suffix.
  - Confirm the Settings page still opens normally if package metadata loading
    is slow or unavailable.
- GitHub issue #9 category editing:
  - Status: implementation is in place, but hands-on settings/category UX
    verification is deferred until the current issue batch is ready for one test
    pass.
  - Open Settings on macOS and iOS and confirm user-editable categories show an
    edit button next to the delete button.
  - Edit a custom category name and color, save it, and confirm the category row
    updates without creating a duplicate category.
  - Assign an event to that category before editing, then confirm the event still
    remains in the same category after the category label/color change.
  - Confirm the default/basic category can be edited if present, while the locked
    holiday category remains non-editable and non-deletable.
  - Confirm category changes are saved after closing and reopening Settings.
- GitHub issue #10 Google Drive session restore:
  - Status: implementation is in place, but hands-on iOS/macOS verification is
    deferred until the current issue batch is ready for one test pass.
  - On iOS, connect Google Drive, fully terminate Daily, reopen it, and confirm
    Settings still shows the connected Google account instead of local mode.
  - On iOS, after the same restart, create or edit an event and confirm Google
    Drive sync continues without reconnecting.
  - On macOS, repeat the restart/open Settings flow and confirm the connected
    Google account is restored in the UI when a saved desktop OAuth session
    exists.
  - Confirm Daily does not open the Google login/permission window during app
    start or Settings open; only the explicit connect/sync buttons may prompt.
- GitHub issue #11 iOS month calendar density:
  - Status: implementation is in place. Pro Max simulator GUI confirmed that
    the filter sheet no longer crashes when pressing `완료`; final 13 mini/17
    GUI re-check was blocked by Codex usage-limit rejection on `simctl launch`.
  - Compact month-grid event density now targets standard-mode visible event
    counts by screen width: iPhone 13 mini-class width shows 4 events per busy
    day when height allows, iPhone 17-class width shows 5, and Pro Max-class
    width shows 6.
  - If the actual row height is too small, the grid reduces visible lanes before
    overlap and keeps the `+N` overflow indicator.
  - The `+N` overflow indicator now reserves its own line below visible event
    chips instead of being anchored to the bottom of the day cell, preventing
    overlap on compact iPhone widths.
  - The bottom calendar bar now sizes its quick-view icon, view segmented
    control, and LLM icon from the available bar width so the left/right icon
    controls and center tabs scale consistently by device width.
  - The filter sheet, app-lock PIN dialog, number dialog, and category
    add/edit dialog no longer dispose `TextEditingController` instances from
    the outer async function before the input widget has left the tree. Category
    and PIN/number dialogs now own their controllers in stateful dialog widgets.
  - macOS uses the same width-based target curve, so wide windows keep
    proportionally higher event capacity without a separate platform fork.
  - Verified:
    - `./tool/flutter.sh analyze --no-pub` passed.
    - `./tool/flutter.sh test --no-pub` passed.
    - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart` passed after bottom bar proportional sizing.
    - iOS simulator debug build succeeded with `./tool/flutter.sh build ios --simulator --debug --no-pub`.
    - Pro Max simulator GUI confirmed filter `완료` closes without the previous Flutter red screen.
  - Manual verification needed:
    - On iOS and macOS Settings, open category add and edit dialogs, save/cancel
      them, and confirm no Flutter red screen appears.
    - On iOS and macOS Settings, enable app password/PIN and confirm save/cancel
      does not trigger the same red screen.
    - iPhone 13 mini-equivalent simulator: create 5+ events on one day and
      confirm 4 are visible if the layout height allows it, otherwise at least
      3 are visible without overlap.
    - iPhone 17-equivalent simulator: confirm 5 events are visible on one busy
      day with overflow for additional events.
    - iPhone Pro Max-equivalent simulator: confirm 6 events are visible if the
      layout allows it, otherwise 5 are visible without overlap.
    - On macOS, later resize the month view across narrow and wide widths and
      confirm visible event capacity scales smoothly with no text overlap.

## 2026-07-06 Follow-up Fixes

- Category edit propagation:
  - When a category label/color is edited in Settings, existing events using
    that category are now resaved through `EventCommandService` with the updated
    category and color value.
  - This should make calendar chips update immediately after category edit
    instead of waiting until each event is manually edited and saved.
  - Because the command service save path is used, affected events are marked
    pending for sync and event notifications are rescheduled normally.
- User-created holidays:
  - The event editor now allows selecting the `공휴일` category.
  - Events created or edited with the holiday category set `holiday: true` while
    remaining user-editable (`readOnly/systemEvent` are not set by this path).
  - Stored events whose category is `holiday` are mapped back as holiday events
    so they render with holiday styling in the calendar.
- Morning briefing notifications:
  - The previous fixed body `오늘 일정을 확인할 시간입니다.` was replaced with a
    schedule summary body.
  - Daily now schedules the next 14 morning briefing notifications separately,
    each with that date's event summary. If there are more than four events, the
    body ends with `외 N개 더 있습니다.`
  - Event create/update/delete reschedules the morning briefing when it is
    enabled so changed schedules refresh the notification body.
- Bottom calendar bar:
  - The center `주/월/일` segmented control now uses a larger width ratio and
    the side icon buttons are slightly smaller, reducing the empty-space feeling
    on iPhone and wider layouts.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub` passed.
- Manual verification still useful:
  - Edit a custom category color and confirm existing calendar chips repaint
    immediately.
  - Add a personal holiday event and confirm it appears as a holiday-colored,
    editable event.
  - Create more than four events on a future morning briefing date and confirm
    the notification body summarizes visible events plus `외 N개 더 있습니다.`
  - Check iPhone 13 mini / iPhone 17 / Pro Max bottom bar visual balance.

## 2026-07-07 UI and Category Follow-up

- Bottom calendar bar:
  - Replaced the separated icon/segmented controls with one integrated 5-item
    capsule: quick view, week, month, day, LLM.
  - The bar background now extends through the iOS safe-area bottom so the area
    below the controls no longer looks empty.
  - Follow-up: removed the gray capsule background because it looked detached
    from the white toolbar. The bar now uses a white native-toolbar treatment
    with only a soft selected state per item.
- Category edit propagation:
  - Reworked category usage updates to use a repository-level batch update
    before notification/sync follow-up work.
  - This should prevent visible one-by-one color changes and make the calendar
    show the completed color update when returning from Settings.
  - Custom category edits now normalize to the new label-based custom id so
    edited categories do not intermittently map back to the old color after
    reload/sync.
  - Hidden category filter ids are migrated when a category id changes.
- Month picker:
  - Month buttons now use one-line `FittedBox` labels so `1월`, `11월`, and
    `12월` do not wrap as separate number/text lines.
  - Follow-up: restored normal month label font size and widened the month
    picker dialog/content instead of scaling down `10월`/`11월`/`12월`.
- Time format:
  - Added a Settings option for 12h/24h time picker display.
  - Time picker dialogs in Settings now force the selected 12h/24h mode.
  - The setting is persisted locally and included in Drive settings sync.
	- Verification:
	  - `./tool/flutter.sh analyze --no-pub` passed.
	  - `./tool/flutter.sh test --no-pub` passed.
	  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed.
	  - Installed and launched on iPhone 17 simulator
	    `BF524643-403E-4212-ACB7-621E11279532`.

## 2026-07-07 Bottom Bar and Period Swipe Follow-up

- Bottom calendar bar:
  - The active `주/월/일` item background now fills the whole item cell from edge
    to edge inside the integrated bottom bar instead of leaving side gaps.
  - The bottom bar content was moved lower by letting the page body extend to
    the screen bottom and letting the bar own its bottom safe area.
  - The bottom bar content width was reduced slightly by increasing horizontal
    inset from 10 to 18.
  - Follow-up: removed the separate bottom padding/margin and increased the bar
    height instead, so the selected item background color extends through the
    lower bar area instead of leaving a blank bottom gap.
- Week/day navigation:
  - Weekly and daily calendar views now use PageView-based horizontal paging,
    matching the monthly calendar swipe animation style.
  - Swipe left moves to the next week/day and swipe right moves to the previous
    week/day with the same page physics used by monthly navigation.
  - The same visible-range update path is used for header navigation and body
    swipes so selected date and visible month stay in sync.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart` passed.
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed.
  - Installed and launched on iPhone 17 simulator
    `BF524643-403E-4212-ACB7-621E11279532`.
  - Screenshot check confirmed the bottom bar reaches the bottom edge without
    the previous visible bottom gap.
- Manual verification still useful:
  - On iPhone 17 simulator, check that the bottom bar is lower, slightly
    narrower, and that the active color reaches the full selected item bounds.
  - Switch to weekly and daily modes, then swipe left/right to confirm period
    navigation feels correct.

## 2026-07-07 Apple Login Drives Google Sync

- Apple login flow:
  - Starting with Apple now first attempts silent Google Drive session restore
    via `restorePreviousSignIn()`.
  - If a Google Drive account was already connected/restorable on the device,
    Daily starts Drive sync automatically without showing the Google sign-in
    account picker.
  - If no restorable Google Drive session exists, Apple login now continues into
    the interactive Google login/Drive permission flow automatically after a
    short sequencing delay. This preserves the requested first-login linkage
    while reducing iOS back-to-back OAuth URL callback collisions.
  - Onboarding is completed only after Apple sign-in and Google Drive connection
    both succeed, preventing an Apple-only state with no Drive sync.
  - If the Google Drive permission flow is cancelled after Apple sign-in, the
    user remains on the welcome screen with a message explaining that Google
    Drive connection is required to continue with Apple.
- Settings Apple connection:
  - Connecting Apple from Settings now first attempts silent Google Drive restore
    and opens the Google login/Drive connection flow automatically if there is
    no restorable Google session.
  - Settings text no longer says Google Drive sync is a separate Apple-login
    choice; it explains that Apple login uses Google Drive for backup/sync.
- Account UX:
  - The welcome screen no longer exposes a first-login `Google Drive backup
    restore` action. It now offers `Google로 계속`, which uses the same
    login-and-Drive-sync flow as Apple.
  - `연결 해제` was renamed to `로그아웃`; logout now syncs once, signs out
    Apple/Google local session state, and returns directly to the welcome screen.
  - `Drive 백업 삭제` was renamed to `회원탈퇴`; membership withdrawal deletes
    the Drive AppData backup when available, clears local data/settings, signs
    out Apple/Google, and returns to the welcome screen.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` passed.
  - Added regression coverage for Apple first login automatically continuing
    into Google login when no restorable Google session exists.

## 2026-07-07 iOS Google Auth Crash Follow-up

- Crash diagnosis:
  - The post-Apple Google link crash was a native iOS Google Sign-In/AppAuth URL
    callback abort (`OIDAuthorizationSession resumeExternalUserAgentFlowWithURL`),
    not a catchable Dart exception.
- iOS auth change:
  - User clarified the desired Google auth UI: it should feel like an in-app
    popup/sheet rising over Daily, not a full jump to the Safari app.
  - iOS Google Drive auth now uses a custom `ASWebAuthenticationSession` method
    channel (`daily/google_oauth`) instead of `google_sign_in_ios`.
  - iOS OAuth uses the app's reversed Google client id URL scheme and PKCE
    redirect URI `com.googleusercontent.apps...:/oauth2redirect/google`; it no
    longer uses localhost redirects or launches Safari via `open`.
  - The iOS custom auth session exchanges the returned authorization code in
    Dart through the existing Google token/userinfo path and stores the refresh
    token in the existing secure storage-backed Drive session keys.
  - Fixed a follow-up blocker where iOS was still treated like desktop browser
    OAuth for lifecycle cancellation. `canCancelPendingSignInOnResume` is now
    false on iOS so the app returning from the authentication sheet no longer
    cancels the in-progress Google Drive connection.
  - Added the iOS OAuth client id from `ios/Runner/GoogleService-Info.plist` as
    the default `GOOGLE_IOS_CLIENT_ID`, so Google/Apple-to-Google connection
    does not require an extra build define to open the auth sheet.
  - Added serialization around mobile Google sign-in so Apple-login-to-Google
    linking cannot start overlapping interactive Google auth requests.
  - `SceneDelegate` still swallows Google callback URLs so the registered
    `google_sign_in_ios` plugin cannot receive duplicate callbacks and crash
    with AppAuth `resumeExternalUserAgentFlowWithURL`.
- Settings separation:
  - Settings now displays `Google 계정` and `Google Drive 동기화` as separate
    rows so the signed-in Google account and Drive sync status are not conflated.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` passed.
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed after the
    `ASWebAuthenticationSession` auth path was added.
  - Installed and launched on iPhone 17 simulator with the new iOS auth path.

## 2026-07-08 iOS Google Auth Presentation Fix

- User-reported iPhone screenshot showed Google Drive linking failing with
  `com.apple.AuthenticationServices.WebAuthenticationSession error 3`.
- Root cause candidate fixed in native iOS code: `ASWebAuthenticationSession`
  could request its presentation anchor before a key window was discoverable,
  causing the session to fail immediately instead of showing the Google sheet.
- `DailyGoogleOAuthSession` now resolves a foreground visible window first and
  retains a clear fallback `UIWindow` tied to the active `UIWindowScene` when no
  key window is available. The fallback window is released when auth completes
  or fails.
- This keeps the Google auth flow as an in-app iOS authentication sheet over
  Daily rather than opening the standalone Safari app.

## 2026-07-08 Apple/Google Login State Fix

- User confirmed the iOS Google auth sheet opens normally, then reported account
  state issues after Apple login:
  - Apple login showed Google-button loading while entering the app.
  - Settings showed Google connected but Apple disconnected after relaunch.
  - After a normal logout, Apple login opened the Google popup again instead of
    silently reusing the previously linked Google Drive account.
- Behavior changed:
  - Apple onboarding now keeps the Apple button busy while it silently checks or
    connects Google Drive. The Google button shows a spinner only when the user
    explicitly chooses Google.
  - `AppleSignInService.refreshCurrentAccount()` no longer deletes the saved
    Daily Apple account marker when iOS reports a revoked/transient credential
    state. Apple account data is cleared only by explicit Daily logout or
    membership withdrawal.
  - Normal account logout no longer clears saved Google Drive auth tokens. It
    syncs pending changes, returns to the welcome screen, and preserves the
    saved Apple and Google Drive link markers so the next Apple/Google login can
    restore the paired account state automatically without prompting.
  - Membership withdrawal/local reset still clears local data, Apple account
    data, and Google Drive auth/session data when applicable.

## 2026-07-08 Reciprocal Apple/Google Link Persistence

- User requested the reciprocal path: if Apple was already linked, signing in
  through Google later should automatically keep Apple linked too.
- Normal `로그아웃` now preserves both saved Apple and Google Drive account link
  state and only marks onboarding incomplete to return to the welcome screen.
- `회원탈퇴` remains the destructive account-removal path and still clears Apple
  account data plus Google Drive auth/session data when applicable.
- Added widget coverage confirming Google logout returns to onboarding while
  preserving the saved Apple account marker for the next Google/Apple login.
- Follow-up UI cleanup: account settings now exposes a single unified
  `로그아웃` button for the whole account section. Apple and Google Drive rows keep
  their sign-in/sync actions, but no longer show separate logout buttons.

## 2026-07-08 Cross-Platform Parity Handoff

- macOS, Android, and Windows must be brought to the same account UX and sync
  policy as the latest iOS work before their next user-facing build:
  - Welcome screen should expose Apple where supported, local start, Google
    continue, and notification permission consistently with iOS wording.
  - Apple login, where supported, should first restore an existing Google Drive
    AppData session silently and open Google authorization only when no saved
    Drive session exists.
  - Google login should preserve an already linked Apple account marker, so
    either login path restores the paired account state.
  - Settings should show Google account and Google Drive sync as separate rows,
    but only one unified `로그아웃` button for the entire account section.
  - Normal `로그아웃` must sync pending changes and return to onboarding while
    preserving saved Apple/Google link state for future automatic restore.
  - `회원탈퇴` remains the only destructive account removal path and must clear
    local data/settings plus Apple/Google auth/session state and Drive backup
    where applicable.
  - iOS Google auth now uses an in-app `ASWebAuthenticationSession` sheet with a
    valid presentation anchor and retry handling. macOS should keep equivalent
    user-visible behavior with its supported auth mechanism; Android/Windows
    should keep the same account-state semantics even if their native auth UI is
    different.
- Required verification for macOS/Android/Windows agents:
  - Fresh install: Apple/Google/local onboarding paths.
  - Apple then Google link, app restart, settings account rows.
  - Logout then Apple login: Google Drive restores without a prompt when saved.
  - Logout then Google login: Apple marker remains linked when previously saved.
  - Membership withdrawal clears both account markers and Drive backup.
  - Manual sync and create/update/delete event sync still use v2 AppData files.

## 2026-07-08 Release 2.5.15 Preparation

- User approved recommended version `2.5.15`.
- Updated shared Flutter version and Windows MSIX metadata from `2.5.14` to
  `2.5.15`.
- Updated stale iOS/macOS Xcode test target marketing/build values to `2.5.15`.
- GitHub Release should upload only one IPA asset for this release, per user
  instruction.
- Prepare two local IPA copies after build:
  - Transporter/App Store Connect upload IPA.
  - Physical iPhone install/check IPA for user-side installation.
- App Store Connect notes to update:
  - Select the latest uploaded `2.5.15` iOS build.
  - Review notes should mention Apple and Google login are both available.
  - Google Drive access is only for Drive AppData Daily backup/sync.
  - Daily does not access normal Google Drive files.
  - Daily does not use IDFA, ads, data brokers, or cross-app/site tracking.

## 2026-07-08 Issue #15/#16 Release 2.5.16 Follow-up

- Issue #15 `애플 로그인 오류`:
  - Report: Apple login fails on a real iPhone when the IPA is installed through
    SideStore, showing only an unknown Apple login error.
  - Important limitation: SideStore/re-signed IPAs can lose the Sign in with
    Apple entitlement. Code cannot make native Apple Sign In succeed without the
    proper Apple entitlement in the installed app signature.
  - Fix: Daily now explains this case in the Apple unknown-auth error message
    and tells the user to use `Google로 계속` for SideStore builds or
    TestFlight/App Store builds for Apple login.
  - Regression test added for the SideStore/Google fallback message.
- Issue #16 `수정 분류 동기화 오류`:
  - Report: after moving to another iPhone, calendar event colors reflect an
    edited category, but the category color shown in Settings remains stale.
  - Fix: `GoogleDriveSyncService` now exposes a `settingsRevisionNotifier` and
    increments it when remote settings are restored. `_AppHome` listens for that
    signal and reloads `appSettingsProvider` from `SettingsRepository`, so
    Settings receives the restored category color immediately.
  - Regression test added to restore a remote category color and confirm both
    local settings storage and the revision notifier update.
- Version advanced to `2.5.16` instead of rewriting the already-pushed
  `v2.5.15` tag.

## 2026-07-08 Release 2.5.17 Retry / GitHub Actions Fix

- GitHub check after the `v2.5.16` push showed:
  - `v2.5.16` tag exists on GitHub.
  - GitHub Release object for `v2.5.16` was not created.
  - `Release Installers` failed because the Windows ZIP job failed at
    `flutter build windows --release --no-pub`.
  - Android and Apple jobs completed, but the final release publish job was
    skipped because Windows was in the `needs` list.
- Likely Windows failure cause: the project now uses user-facing versions like
  `2.5.16` without a `+build` suffix. Flutter leaves `FLUTTER_VERSION_BUILD`
  empty on Windows, but `Runner.rc` requires a numeric fourth version segment.
- Fix applied for Windows: `windows/runner/CMakeLists.txt` now defaults an empty
  `FLUTTER_VERSION_BUILD` to `FLUTTER_VERSION_PATCH`, preserving the user's
  no-`+` version convention while keeping Windows resource compilation valid.
- Release workflow changed from all-platform installers to an iOS-only IPA
  release workflow, matching the user's instruction that GitHub Release should
  upload only the IPA for this release.
- Version advanced to `2.5.17` for the retry instead of rewriting the failed
  `v2.5.16` tag.

## 2026-07-08 Release 2.5.17 Notes Rewrite

- User requested the GitHub Release note text be rewritten by referencing prior
  uploaded release notes.
- Added `docs/RELEASE_NOTES_2.5.17.md` using the older release-note structure:
  적용 범위, 변경 사항, 검증, 배포 파일, SHA-256, 남은 확인 사항.
- Updated `.github/workflows/release-installers.yml` to use
  `body_path: docs/RELEASE_NOTES_2.5.17.md` instead of the short inline release
  body.
- Important: the already-created GitHub Release `v2.5.17` still has the earlier
  short body unless it is edited through GitHub web/API or the workflow is
  manually dispatched with permissions that can update the existing release.

## 2026-07-12 App Review 2.6.0 Apple Login Fix / Maps Shortcut

- App Review rejected `2.5.17 (2.5.17)` on 2026-07-09 because `Apple로 계속`
  completed Apple authentication and then opened a Google login page, blocking
  review unless Google login was completed.
- Version advanced to `2.6.0` across shared Flutter metadata, iOS/macOS Xcode
  project values, Windows MSIX metadata, and README current-version notes.
- Fixed Apple login onboarding behavior:
  - `Apple로 계속` no longer opens Google sign-in interactively.
  - Apple login now completes local app entry even when no Google Drive session
    exists.
  - If a previous Google Drive session can be restored silently, Daily starts
    Google Drive sync without prompting.
  - If the silent restore fails or the stored session is missing, Daily stays in
    Apple/local mode and the user can connect Google Drive explicitly.
- Added Apple-to-Google link persistence in `SettingsRepository`:
  - `appleLinkedGoogleEmail`
  - `appleLinkedGoogleDisplayName`
  - normal logout preserves this link; `resetAll()`/회원탈퇴 clears it.
  - Explicit Google connection records the Google account when an Apple account
    is already saved.
- Settings Apple login flow was corrected the same way:
  - Apple login in Settings does not force-open Google login.
  - It only restores an existing Google session silently if available.
- Added one `지도 바로가기` action for events with a `location`:
  - Tapping it opens one bottom-sheet chooser.
  - Supported services: 카카오맵, 네이버지도, Apple 지도.
  - iOS `LSApplicationQueriesSchemes` now includes `kakaomap` and `nmap`.
  - Android manifest queries include `kakaomap` and `nmap`.
- Issue #16 follow-up:
  - Category add/edit/delete now performs a best-effort awaited `backupNow()`
    after local settings/event category updates so the remote settings file is
    less likely to lag behind event color updates on another device.
- Verification completed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
  - `./tool/flutter.sh build ipa --release --no-pub`
    - Archive validation: Version Number `2.6.0`, Build Number `2.6.0`,
      Bundle Identifier `com.littlebit0.daily`.
- Local 2.6.0 IPA copies:
  - `dist/release-2.6.0/daily-ios-2.6.0.ipa`
  - `dist/transporter-upload/Daily-iOS-Transporter-2.6.0.ipa`
  - `dist/device-install/Daily-iOS-Device-2.6.0.ipa`
  - SHA-256:
    `0b2e3fabbdfd7135c757fc697c6673c5466130927a4c0daff83697da65c5e82f`
- Still verify manually before App Store resubmission:
  - Fresh iPad/iPhone install: tap `Apple로 계속`; Google login must not appear.
  - Settings Apple login: Google login must not appear unless the user presses
    the explicit Google connect button.
  - With a previously connected Google account: Apple login should restore Drive
    sync silently when the Google session is still available.
  - Event with address/location: `지도 바로가기` bottom sheet should open and each
    map choice should launch or fall back correctly.
  - macOS/Windows/Android parity should be smoke-tested because shared Flutter
    account and event-detail code changed.

## 2026-07-15 macOS 2.6.0 Test Build

- The latest shared 2.6.0 Flutter code was built for macOS and installed at
  `~/Applications/Daily.app` for user testing.
- The previous Daily process was replaced and the new app was launched.
- Confirmed installed bundle version and build number are both `2.6.0`.
- Apple sign-in entitlement and macOS network entitlements remain present.
  The Apple/Google/local onboarding, saved Google Drive restoration, account
  settings, and location map chooser use shared Flutter code with iOS.
- User will perform interactive functional testing; do not continue UI actions
  unless specifically requested.

## 2026-07-15 Month Event Density Follow-up

- At the current macOS Daily window size (approximately `800 x 720`), month
  cells had enough vertical space for only one to three event flags even though
  the width-based density target allowed more.
- `CalendarMonthGrid` now renders five-week months in five rows rather than
  always reserving an empty sixth row. Six-week months remain six rows.
- This gives the current July desktop layout enough vertical space to preserve
  readable 13px event rows while showing four schedules. The `+N` overflow
  marker remains below the visible rows.
- Added a regression test for an `800 x 570` month-grid area, matching the
  current desktop calendar content height, which requires four visible events.
- Added a regression test confirming a five-week month does not render an
  empty sixth week.
- Verified with the latest installed macOS build: a day containing four
  schedules renders all four readable flags in the current window size.
- Verification passed:
  - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
  - `./tool/flutter.sh analyze --no-pub`

## 2026-07-15 Calendar Navigation Restoration

- Removed the iOS-style fixed bottom navigation bar from the shared calendar
  screen, including its LLM shortcut.
- Restored the previous header navigation pattern:
  - desktop-width screens show the `주 / 월 / 일` segmented view control in
    the header, together with range navigation and utility actions;
  - compact screens use the header's view-selection menu and more-actions
    menu, avoiding a bottom bar.
- The calendar body now receives the reclaimed bottom-bar height. The shared
  Flutter change applies to macOS and iOS.
- macOS visual check passed with the restored header controls visible.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart`

## 2026-07-15 macOS Google Drive Connection Cancellation Fix

- Root cause of the reported macOS Google Drive connection failure: the
  onboarding and Settings lifecycle observers treated a browser focus change
  as an aborted desktop OAuth flow. Daily then cancelled its loopback OAuth
  listener before Google could return the authorization callback.
- Removed all lifecycle-driven OAuth cancellation. A Google Drive connection
  now remains pending while the user completes browser authentication, even
  when the app becomes inactive and resumes.
- Added an explicit `연결 취소` action during a pending desktop Google Drive
  connection. This is the only in-app path that cancels the loopback OAuth
  listener, so users can deliberately recover without guessing at lifecycle
  timing.
- The shared Flutter behavior applies to macOS and Windows desktop OAuth
  flows. iOS/Android retain their platform-native Google authorization flow.
- Tests now verify inactive-to-resumed lifecycle transitions do not cancel a
  pending connection and that the explicit cancellation control does.

## 2026-07-15 Android and Windows Account-Flow Parity

- The latest shared account, onboarding, settings, Google Drive sync, and
  calendar behavior is applied to Android and Windows through Flutter shared
  code. No separate platform UI implementation is needed for these changes.
- Android follows the iOS/mobile pattern:
  - Google authorization uses the platform-native mobile flow.
  - The UI shows `Google 연결 중` while authorization is pending and does not
    expose a desktop-loopback cancellation control.
- Windows follows the macOS/desktop pattern:
  - Google authorization opens the system browser and waits for the loopback
    OAuth callback without lifecycle-driven automatic cancellation.
  - While it is pending, the user can use the explicit `연결 취소` control.
  - The desktop OAuth configuration lookup supports
    `%APPDATA%\\Daily\\google_desktop_oauth.json`,
    `%LOCALAPPDATA%\\Daily\\google_desktop_oauth.json`, or the
    `GOOGLE_DESKTOP_OAUTH_CONFIG` override. The JSON may contain a client
    secret and must remain outside Git.
- Shared verification passed on macOS:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- Android debug build was attempted but this Mac has no Android SDK configured
  (`ANDROID_HOME` unavailable), so a Windows/Android environment must still
  perform the following smoke checks before release.

### Android Verification Checklist

- [ ] Install a clean debug or release APK after removing any older Daily app.
- [ ] Start in `로컬로 시작`; create, edit, delete, and restart to confirm local
  events and settings persist without a Google account.
- [ ] Choose `Google로 계속`; complete Android's native Google account and Drive
  permission flow. While it is open, Daily must show `Google 연결 중`, must not
  expose `연결 취소`, and must not crash or remain permanently disabled after
  user cancellation.
- [ ] Confirm the connected email appears in Settings and that the first
  Google Drive AppData backup/restore completes.
- [ ] On a second device signed into the same Google account, create an event
  on one device and confirm the other device receives the v2 event file after
  sync/resume. Also verify an edit and deletion propagate correctly.
- [ ] Sign out, restart, and verify the intended saved Google session behavior
  is restored without an unwanted account-selection page. Confirm local-only
  mode remains usable when no Google account is connected.
- [ ] Check monthly, weekly, and daily calendar navigation; category color
  changes; holiday event selection; event address map chooser; scheduled event
  notification; and morning briefing in Android system notifications.

### Windows Verification Checklist

- [ ] Install/run a clean Windows build and confirm `Google로 계속` opens the
  system browser, not an embedded or blank web view.
- [ ] Complete browser Google sign-in and Drive AppData approval. Switching to
  the browser and back must not show `Google Drive 연결이 취소되었습니다.` before
  the OAuth callback finishes.
- [ ] During the pending browser flow, confirm `연결 취소` is visible and works
  only when the user deliberately presses it. Cancelling must re-enable
  `Google로 계속` and must not leave a blocked connection state.
- [ ] Confirm the connected email, initial Drive AppData backup/restore, and
  app restart token restoration. If a local desktop OAuth config is needed,
  verify it is stored outside Git at the documented APPDATA/LOCALAPPDATA path.
- [ ] Verify cross-device event create, edit, delete, all-day event date, and
  category/settings synchronization against the same Google Drive AppData
  account used by iOS/macOS/Android.
- [ ] Check local-only start, logout, account deletion/local reset, monthly
  calendar scrolling, weekly/daily navigation, address map chooser, event
  notifications, and morning briefing in the Windows notification center.
- [ ] Build a release executable or MSIX and confirm its displayed version is
  `2.6.0` with no Flutter `+` suffix.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`; do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, OAuth secrets, and private config files out of the repository.
- The current iPhone-first Drive sync target uses project number
  `234127810480` for iOS, Android, and Windows Desktop OAuth.

## 2026-07-17 2.5.17 Baseline Reset

- App source, platform configuration, release workflow, tests, and release
  documents were rolled back to the exact `v2.5.17` tracked tree on branch
  `Cottlebit/rollback-to-v2.5.17`.
- `AGENT_MEMORY.md` is intentionally preserved as the cross-agent handoff
  record and is not part of the product-source rollback.
- Reapply post-`2.5.17` work one item at a time. Explain and obtain user
  approval before any UI change.

## 2026-07-17 Daily Account Provider Linking

- Reapplied from the `v2.5.17` product baseline as the first approved item.
- Daily now stores one local `DailyAccount` identity with independently
  attached Apple and Google providers. A provider is attached only after its
  own sign-in succeeds; matching email addresses are never used to merge
  accounts.
- Apple sign-in no longer opens an interactive Google login page. Apple-only
  users enter Daily immediately.
- If the same stored Daily account already has a Google provider and its
  authorization can be restored silently on the device, Google Drive AppData
  sync resumes. A missing or expired Google session leaves Apple/local use
  available and does not show a Google login page.
- `Google로 계속` is now the explicit Google account sign-in path. It requests
  the existing Google Drive AppData scope during that authorization, then
  attaches the Google account to the current Daily account and starts sync.
- Legacy pre-Daily-account Apple/Google local state is migrated once on app
  start so existing local users retain their connected session behavior.
- Settings now distinguishes the Daily account, Apple login, Google login,
  and Google Drive sync status. This was an approved text/status-only UI
  adjustment; no calendar UI was changed.
- Verification passed on macOS:
  - `./tool/flutter.sh test --no-pub`
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh build ios --simulator --debug --no-pub`
- Remaining manual verification for iOS/macOS/Android/Windows:
  - Apple-only sign-in enters the calendar without any Google auth sheet.
  - On the same Daily account, explicitly sign in with Google, grant Drive
    AppData, restart, then sign in with Apple and confirm only silent Google
    restoration occurs.
  - With a missing/revoked Google session, Apple sign-in remains usable and
    Settings offers an explicit Google login action.
  - Confirm Google sign-in on each platform shows the native/system OAuth UI,
    obtains Drive AppData consent, and starts the v2 sync flow.
