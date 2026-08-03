# Privacy, Security, and Consent Notes

Current release baseline: `3.0.1`.

This document is the pre-release checklist for Daily's current data handling.
It is not legal advice; it is the engineering baseline that should be reviewed
before public distribution.

## Data Stored Locally

- Calendar events: title, dates, times, all-day flag, recurrence, category,
  memo, location, URL, optional weather note, reminders, D-day display flag,
  sync metadata, and soft-delete timestamps.
- App settings: reminder defaults, week start day, lunar-date display, category
  definitions, D-day reminder offsets, onboarding completion, default calendar
  view, calendar filters, calendar display preferences, and AI feature toggles.
- App lock PIN, when enabled, is stored locally through platform secure storage
  and is not included in Google Drive sync files.
- Linked Apple and Google account metadata is stored locally in secure app
  preferences to restore the user's chosen sign-in state. Daily does not yet
  operate a backend account-linking service.
- Gemini API key, if used later, is stored through platform secure storage.
  The AI UI is currently disabled and marked as in development.

## Google Drive Sync

- Sync uses the Google Drive `appDataFolder` scope:
  `https://www.googleapis.com/auth/drive.appdata`.
- The app stores private v2 JSON files in the user's app data folder:
  `daily-sync-v2-event-{eventId}.json` for each event and
  `daily-sync-v2-settings.json` for non-secret app settings.
- Event files and settings files do not include the local app lock PIN.
- The app does not request access to the user's visible Drive files.
- Google Drive AppData sync files are not yet end-to-end encrypted. Treat that
  as a blocker before storing highly sensitive content.

## User Consent Text Needed Before Public Release

Use this wording as the basis for the OAuth consent screen and store listing:

```text
Daily stores your calendar events and app settings on your device. If you sign
in with Google, Daily saves private app-data files in your Google Drive app
data folder so your devices can restore and sync your data. Daily does not
read, list, or modify your visible Google Drive files.
```

Required public links before production OAuth release:

- Privacy policy URL
- Support email
- App homepage or support page
- Data deletion instructions

## Data Deletion

Users must be able to:

- Delete local events from the app.
- Log out from Settings, which returns the app to the welcome flow.
- Use the in-app membership withdrawal action, which deletes the Google Drive
  app-data backup when available, clears local events/settings, signs out, and
  returns to the welcome flow.
- Delete the app's Google Drive app-data files from their Google account if
  manual removal is needed.

## Security Hardening Still Needed

- Add optional encryption for Google Drive AppData sync files.
- Continue release-device testing of PIN, biometric, and system authentication
  unlock paths on iOS and macOS.
- Re-test with a fresh Google account after publishing the OAuth app to
  production.

## Korea Holiday Source

Korean public holidays and substitute holiday rules are based on the current
`관공서의 공휴일에 관한 규정` in the National Law Information Center:

- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1018770085
- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027161473
