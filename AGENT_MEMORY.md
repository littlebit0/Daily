# Agent Memory

This file is a handoff note for the next agent working on Daily. It records the
current state, completed work, changed areas, release status, and safe next
steps. Do not add OAuth client secrets, GitHub tokens, signing certificates, or
keystore passwords to this file.

## Current State

- Repository: `littlebit0/Daily`
- Local path used for this work:
  `C:\Users\com\Documents\New project\.codex-tools\portfolio_repos\Daily`
- Branch: `main`
- Current visible app version in repo:
  `2.0.4`
- Current internal build number:
  no `+` suffix in `pubspec.yaml`; Android 2.0.4 artifacts are built with build
  number `8` via build command only. Windows 2.0.4 builds must omit
  `--build-number` so Windows file/product versions stay `2.0.4` without a `+`
  suffix.
- Latest release work commit before this handoff:
  `e6be3ba Release Daily 2.0.1 installers`
- Release tag published:
  `v2.0.4` after the Windows/Android 2.0.4 follow-up release.
- GitHub SSH authentication was configured and verified for user `littlebit0`.
- GitHub CLI authentication was completed with `repo` scope in a temporary
  config directory.
- Windows/Android verification on 2026-06-01 in
  `C:\Users\com\Documents\New project\.codex-tools\portfolio_repos\Daily`
  found and fixed two regressions after the macOS-side handoff:
  pending local event changes could survive restart without being uploaded if
  the delayed event timer had not fired, and Android local start could open a
  Google account chooser because mobile lightweight auth ran during app
  initialization. The fix flushes queued/DB-pending event IDs through v2
  event-file backup on startup/background and only enters mobile Google auth
  from explicit Google actions. Verification passed: `flutter analyze --no-pub`,
  `flutter test --no-pub`, Android debug APK install/run on `Daily_API_35`,
  and Windows debug build/run.
- Windows/Android verification on 2026-06-03 addressed the latest reported
  issues except the two items the user explicitly excluded: the wide empty
  month detail panel when no date events exist, and missing accessibility
  labels on the bottom event input / Gemini API key input. Changes made:
  Android/Windows shared month `PageView` now uses a faster page-settling
  spring and implicit adjacent page preparation, so a horizontal monthly swipe
  no longer remains half-settled for seconds; wide month detail loading now
  keeps the details panel mounted instead of showing a large spinner during
  range reload; settings notification test layout moves the send button below
  text on compact widths; Google Drive local-mode copy was shortened to avoid
  awkward Korean line breaks; locked categories now show a disabled lock icon
  instead of an apparently tappable delete icon. Google login hardening:
  mobile and desktop user approval waits remain separate from short
  silent/network timeouts, explicit Drive authorization is verified immediately
  after Settings > Google login, and prompt-driven header requests can recover
  from an empty local session by re-entering sign-in before failing.
  Windows release packaging now stages only runtime files before zipping, so
  `.pdb`, `.lib`, and `.exp` artifacts are excluded from
  `daily-windows-2.0.4.zip`.
- 2026-06-03 verification results: `.\tool\flutter.ps1 analyze --no-pub`
  passed, `.\tool\flutter.ps1 test --no-pub` passed with 31 tests, Android
  debug APK was rebuilt with test-only build number `8`, and the smaller
  x86_64 split APK (`app-x86_64-debug.apk`, about 79.9 MB) installed
  successfully on `emulator-5554` after the universal debug APK hit emulator
  storage limits. Android launched with PID `8966`; the monthly swipe was
  visually settled on July by the 450 ms capture, and Settings showed the new
  compact notification layout plus the disabled lock icon for the locked
  holiday category. Windows release build succeeded with `daily.exe`
  file/product version `2.0.4`; the refreshed local ZIP is about 14.4 MB and
  contains no `.pdb/.lib/.exp` entries. The Windows app process launched from
  `build\windows\x64\runner\Release\daily.exe`, window title `daily`, and was
  responding. Computer Use screenshot capture was unavailable in this Codex
  session (`Computer Use native pipe path is unavailable` on two attempts), so
  Windows visual screenshot validation could not be completed here.
- 2026-06-03 `2.0.4` release artifacts prepared locally:
  `dist/release-2.0.4/daily-android-2.0.4.apk` (versionName `2.0.4`,
  versionCode `8`, SHA-256
  `18080e2fedebbc48a2e685e8d7a529930125b26e795c1af31fc8732b72385681`),
  `dist/release-2.0.4/daily-windows-2.0.4.zip` (SHA-256
  `5f465ed937a2afd9079ff7c62b78a68890bc11686073261031fcf4d042faec87`),
  and `dist/release-2.0.4/SHA256SUMS.txt`.
- Mac/iPhone workers: do not change the excluded UI items unless the user asks.
  If macOS/iOS has platform-specific Google auth wrappers or release packaging
  scripts outside this shared Flutter code, mirror the same distinction:
  user-driven Google account/Drive permission approval must not share the short
  token/network timeout, and package artifacts should exclude debug symbols and
  intermediate libraries unless intentionally shipped.
