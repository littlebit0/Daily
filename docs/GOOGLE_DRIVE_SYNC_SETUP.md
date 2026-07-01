# Google Drive Sync Setup

This setup must be done in stages. Do not skip the Google Cloud/OAuth stage;
the app can build without it, but Google Drive connection will not complete
correctly until OAuth clients and scopes are configured.

## Stage 1: Implemented in the app

- Sync provider was switched from Firebase sync to Google Drive AppData sync.
- The app no longer uses the legacy `daily-sync-v1.json` whole-database
  snapshot. Version 2 stores one JSON file per event in the user's Google Drive
  `appDataFolder`.
- Event files are named `daily-sync-v2-event-{eventId}.json`. Non-secret app
  settings are stored separately in `daily-sync-v2-settings.json`.
- Local events and remote events are merged by event ID and the newest
  `updatedAt` or `deletedAt` timestamp.
- Deleted events are retained as tombstones so deletion can sync to other
  devices.
- Settings now has a Google Drive sync section with connect, manual sync, and
  disconnect actions.
- Automatic sync runs on app start, after Google Drive connection, when the app
  returns to the foreground, before the app backgrounds/exits, and after local
  event/settings changes.
- The app no longer polls Google Drive every few seconds while idle. Local
  event changes are debounced for 1 second so repeated edits trigger one Drive
  request without excessive cellular data use.
- If another sync request arrives while a sync is already running, one more
  sync pass is guaranteed after the current pass finishes.
- Event create/update/delete sync uploads only the changed event file. App
  start, Google Drive connection, resume, and manual sync list v2 event files
  and merge by event ID.
- All-day events are normalized to local date boundaries during sync and local
  database save/load. V2 event files include `startDate` and `endDate`
  date-only fields for all-day events, preventing iPhone/iOS UTC-midnight
  all-day events from appearing as two-day events on Android/Windows.
- Android Google Drive connection can receive a web OAuth client ID through:

```powershell
.\tool\flutter.ps1 run --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID="<web-client-id>"
```

- Windows Google Drive sync uses a desktop OAuth browser flow with PKCE and a
  local loopback callback. It can receive a Desktop app OAuth client ID through
  either an environment variable, a build define, or a local OAuth JSON config
  file. The current Daily Desktop OAuth client rejects token exchange without
  its generated client secret, so Windows installs must provide that secret from
  a local secret store, CI secret, or `%APPDATA%\Daily\google_desktop_oauth.json`.

```powershell
$env:GOOGLE_DESKTOP_CLIENT_ID = "<desktop-client-id>"
.\tool\flutter.ps1 run -d windows

.\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"
# $env:GOOGLE_DESKTOP_CLIENT_SECRET = "<desktop-client-secret>"
# .\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

Example local Windows config file, never committed:

```json
{
  "installed": {
    "client_id": "<desktop-client-id>",
    "client_secret": "<desktop-client-secret>"
  }
}
```

## Stage 2: Google Cloud/Firebase setup status

OAuth clients currently checked in or referenced by the app:

- Google Drive AppData target project for iPhone/iOS, Android, and Windows sync:
  `234127810480`
- Legacy Firebase metadata project still present in checked-in
  `android/app/google-services.json`:
  `424765276744`
- Android package name: `com.littlebit0.dailycalendar`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`
- Web OAuth client for Android Google Drive connection:
  `234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com`
- Android debug OAuth client:
  `234127810480-mst5c3lojau02lbdov924j8o7vaohonl.apps.googleusercontent.com`
- Android release OAuth client:
  `234127810480-otvrdan5a1q6gbqejulbp4e7tueebr4n.apps.googleusercontent.com`
- Windows Desktop OAuth client:
  `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`
- iOS bundle ID: `com.littlebit0.daily`
- iOS OAuth client:
  `234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa.apps.googleusercontent.com`
- iOS reversed client ID:
  `com.googleusercontent.apps.234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa`
- macOS bundle ID: `com.littlebit0.daily.macos`
- macOS OAuth client:
  `424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com`

Known configuration gaps:

- iOS Google Drive connection now has a checked-in iOS OAuth client for
  `com.littlebit0.daily`; keep `GIDServerClientID`/`SERVER_CLIENT_ID` absent
  unless a same-project iOS-specific server client is deliberately added.
- macOS Google Drive connection has a checked-in OAuth client and URL scheme.
  The native GoogleSignIn SDK path also requires keychain sharing entitlement in
  signed builds;
  local debug builds without an Apple development certificate keep that
  entitlement disabled so the app can still run in local mode.
- Android runtime now uses package `com.littlebit0.dailycalendar` and the
  project `234127810480` Web client so Android reads/writes the same Drive
  AppData v2 file set as the working iPhone build. The checked-in
  `google-services.json` still references legacy project `424765276744`; do not
  use it as the source of truth for Google Drive AppData sync.
- Windows must have the Desktop OAuth client secret available locally. Without
  it Google rejects the token exchange and the app shows a Google Drive token
  request failure.
- iPhone/iOS and macOS must implement the same v2 file layout. Do not keep
  writing or reading the abandoned `daily-sync-v1.json` snapshot on those
  platforms.

Still required before public release:

1. Confirm OAuth consent screen public-facing text, privacy policy, and support
   email.
2. After the first AAB upload, confirm whether Play App signing uses the same
   SHA-1 as the current Android release OAuth client. Add another Android OAuth
   client if Play Console App integrity reports a different app signing SHA-1.
3. Publish the OAuth app to production when the app is ready for external users.
4. Re-test Google Drive connection/sync from a fresh Google account.

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
2. Windows: the app now uses desktop OAuth instead of the unsupported native
   GoogleSignIn plugin path. A Desktop app OAuth client ID must be supplied
   through `GOOGLE_DESKTOP_CLIENT_ID` or `%APPDATA%\Daily\google_desktop_oauth.json`.
   The current 234 Desktop client also requires its generated client secret.
3. macOS: local mode builds and runs. The native GoogleSignIn SDK path is wired
   to the macOS OAuth client and URL scheme, but keychain sharing requires Apple
   development signing. If native GoogleSignIn is not suitable for the
   signing environment, build with
   `GOOGLE_MACOS_AUTH_MODE=desktop` and `GOOGLE_DESKTOP_CLIENT_ID` to use the
   browser OAuth flow instead. Add `GOOGLE_DESKTOP_CLIENT_SECRET` only when the
   Google Cloud Desktop client requires it.
4. iOS/iPadOS: local mode builds and runs. The iOS OAuth client and URL scheme
   are checked in; test the same Drive AppData sync flow on simulator and a
   connected iPhone after installing the latest build.

## Stage 4: Hardening before public release

- Add encryption for v2 event/settings sync files before treating this as
  production-grade private data storage.
- Add conflict UX for simultaneous edits on multiple devices.
- Add a sync status screen or last-sync timestamp.
- Test Google Drive connection and sync with a fresh Google account, two
  Android installs, and then each desktop/mobile platform.
- For public distribution, publish the OAuth consent screen to production and
  provide the required privacy policy/support links.
