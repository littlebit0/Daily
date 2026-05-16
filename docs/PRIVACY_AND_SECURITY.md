# Privacy, Security, and Consent Notes

This document is the pre-release checklist for Daily's current data handling.
It is not legal advice; it is the engineering baseline that should be reviewed
before public distribution.

## Data Stored Locally

- Calendar events: title, dates, times, all-day flag, recurrence, category,
  memo, location, reminders, D-day display flag, sync metadata, and soft-delete
  timestamps.
- App settings: reminder defaults, week start day, lunar-date display, category
  definitions, D-day reminder offsets, onboarding completion, and AI feature
  toggles.
- Google account email is only kept in memory by the sign-in session; it is not
  stored in the local event database.
- Gemini API key, if used later, is stored through platform secure storage.
  The AI UI is currently disabled and marked as in development.

## Google Drive Sync

- Sync uses the Google Drive `appDataFolder` scope:
  `https://www.googleapis.com/auth/drive.appdata`.
- The app stores a JSON snapshot named `daily-sync-v1.json` in the user's
  private app data folder.
- The snapshot currently contains events and non-secret app settings.
- The app does not request access to the user's visible Drive files.
- The snapshot is not yet end-to-end encrypted. Treat that as a blocker before
  storing highly sensitive content.

## User Consent Text Needed Before Public Release

Use this wording as the basis for the OAuth consent screen and store listing:

```text
Daily stores your calendar events and app settings on your device. If you
connect Google Drive sync, Daily saves one private backup file in your Google
Drive app data folder so your devices can restore and sync your data. Daily
does not read, list, or modify your visible Google Drive files.
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
- Delete the app's Google Drive app-data file from their Google account if
  manual removal is needed.

## Security Hardening Still Needed

- Add optional encryption for the Google Drive snapshot.
- Add last-sync status and conflict details in Settings.
- Re-test with a fresh Google account after publishing the OAuth app to
  production.

## Korea Holiday Source

Korean public holidays and substitute holiday rules are based on the current
`관공서의 공휴일에 관한 규정` in the National Law Information Center:

- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1018770085
- https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1027161473