- 2026-06-03 release handoff for `2.0.4`: Android/Windows-specific chronic
  symptoms such as Android emulator storage limits, Android debug/release
  signature mismatch, Windows Computer Use pipe availability, and Windows ZIP
  debug-symbol leakage should not be treated as macOS/iOS defects. Aside from
  those platform-only phenomena, macOS/iOS agents should apply or verify the
  same shared Flutter behavior where relevant: natural month swipe settling,
  stable month detail loading, compact settings text layout, locked category
  affordance, and robust Google Drive authorization validation. Mac/iPhone
  agents also need to perform actual UX/UI demonstration testing on simulator
  and device where available, then identify and fix any bugs, vulnerabilities,
  optimization needs, delays, and UX/UI improvement items they find. This
  Windows/Android agent did not modify macOS/iOS platform implementation files.

## Cross-Platform Sync Rule

- User requirement as of 2026-05-30: Windows, Android, iPhone/iOS, and macOS
  must all read and write the same Google Drive AppData v2 file set.
- Do not treat platform-specific sync silos as acceptable. All production
  OAuth clients must belong to the same Google Cloud/Firebase project and must
  resolve to the same Drive AppData namespace. The current sync backend uses
  `daily-sync-v2-event-{eventId}.json` per event and
  `daily-sync-v2-settings.json` for settings.
- Current diagnosis: the installed macOS app was rebuilt with the browser-based
  Desktop OAuth client beginning with `234127810480`, while the checked-in
  iOS/Android/Firebase configuration points at project number `424765276744`.
  Because Drive `appDataFolder` is app-scoped, this made macOS and iOS capable
  of seeing different hidden sync data even when the Google account was the
  same.
- Mac local reference data at the time of diagnosis lives in:
  `/Users/kimhwi/Library/Containers/com.littlebit0.daily.macos/Data/Library/Application Support/com.littlebit0.daily.macos/daily.sqlite`.
  It had three visible synced events: `test`, `ttttt`, and `전역 D-38`.
- iOS simulator reference data at the time of diagnosis lived in:
  `/Users/kimhwi/Library/Developer/CoreSimulator/Devices/BF524643-403E-4212-ACB7-621E11279532/data/Containers/Data/Application/56FAAB98-AD81-4B37-9D2B-208E9DF18632/Library/Application Support/daily.sqlite`.
  It had a different `test` event and a deleted `dwqdwq`, confirming this was
  not just a UI refresh problem.
- Next agent must not “fix” iOS sync by copying local SQLite data or adding a
  platform-only workaround. The durable fix is to align OAuth/client project
  configuration and implement the same v2 event-file sync layout.

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
- Prepared Daily `1.1.1+2` bugfix release assets for macOS and iOS.

## Main Files Changed In Release Work

- `.gitignore`
- `PROJECT_ANALYSIS.md`
- `README.md`
- `analysis_options.yaml`
- `docs/APPLE_BUILD_SETUP.md`
- `docs/RELEASE_NOTES_1.1.1.md`
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
- macOS `1.1.1+2` release build completed.
- macOS app code-sign verification passed after signing the release app with
  the local Apple Development identity.
- macOS `1.1.1+2` DMG verification with `hdiutil verify` passed.
- iOS `1.1.1+2` release build completed with `--no-codesign`.
- iOS unsigned IPA ZIP structure check passed.
- iOS signed archive was attempted with automatic provisioning, but Xcode
  failed because no iPhone device is currently registered with the Apple team:
  `Your team has no devices from which to generate a provisioning profile`.

## Release Artifacts

- macOS DMG:
  `dist/daily-macos-1.1.1+2.dmg`
- iOS unsigned IPA:
  `dist/daily-ios-1.1.1+2-unsigned.ipa`

SHA-256:

- macOS DMG:
  `0effbf8366c7408711336868fb759b18aaaf903ada51eceaadb3a91a03f8fd06`
- iOS unsigned IPA:
  `071a42ec0c186e3a968d62b0f10a18974695b0ad592a8312c77491eefd5333bf`

Important caveat: the iOS IPA is unsigned. Actual iPhone installation requires
either a connected/trusted iPhone so Xcode can create a Development provisioning
profile, or Apple Developer Program distribution signing via TestFlight, App
Store, or Ad Hoc provisioning.

## GitHub Release Status

- A GitHub release should be created for tag `v1.1.1+2`.
- Title: `Daily 1.1.1+2`
- Assets prepared locally:
  - `daily-macos-1.1.1+2.dmg`
  - `daily-ios-1.1.1+2-unsigned.ipa`
- Expected public URL after publishing:
  `https://github.com/littlebit0/Daily/releases/tag/v1.1.1+2`

## Known Local Workspace Notes

These untracked local files existed during handoff and were intentionally not
staged:

- `.flutter-plugins-dependencies 2`
- `ios/Flutter/Generated 2.xcconfig`
- `ios/Flutter/flutter_export_environment 2.sh`

They look like accidental duplicate/generated files and should be reviewed or
removed only after confirming they are not user-created work.

## macOS Notification Testing Note

- Do not test macOS notifications by opening the debug app directly from
  `/tmp/daily-flutter-build/.../Daily.app`.
- That path was reproduced as a root cause for Daily disappearing from macOS
  notification settings or reporting notifications as blocked, even after the
  user had previously allowed Daily notifications.
- Current local development launch path: run `./tool/run_macos.sh`. It builds
  the macOS debug app, installs the current build to `~/Applications/Daily.app`,
  registers it with LaunchServices, and launches that stable path so macOS sees
  the same bundle identity consistently across runs.
- After launching from `~/Applications/Daily.app`, the in-app notification
  diagnostic reported:
  `알림 허용 · 배너 허용 · 사운드 허용 · 예약 1개`.
- Later clarification from the user: "알림" means actual OS notification-center
  local notifications, not only an in-app dialog.
