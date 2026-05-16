# Google Drive Sync Setup

This setup must be done in stages. Do not skip the Google Cloud/OAuth stage;
the app can build without it, but Google sign-in will not complete correctly
until OAuth clients and scopes are configured.

## Stage 1: Implemented in the app

- Sync provider was switched from Firebase sync to Google Drive AppData sync.
- The app stores one JSON snapshot named `daily-sync-v1.json` in the user's
  Google Drive `appDataFolder`.
- The snapshot contains events and non-secret app settings such as categories,
  reminder defaults, week start day, lunar display, and D-day reminder offsets.
- Local events and remote events are merged by event ID and the newest
  `updatedAt` or `deletedAt` timestamp.
- Deleted events are retained as tombstones so deletion can sync to other
  devices.
- Settings now has a Google Drive sync section with connect, manual sync, and
  disconnect actions.
- Automatic sync runs on app start, after Google Drive sign-in, after local
  event/settings changes, and every 15 minutes while the app is running.
- Local event changes are debounced for 2 seconds so repeated edits do not
  trigger redundant Drive requests.
- If another sync request arrives while a sync is already running, one more
  sync pass is guaranteed after the current pass finishes.
- Google Sign-In can receive a web OAuth client ID through:

```powershell
.\tool\flutter.ps1 run --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID="<web-client-id>"
```

## Stage 2: Google Cloud/Firebase setup status

Project currently used by the app:

- Firebase/Google Cloud project: `daily-littlebit0`
- Android package name: `com.littlebit0.daily`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`

Completed on 2026-05-16:

- Google Drive API enabled for `daily-littlebit0`.
- Android debug SHA-1 and SHA-256 registered in Firebase.
- Android upload/release SHA-1 and SHA-256 registered in Firebase.
- `android/app/google-services.json` refreshed.
- The refreshed config contains Android OAuth clients and a Web OAuth client.

Still required before public release:

1. Confirm OAuth consent screen public-facing text, privacy policy, and support
   email.
2. Publish the OAuth app to production when the app is ready for external users.
3. Re-test Google Drive sign-in/sync from a fresh Google account.

Android debug signing certificate:

```text
SHA-1   D0:5F:5F:28:C7:A1:9C:92:8A:F4:80:B0:B5:81:97:19:6F:EC:21:E2
SHA-256 84:CF:29:C5:6F:5B:67:39:9D:14:FE:C2:35:D4:6D:B8:61:96:66:0B:26:8F:9E:08:AF:21:7B:48:9A:93:BC:D1
```

Android upload/release signing certificate:

```text
SHA-1   2F:0D:16:3A:FB:B9:E8:DE:97:A5:41:04:43:90:0E:AC:6A:51:76:72
SHA-256 D6:D4:18:72:A4:71:BA:55:35:CD:DD:D1:77:3C:C1:A4:3D:71:F1:3C:9B:26:25:DF:86:E0:DA:A7:36:76:8E:F1
```

Google's Drive API documentation lists `drive.appdata` as a non-sensitive
scope for an app's own configuration data:

- https://developers.google.com/workspace/drive/api/guides/api-specific-auth
- https://developers.google.com/workspace/drive/api/guides/about-files

## Stage 3: Platform rollout

1. Android: first runtime target. The current app code is wired for this.
2. iOS/iPadOS/macOS: add OAuth clients and platform files, then test the same
   Drive AppData sync flow.
3. Windows: the app builds and the sync UI degrades gracefully when native
   Google Sign-In is unavailable. If Windows sync is required for public users,
   add a desktop OAuth browser flow with a local redirect.

## Stage 4: Hardening before public release

- Add encrypted sync snapshots before treating this as production-grade private
  data storage.
- Add conflict UX for simultaneous edits on multiple devices.
- Add a sync status screen or last-sync timestamp.
- Test sign-in and sync with a fresh Google account, two Android installs, and
  then each desktop/mobile platform.
- For public distribution, publish the OAuth consent screen to production and
  provide the required privacy policy/support links.
