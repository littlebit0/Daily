# DailyCalendar 3.0.1 App Review Notes

## iOS

```text
DailyCalendar 3.0.1 is an update to the personal calendar app.

The app can be reviewed without any account. On the welcome screen, choose "로컬로 시작" (Start locally) to enter the calendar and use the calendar features in local-only mode.

Sign in with Apple is independent from Google. Completing Sign in with Apple enters the app immediately and does not require or present a Google login page.

Google sign-in is optional. It is shown only when the user explicitly chooses Google sign-in or connects Google for backup and sync. Google Drive access is limited to the private AppData area used for DailyCalendar event and setting backup/sync. The app does not read, modify, or manage the user's regular Google Drive files.

If a previously authorized Google session can be restored silently, the app may restore that optional sync connection without an interactive login page. If silent restoration is unavailable, Apple/local mode remains fully usable.

This build improves the search-panel transition and continuous vertical month scrolling. Opening search no longer changes the visible month, and calendar scrolling avoids unnecessary full-screen rebuilds.

Calendar access is requested only when the user chooses calendar import. Notification access is used only for event reminders, morning briefings, and D-day reminders configured by the user.

DailyCalendar does not use IDFA, advertising, ad measurement, data brokers, or cross-app/site tracking.
```

## macOS

```text
DailyCalendar 3.0.1 is the macOS version of the personal calendar app.

The app can be reviewed without any account. On the welcome screen, choose "로컬로 시작" (Start locally) to enter the calendar and use the calendar features in local-only mode.

Sign in with Apple is independent from Google. Completing Sign in with Apple enters the app immediately and does not require or present a Google login page.

Google sign-in is optional. It is shown only when the user explicitly chooses Google sign-in or connects Google for backup and sync. Google Drive access is limited to the private AppData area used for DailyCalendar event and setting backup/sync. The app does not read, modify, or manage the user's regular Google Drive files.

If a previously authorized Google session can be restored silently, the app may restore that optional sync connection without an interactive login page. If silent restoration is unavailable, Apple/local mode remains fully usable.

This build improves the search-panel transition, continuous vertical month scrolling, and macOS calendar interaction performance. Opening search no longer changes the visible month.

Calendar access is requested only when the user chooses calendar import. Notification access is used only for event reminders, morning briefings, and D-day reminders configured by the user.

DailyCalendar does not use IDFA, advertising, ad measurement, data brokers, or cross-app/site tracking.
```

## Transporter Files

- iOS: `dist/transporter-ios-3.0.1/Daily-iOS-AppStore-3.0.1-build-3.0.1.ipa`
- macOS: `dist/transporter-macos-3.0.1/Daily-macOS-AppStore-3.0.1-build-3.0.1.pkg`