- Follow-up fixes:
  - iOS `AppDelegate.swift` now registers `UNUserNotificationCenter.current().delegate`
    and the flutter local notifications registrant callback.
  - macOS `MainFlutterWindow.swift` installs a strong
    `UNUserNotificationCenterDelegate` after plugin registration so foreground
    notifications request banner/list/sound/badge presentation.
  - Android `AndroidManifest.xml` now declares the flutter_local_notifications
    action, scheduled, and boot receivers required for scheduled reminders.
  - Notification diagnostics now include delivered notification count
    (`도착 N개`) in addition to permission and pending counts.
- Verification on macOS after these fixes:
  - Pressing Settings > 알림 테스트 > 보내기 reported
    `알림 허용 · 배너 허용 · 사운드 허용 · 예약 1개 · 도착 1개`.
  - A temporary event `system probe 00:12` was inserted, app relaunched, and the
    reminder fired at 2026-05-29 00:12 KST. Afterward diagnostics reported
    `도착 2개`, confirming the scheduled event path delivered to macOS
    Notification Center. The temporary event row was deleted afterward.
- Follow-up on 2026-05-29:
  - The user's missed `test 00:56` event was created at 2026-05-29 00:59:03 KST,
    after its start time. The old logic only sent immediate notifications for
    missed reminders within a 2-minute grace period, so this case was skipped.
  - A first attempted fix used `event.updatedAt` to detect recent saves, but the
    project currently stores `KoreaTime.now()` as a UTC-shifted value, making
    `updatedAt` appear about 9 hours ahead in SQLite. That caused the recent-save
    check to fail.
  - Current fix: `EventCommandService.save()` calls
    `scheduleEventReminder(..., allowImmediate: true)`, and
    `LocalNotificationService` now sends an immediate system notification for
    a missed reminder when that flag is true and the event has not ended yet.
    This also covers a newly saved event whose default reminder time is already
    past but whose start/end window is still active.
  - App startup and sync paths keep `allowImmediate` false, so old historical
    events should not suddenly notify on launch. If their configured reminder is
    already stale but the event start is still upcoming, the startup path falls
    back to scheduling at the event start.
  - The reminder decision logic is now isolated in
    `lib/core/notifications/reminder_delivery_plan.dart` with unit coverage in
    `test/core/notifications/reminder_delivery_plan_test.dart`.
  - `KoreaTime.now()` now returns `DateTime.now()` instead of creating a
    UTC-tagged KST wall time, preventing new `createdAt`/`updatedAt` values from
    being stored 9 hours ahead.
  - macOS notifications now use a project-owned native MethodChannel
    (`daily/native_notifications`) for show/schedule/cancel/count/permission
    checks. One-shot event reminders are registered with
    `UNTimeIntervalNotificationTrigger`, daily briefings still use
    `UNCalendarNotificationTrigger`, and immediate/test notifications use
    `UNUserNotificationCenter` requests without a trigger.
  - macOS no longer removes delivered notifications when refreshing a pending
    request. Delivered notifications are removed only through the explicit
    cancel/delete path.
  - Startup rescheduling no longer re-emits a just-fired reminder when
    `allowImmediate` is false; this avoids replacing or obscuring Notification
    Center entries after the app opens.
  - The former foreground `Timer` reminder watcher was removed from `DailyApp`.
    The app now relies on OS-managed notification requests for reminder
    delivery, including when the app is not running.
  - macOS notification root cause found from unified logs: `usernoted`
    delivered Daily notifications to `[.alert .lockScreen .notificationCenter]`
    and attempted to present them as banners, but `NotificationCenter` dropped
    them with `com.littlebit0.daily.macos dropping msg ... app not found`.
    The local app had previously been ad-hoc signed (`TeamIdentifier=not set`),
    so LaunchServices and Notification Center cached an unusable notification
    app identity.
  - The user logged into the Apple account in Xcode, after which a local Apple
    Development code-signing identity became available in the keychain. A debug
    macOS build signed with this identity now has a real TeamIdentifier instead
    of `TeamIdentifier=not set`.
  - After replacing `~/Applications/Daily.app` with the Apple Development-signed
    app, unregistering/registering it with `lsregister`, reindexing it with
    `mdimport`, and restarting `NotificationCenter`/`usernoted`, macOS unified
    logs confirmed the real Notification Center path:
    `displaying as banner`, `Playing notification sound`, and
    `Adding notification to storage`.
  - `tool/run_macos.sh` now signs the installed app with
    `DAILY_CODESIGN_IDENTITY` or the first available Apple signing identity,
    warns when it must fall back to ad-hoc signing, registers only the stable
    `~/Applications/Daily.app` path, and refreshes Notification Center services
    when the installed app's TeamIdentifier changes. This avoids the old
    ad-hoc app cache continuing to drop notifications after signing is fixed.
  - `macos/Runner/Release.entitlements` and `ios/Runner/Runner.entitlements`
    no longer include `com.apple.developer.usernotifications.time-sensitive`.
    Apple Personal Team provisioning does not support that capability, and
    standard Notification Center reminders do not require it.
  - Android scheduled notifications now fall back to
    `AndroidScheduleMode.inexactAllowWhileIdle` when exact alarm permission is
    unavailable, instead of failing the schedule call.
  - Direct SQLite test rows must store `start_at`/`end_at` in Unix seconds, not
    milliseconds. A bad millisecond insert made a test event look far in the
    future and created a false "not firing" diagnosis.
  - Latest macOS verification on 2026-05-29 after real signing and cache
    refresh: a probe event due at 03:18 KST delivered through Notification
    Center. Unified logs showed:
    `addOrUpdate listItem`, `displaying as banner`,
    `Playing notification sound`, and `Adding notification to storage`.
    Temporary probe rows were removed from the local database afterward.
  - Verification after this update:
    `./tool/flutter.sh analyze` passed, `./tool/flutter.sh test` passed,
    `plutil -lint macos/Runner/Info.plist` passed, `xcodebuild -project
    macos/Runner.xcodeproj -scheme Runner -configuration Debug
    -showBuildSettings` passed, and `./tool/run_macos.sh` rebuilt/launched the
    app.
  - Android debug APK build could not be run on this Mac because no Android SDK
    is installed (`No Android SDK found`). Windows build cannot be verified from
    macOS.
  - Temporary `lateprobe`/`lateprobe2` test rows were removed from the local DB.

