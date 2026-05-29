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
  `pending 1.1.1+2 release commit`
- Release tag prepared locally:
  `v1.1.1+2`
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

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`. Do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, and OAuth secrets out of the repository.
- Google project number currently referenced by project docs:
  `234127810480`.

## Recommended Next Steps

1. Publish the GitHub release for `v1.1.1+2` with the prepared macOS DMG and
   iOS unsigned IPA assets.
2. For actual iPhone installation, connect and trust the user's iPhone, then
   rerun the iOS archive/install flow so Xcode can create a Development
   provisioning profile for `com.littlebit0.daily`.
3. Clean or ignore the duplicate generated Flutter files after checking they
   are not needed.
4. Continue the pending design task: redesign Daily with an Apple-like visual
   language and apply it consistently across iOS, macOS, Android, and Windows.
5. After design changes, run `./tool/flutter.sh analyze` and
   `./tool/flutter.sh test`.
6. For release-quality iOS distribution, configure Apple Developer signing and
   create a signed IPA or TestFlight upload.