- Follow-up on 2026-05-29 evening:
  - User reported macOS Google login was blocked again and suspected iPhone
    account-management sync issues.
  - Current installed macOS app at `~/Applications/Daily.app` was still
    `1.1.0 (1)`, while the repo build was `1.1.1 (2)`. The old app showed the
    Desktop OAuth client secret configuration error in Settings > Account.
  - `GoogleDriveAuthService` no longer blocks Desktop OAuth when
    `GOOGLE_DESKTOP_CLIENT_SECRET` is absent. Google's installed-app token
    exchange treats `client_secret` as optional when PKCE is used; the app still
    sends it if a build/runtime value is supplied.
  - iOS now attempts lightweight Google authentication during auth-service
    initialization instead of skipping iOS. This restores a previously signed-in
    iPhone account on app startup so Settings > Account and automatic Drive sync
    do not incorrectly look like local mode after restart.
  - Added an 8-second timeout around lightweight mobile auth restoration so the
    settings/sync path cannot hang indefinitely waiting for native sign-in state.
  - Rebuilt and replaced `~/Applications/Daily.app` with the fixed macOS
    `1.1.1 (2)` build. GUI check confirmed the Account section now shows the
    normal `Google로 로그인` button and no Desktop OAuth secret error. The actual
    Google login browser flow was not completed because the user requested to be
    asked before login.
  - Rebuilt and installed the fixed iOS `1.1.1 (2)` app onto the connected
    iPhone. Launch from `devicectl` failed only because the iPhone was locked.
  - Local verification after this update: `./tool/flutter.sh analyze` passed
    and `./tool/flutter.sh test` passed.
  - Remaining iOS OAuth configuration issue: the checked-in iOS plist values
    still point to the same OAuth client used for bundle
    `com.littlebit0.daily.macos`. A production iPhone sync fix still needs a
    Google/Firebase iOS OAuth client for bundle `com.littlebit0.daily` and its
    matching `REVERSED_CLIENT_ID` in `ios/Runner/Info.plist`.

- Follow-up on 2026-05-29 after user testing:
  - User completed macOS browser login and the app showed
    `Google 토큰 요청 실패: client_secret is missing.`
  - Root cause: Google's installed-app `client_secret` is optional by protocol,
    but the current Daily Desktop OAuth client rejects this token exchange
    without its generated secret.
  - Rebuilt and reinstalled `~/Applications/Daily.app` with
    `GOOGLE_DESKTOP_CLIENT_SECRET` injected via a temporary
    `--dart-define-from-file`; the temp file was deleted after the build. Do
    not commit the secret.
  - User reported iPhone real-time sync still did not work. Code root cause:
    Settings/Onboarding login called `syncNow()` once but did not start
    `SyncService.start()`, so the periodic remote pull timer was not activated
    after logging in from a running app.
  - Fixed Settings and Welcome Google login flows to call
    `syncServiceProvider.start()` after sign-in, and reduced Google Drive
    foreground polling from 20 seconds to 5 seconds for near-real-time sync
    while the app is open.
  - Rebuilt and installed the fixed iOS `1.1.1 (2)` app onto the connected
    iPhone and launched it successfully with `devicectl`.
  - Local verification after this update: `./tool/flutter.sh analyze` passed
    and `./tool/flutter.sh test` passed. The first parallel test attempt failed
    only because another Flutter command was holding the startup/ephemeral file
    lock; rerunning test alone passed.

- Follow-up on 2026-05-29 for iPhone sync first:
  - User supplied a new Google iOS OAuth plist for bundle
    `com.littlebit0.daily` under project number `234127810480`.
  - `ios/Runner/Info.plist` now uses iOS client
    `234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa.apps.googleusercontent.com`
    and reversed URL scheme
    `com.googleusercontent.apps.234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa`.
  - `ios/Runner/GoogleService-Info.plist` now uses the same iOS client and
    reversed client ID. The stale `SERVER_CLIENT_ID` from project
    `424765276744` was removed because `google_sign_in_ios` reads that value
    automatically and would otherwise mix projects during iOS sign-in.
  - iOS `GoogleDriveAuthService` now treats
    `GOOGLE_IOS_SERVER_CLIENT_ID` as optional and does not fall back to the
    default web/server client on iOS. Interactive mobile login/authorization
    waits up to 5 minutes; silent auth remains capped at 45 seconds.
  - Version was bumped to visible release `1.1.3`; build number remains `3`.
    User explicitly requested release/tag/docs/assets use `1.1.3` style rather
    than exposing the Flutter build metadata suffix in release names.
  - Connected iPhone `김휘의 iPhone`
    (`415EDAF7-A303-50FD-8344-351D7BF59153`) was updated with the
    development-signed `1.1.3 (3)` build and launched successfully.
- Release assets prepared:
    `dist/daily-ios-1.1.3-signed-development.ipa` and
    `dist/daily-ios-1.1.3-unsigned.ipa`.
  - This is the immediate iPhone-first fix. Android/Web/Firebase metadata still
    references project `424765276744`, so the later cross-platform cleanup must
    align all production OAuth clients to one shared Drive AppData target.

- Follow-up on 2026-05-29 from Windows/Android-focused local Codex:
  - Windows local path for this pass:
    `C:\Users\com\Documents\New project\.codex-tools\portfolio_repos\Daily`.
  - Product behavior must remain the same across Windows, Android, macOS, and
    iPhone/iOS. This local Codex can work and verify Windows/Android only; do
    not interpret that as permission to let macOS/iOS drift from the shared
    Flutter behavior.
  - Month calendar paging was changed from a 3-page reset/jump model to a
    long virtual PageView, so swipe gestures no longer replace the visible
    month halfway through the animation.
  - Lunar labels now render beside the solar day number and include lunar
    month/day on every date, not only on lunar day 1.
  - Google Drive sync no longer polls every 5 seconds while idle. Sync is now
    event-driven for local create/update/delete changes, runs on first app
    start/sign-in/resume, and attempts a best-effort sync before background or
    exit. Local change sync is debounced for 1 second.
  - As of 2026-05-30, the old whole-backup `daily-sync-v1.json` behavior is
    abandoned. Android/Windows now use v2 Drive AppData files:
    `daily-sync-v2-event-{eventId}.json` for each event and
    `daily-sync-v2-settings.json` for settings. Local event create/update/delete
    sync touches only the changed event file; deletions are tombstoned in that
    event file. First start, sign-in, resume, and manual sync may list v2 event
    files to merge state, but must not read or write a monolithic snapshot.
    Mac/iPhone agents must implement this exact v2 layout and stop using v1.
  - A cross-device all-day sync bug was fixed after the user reported iPhone
    events `6.1 평일외출` and `6.5평일외출` showing as two-day events on Android.
    Root cause: all-day `startAt`/`endAt` values could arrive from iPhone/iOS as
    UTC-midnight instants, then Android converted them to local 09:00 times and
    the month grid treated the exclusive end as touching the next day. The fix
    normalizes all-day events to local date boundaries in the event domain,
    event draft creation, command-service save, Drift save/load, and Google
    Drive sync decode/encode. V2 event files now emit date-only `startDate`/
    `endDate` fields for all-day events while keeping backward-compatible
    `startAt`/`endAt`. Google Drive all-day decode now reads the literal ISO
    date prefix before considering time-zone conversion, so offset-bearing
    all-day strings stay on the intended calendar date.
  - `syncServiceProvider` currently points at Google Drive sync. The older
    `FirestoreSyncService` remains in the tree but is not the active sync
    backend for Android/Windows. It was not removed because doing so would be
    a feature-surface decision. If a future Mac/iPhone or shared-code agent
    re-enables Firestore sync, it must apply the same all-day date-only
    semantics before using it in production.
  - The compact calendar header now keeps month/view/actions in one row, uses
    a single week/month/day view menu, and moves secondary actions into a
    more menu to recover vertical and horizontal space on Android-sized
    screens.
  - Mac/iPhone Codex should verify the same shared Flutter UI changes on
    macOS/iOS, especially PageView swipe feel, lifecycle sync on background/
    foreground, and whether mobile header controls fit without overflow.
  - If macOS/iOS still uses short-interval foreground polling for Google Drive
    sync, treat that as a Mac/iPhone-side defect. Match the Android/Windows
    behavior: sync on app start/sign-in/resume, best-effort before background
    or exit, and after create/update/delete events with a short debounce.
  - Android/Windows should keep feature parity with the Mac/iPhone builds for
    calendar navigation, lunar display, lifecycle sync, Google Drive AppData
    sync semantics, all-day date handling, and compact header controls.
  - Verification on Windows local Codex after this pass:
    `.\tool\flutter.ps1 analyze --no-pub` passed,
    `.\tool\flutter.ps1 test --no-pub` passed with 25 tests,
    Android debug APK build passed, and Windows debug build produced
    `build\windows\x64\runner\Debug\daily.exe`. Windows build emitted many
    linker `LNK4099` warnings for missing Firebase/libcurl PDB debug symbols;
    the build still succeeded and these warnings are from bundled dependency
    debug-symbol lookup, not app logic.
  - Correction after user reported that iPhone is the working source of truth:
    Android/Windows must use the same Google Drive AppData target as the iPhone
    build, project number `234127810480`. The temporary Android
    `applicationId = "com.littlebit0.daily"` made Android authenticate against
    a different OAuth/AppData identity and made the device look like it had
    been initialized separately from iPhone data.
  - Android `applicationId` is now back to `com.littlebit0.dailycalendar`.
    Google Cloud project `daily-496913` / `234127810480` contains matching
    Android OAuth clients for that package: `Daily Android Debug` with SHA-1
    `D0:5F:5F:28:C7:A1:9C:92:8A:F4:80:B0:B5:81:97:19:6F:EC:21:E2` and
    `Daily Android Release` with SHA-1
    `2F:0D:16:3A:FB:B9:E8:DE:97:A5:41:04:43:90:0E:AC:6A:51:76:72`.
  - The Android Google Sign-In server client default now uses the same 234
    Web client as the iPhone-aligned project:
    `234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com`.
    Do not change Android back to project `424765276744`; the checked-in
    `android/app/google-services.json` is legacy metadata and is not the source
    of truth for Drive AppData sync.
  - Windows uses the 234 Desktop OAuth client
    `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`.
    Google rejects the token exchange for this Desktop client unless its
    generated secret is supplied. The app now reads that secret from
    `GOOGLE_DESKTOP_CLIENT_SECRET`, `GOOGLE_DESKTOP_OAUTH_CONFIG`, or local
    `%APPDATA%\Daily\google_desktop_oauth.json` /
    `%LOCALAPPDATA%\Daily\google_desktop_oauth.json`. A new Desktop client
    secret was added in Google Cloud Console and saved locally at
    `%APPDATA%\Daily\google_desktop_oauth.json`; never commit or print it.
  - Verification after the 234-project correction: `.\tool\flutter.ps1 analyze
    --no-pub` passed, `.\tool\flutter.ps1 test --no-pub` passed with 25 tests,
    Android debug APK build passed, badging reports package
    `com.littlebit0.dailycalendar` version `1.1.3` code `3`, the emulator was
    updated with that APK, and Google sign-in reached the account chooser with
    calling package `com.littlebit0.dailycalendar`. The automated pass did not
    choose a personal Google account; the user must choose the same Google
    account used on the working iPhone build.
  - On 2026-05-30 the user reported that editing schedules made dates change
    unexpectedly. Windows local DB inspection at
    `%APPDATA%\littlebit0\Daily\daily.sqlite` showed the listed iPhone-source
    all-day events were already stored 1-2 days early while marked `synced`.
    That meant any edit would attach a new `updatedAt` to the wrong local date
    and sync it outward. This was existing corrupted sync data, not a reason to
    change iPhone/macOS. The DB was backed up to
    `%APPDATA%\littlebit0\Daily\daily.sqlite.backup-before-date-repair-20260530-181224`,
    then exactly these events were repaired locally and synced back to Drive:
    `6.1 평일외출`, `6.3 국회의원선거`, `6.5 평일외출`,
    `6.6 면회외출`, `6.20-6.21 캠핑 약속`, and `6.30 전역🎉`.
  - Windows debug build was regenerated after this shared Dart change. The
    first attempt failed because the old `daily.exe` was still running and
    locked the install output; stopping that process and rebuilding succeeded,
    producing `build\windows\x64\runner\Debug\daily.exe`.
  - Follow-up v2-only sync conversion after the user explicitly abandoned the
    old v1 behavior: `lib/core/sync/google_drive_sync_service.dart` no longer
    reads or writes the legacy whole snapshot during normal sync. Full sync
    lists and merges v2 event files; queued event sync finds and uploads only
    `daily-sync-v2-event-{eventId}.json` for the changed event. Settings sync
    is separated into `daily-sync-v2-settings.json` and is not touched by a
    queued event-only sync. `deleteCloudBackup()` still knows the legacy v1
    name only so a user-requested cloud-data deletion can clean abandoned data.
  - Verification after the v2-only sync conversion: targeted Google Drive sync
    tests passed, `.\tool\flutter.ps1 analyze --no-pub` passed,
    `.\tool\flutter.ps1 test --no-pub` passed with 26 tests, Android debug APK
    built and was installed over the emulator package
    `com.littlebit0.dailycalendar`, Windows debug build succeeded, and
    `build\windows\x64\runner\Debug\daily.exe` plus the Android emulator app
    were launched from the latest build.
  - Release coordination rule from the user: after the Mac/iPhone agents port
    the same v2 sync method, release updates must not upload only Mac/iPhone
    artifacts. Every 2.0.0-or-newer release must publish Windows and Android
    artifacts together with Mac/iPhone artifacts so all platforms stay on the
    same sync schema and OAuth/AppData target.
  - Daily 2.0.0 release artifacts prepared on Windows/Android:
    `dist/daily-android-2.0.0.apk`,
    `dist/daily-android-2.0.0.aab`,
    `dist/daily-windows-2.0.0.zip`, and
    `dist/daily-windows-2.0.0.exe`. Android APK badging reports package
    `com.littlebit0.dailycalendar`, visible version `2.0.0`, and internal
    build number `4`.
  - 2026-06-01 login-delay investigation for Android/Windows: the apparent
    five-minute Google login delay was caused by five-minute interactive auth
    waits plus the connect flow immediately running both `start()` and
    `syncNow()`, which could duplicate initial restore/full-sync work before
    the UI considered login complete. Android sign-in now authenticates the
    account once and lets the first Drive sync request Drive scope consent,
    Windows loopback OAuth waits 90 seconds instead of five minutes, token/
    userinfo and Drive API requests have 30-second request timeouts, and
    onboarding/settings connect flows use `startListeningOnly()` before one
    explicit `syncNow(promptIfNecessary: true)` so initial restore is not run
    twice. A regression test verifies `startListeningOnly()` does not run an
    initial restore. Mac/iPhone platform folders were not edited; if those
    platforms have separate native auth/sync code, their agents should mirror
    the same rule: do not request Drive consent twice during sign-in, do not
    run duplicated initial sync during connect, and keep bounded network waits.
  - Verification after the login-delay fix: `.\tool\flutter.ps1 analyze
    --no-pub` passed, `.\tool\flutter.ps1 test --no-pub` passed with 30 tests,
    Android debug APK built successfully after fixing `tool/flutter.ps1` to
    quote `JAVA_TOOL_OPTIONS` temp paths that contain spaces, the debug APK was
    installed and launched on emulator `emulator-5554` with no fatal logcat
    crash, Windows debug build produced
    `build\windows\x64\runner\Debug\daily.exe`, and the Windows executable
    stayed running during a smoke launch.
  - Follow-up on the same day: user rejected treating login/logout as complete
    while heavy sync continued in the background. The Windows/Android fix was
    revised to optimize the synchronous path instead. Account auth, silent
    auth, desktop OAuth redirect, desktop token/userinfo requests, and Drive
    requests are bounded at 10 seconds or less; mobile sign-out is bounded at 3
    seconds. Login/connect now starts listeners without an automatic initial
    sync, then performs only pending-change upload plus restore instead of full
    backup-all plus restore. Event restore downloads are batched with limited
    concurrency, and pending-event backup resolves all target remote files with
    one name query instead of one Drive list query per event. Logout no longer
    runs a full sync; it only attempts pending-change upload within the
    remaining 10-second budget before clearing account state. No background
    completion workaround is used for login/logout.
  - Verification after the revised optimization: `.\tool\flutter.ps1 analyze
    --no-pub` passed, `.\tool\flutter.ps1 test --no-pub` passed with 30 tests,
    Android debug APK rebuilt, reinstalled, and launched on `emulator-5554`
    with app PID observed, and Windows debug build rebuilt and launched with
    `daily.exe` running.
  - Mac/iPhone handoff for work done outside the previous macOS-side notes:
    port the same synchronous-path optimization, not a background completion
    workaround. Specifically, avoid any login/connect flow that runs both
    initial listener startup restore and a separate full sync; connect should
    start listeners, flush only pending local v2 event files, then restore v2
    remote data. Logout should never run full backup-all/full-restore; it
    should only make a short pending-change flush attempt, then clear account
    state. Keep account/auth and Drive API waits bounded to roughly 10 seconds,
    and keep native sign-out much shorter. Preserve the v2 file model exactly:
    one settings file, per-event files, date-only all-day fields, tombstones for
    deletes, and event-only uploads for local event changes. Also port the
    Android/Windows startup/background behavior: queued and DB-pending event
    IDs must be flushed so local changes cannot survive restart unsynced, but
    local startup must not open a Google account chooser automatically. If
    iOS/macOS have separate native auth wrappers, they must avoid duplicate
    Drive scope consent requests during sign-in. If they share this Flutter
    Dart code, verify the shared behavior on iOS simulator/device and macOS.
  - 2.0.2 release coordination: the repository version was moved to `2.0.2`
    with no `+` suffix in `pubspec.yaml` per user request. Android artifacts
    should use build number `6` only at build time. For the `v2.0.2` GitHub
    release, Windows/Android are rebuilt from this code. The user explicitly
    allowed reusing the existing 2.0.1 macOS DMG and unsigned iOS IPA because
    dedicated Mac/iPhone 2.0.2 artifacts do not exist yet.
  - 2026-06-02 GitHub issue #2 Windows/Android UI fix: adjusted the shared
    month grid cell layout so lunar labels and Gregorian day numbers share the
    same fixed 21 px header row, including today's blue circle. All cells now
    keep a 1 px border slot, using a transparent border when not selected, so
    selected/today cells no longer shift their y-position. Event span flags now
    start closer to the date header (`_flagTop` 27) with smaller lane height/gap
    to reduce wasted vertical space. Added a widget test that checks today's
    date label and a neighboring date label have the same y-position and that
    the event flag begins close to the day header. Android and Windows debug
    builds were rebuilt and launched after this change. Mac/iPhone agents
    should port/verify the same month-cell alignment behavior if their platform
    rendering diverges from the shared Flutter widget.
  - 2026-06-02 Windows/Android dependency cleanup: removed inactive
    Firebase/Firestore Dart code and dependencies from the active shared
    Flutter project. `syncServiceProvider` already pointed at Google Drive v2,
    and the Firebase Auth/Firestore providers and `FirestoreSyncService` were
    only self-referenced legacy code. Removed the stale Android
    `google-services.json` from project `424765276744` so Android does not carry
    dead Firebase metadata that conflicts with the current iPhone-aligned
    Google Drive AppData project `234127810480`.
  - The same cleanup removed unused direct dependencies `cupertino_icons` and
    `collection`, replaced the unused direct `drift_flutter` dependency with an
    explicit `sqlite3_flutter_libs` dependency so the native SQLite bundle
    remains intentional, and updated `flutter_secure_storage` to `10.3.1`.
    Removing `drift_flutter` also removed the unused transitive
    `sqlcipher_flutter_libs` package. Android Gradle Plugin was updated within
    major version 8 to `8.13.2`, Kotlin was updated to `2.3.21`, and
    `android/app/build.gradle.kts` was migrated from the deprecated
    `kotlinOptions.jvmTarget` setter to the Kotlin `compilerOptions` DSL.
  - Verification after dependency cleanup: `.\tool\flutter.ps1 analyze
    --no-pub` passed, `.\tool\flutter.ps1 test --no-pub` passed with 31 tests,
    Android debug APK built with `--build-name=2.0.2 --build-number=6`,
    installed on emulator `emulator-5554`, launched with app PID `26002`, and
    recent Android logs showed no `FATAL EXCEPTION` / `E AndroidRuntime`.
    Windows debug build produced `build\windows\x64\runner\Debug\daily.exe`
    and the smoke launch stayed running with PID `15872`.
  - Mac/iPhone agents must mirror the dependency cleanup on their side before
    the next Apple build: run Flutter dependency generation on macOS/iOS so
    Firebase/Firestore plugin registration is removed from platform-generated
    files, verify no stale Firebase native references remain, and then run the
    normal iOS/macOS analyze/test/build checks. This Windows/Android pass did
    not edit iOS/macOS platform implementation files.
  - 2026-06-02 Windows/Android Google login follow-up: after clean reinstall,
    the user reported Windows browser login could not finish and Android Drive
    permission approval timed out. Root cause in the shared Dart auth service:
    the previous 10-second optimization used the same timeout for user-driven
    OAuth/permission approval UI and app-controlled token/network work. That
    closed the Windows loopback server and Android authorization wait while the
    user was still approving. The fix separates those budgets:
    browser/account/Drive permission approval now waits up to 2 minutes, while
    silent auth, token exchange, userinfo, Drive API requests, and logout
    remain bounded at 10 seconds or less. Verification after the fix:
    `.\tool\flutter.ps1 analyze --no-pub` passed, `.\tool\flutter.ps1 test
    --no-pub` passed with 31 tests, Android and Windows debug builds passed,
    Android was uninstalled/reinstalled/launched on emulator `emulator-5554`
    with PID `27520` and no fatal AndroidRuntime logs, and Windows app data was
    backed up/removed before relaunching the latest debug build with PID `5640`.
    Mac/iPhone agents should mirror this distinction if any platform-specific
    auth wrapper has its own timeout: user approval waits must not share the
    short network/sync timeout.
  - 2026-06-02 Windows/Android-only 2.0.3 update: bumped `pubspec.yaml` visible
    version to `2.0.3` with no `+` suffix, updated Windows MSIX metadata to
    `2.0.3.0`, added `docs/RELEASE_NOTES_2.0.3.md`, rebuilt Android with
    versionName `2.0.3` and versionCode `7`, and rebuilt Windows with
    `--build-name=2.0.3` only so Windows file/product versions are exactly
    `2.0.3`. Prepared local artifacts
    `dist/daily-android-2.0.3.apk` and `dist/daily-windows-2.0.3.zip`.
    SHA-256: Android
    `a9a73c94065658846cb351aa642c6afd7544d01ffba8bb8ff664ac73ba69de63`;
    Windows
    `e308bc9fb50b33834a2ea7af951bf17aefb179df0cd29330c90143a5b8771a6e`.
    Final 2.0.3 smoke check installed/launched the Android APK on
    `emulator-5554` with PID `28242` and no fatal AndroidRuntime logs, then
    launched the Windows debug build with PID `10748`. This pass intentionally
    did not produce new macOS/iOS artifacts.

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`. Do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, and OAuth secrets out of the repository.
- Google/Firebase legacy metadata still references project number
  `424765276744`. The current iPhone-first Drive sync target uses project
  number `234127810480` for iOS, Android, and Windows Desktop OAuth. Do not
  commit OAuth client secrets.

## Recommended Next Steps

0. Current release prep moved Daily to `2.0.1+5` and added GitHub Actions
   workflows for platform installer generation. The release workflow publishes
   Android APK, macOS DMG, unsigned iOS IPA, Windows ZIP, and SHA-256 sums to
   the `v2.0.1` GitHub release when the tag is pushed. iOS remains unsigned in
   CI because Apple Developer signing assets are not stored in the repo.
   Store submission prep then added a generated Daily app icon set for iOS,
   macOS, and Android, generated a Daily iOS launch image, and added
   `docs/STORE_SUBMISSION.md`. The user narrowed the current store-submission
   scope to Apple App Store only, so Google Play and Microsoft Store work is
   deferred. Apple archive creation works, but App Store IPA export is blocked
   until an Apple Distribution certificate and App Store provisioning profiles
   are available for the team.
1. Mac/iPhone Codex must port the same v2 Google Drive AppData file layout and
   stop using `daily-sync-v1.json` for normal sync. Use the exact Android/
   Windows semantics: per-event v2 files, date-only all-day fields, tombstones
   for deletes, event-only uploads for local event changes, and settings in the
   separate v2 settings file.
2. When publishing a release after this v2 sync change, upload Windows and
   Android artifacts together with Mac/iPhone artifacts. Do not publish a
   Mac/iPhone-only release for a sync-schema-changing version.
3. Verify the iPhone/macOS v2 sync change with `./tool/flutter.sh analyze`,
   `./tool/flutter.sh test`, an iOS simulator run, a connected iPhone install,
   and a macOS run against the same Google account.
4. After user confirms cross-platform v2 sync works, commit, push, tag, and
   publish the next GitHub release with fresh artifacts.
5. Clean or ignore the duplicate generated Flutter files after checking they
   are not needed.
6. Continue the pending design task: redesign Daily with an Apple-like visual
   language and apply it consistently across iOS, macOS, Android, and Windows.
7. After design changes, run `./tool/flutter.sh analyze` and
   `./tool/flutter.sh test`.
8. For release-quality iOS distribution, configure Apple Developer signing and
   create a signed IPA or TestFlight upload.
