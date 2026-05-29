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

- Windows Google Drive sync uses a desktop OAuth browser flow with PKCE and a
  local loopback callback. It can receive a Desktop app OAuth client ID through
  either an environment variable or a build define. The Desktop OAuth client
  secret is optional for Google's installed app flow. The current Daily Desktop
  OAuth client rejects token exchange without it, so release builds should pass
  `GOOGLE_DESKTOP_CLIENT_SECRET` from a local secret store or CI secret:

```powershell
$env:GOOGLE_DESKTOP_CLIENT_ID = "<desktop-client-id>"
.\tool\flutter.ps1 run -d windows

.\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"
# Optional:
# $env:GOOGLE_DESKTOP_CLIENT_SECRET = "<desktop-client-secret>"
# .\tool\flutter.ps1 build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

## Stage 2: Google Cloud/Firebase setup status

OAuth clients currently checked in or referenced by the app:

- Google Cloud project number: `424765276744`
- Android package name: `com.littlebit0.dailycalendar`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`
- Web OAuth client for Android sign-in:
  `424765276744-j32k4bdck7lr4ba0lg5s99u91c4849bp.apps.googleusercontent.com`
- Windows Desktop OAuth client:
  `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`
- iOS bundle ID: `com.littlebit0.daily`
- macOS bundle ID: `com.littlebit0.daily.macos`
- macOS OAuth client:
  `424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com`

Known configuration gaps:

- iOS Google Sign-In still needs an Apple OAuth client for
  `com.littlebit0.daily` and its reversed client ID URL scheme in
  `ios/Runner/Info.plist`.
- macOS Google Sign-In has a checked-in OAuth client and URL scheme. Native
  Google Sign-In also requires keychain sharing entitlement in signed builds;
  local debug builds without an Apple development certificate keep that
  entitlement disabled so the app can still run in local mode.
- The checked-in `android/app/google-services.json` contains Android OAuth
  clients for `com.littlebit0.daily`, while the current Gradle `applicationId`
  is `com.littlebit0.dailycalendar`. Reconcile this before the next Android
  release.

Still required before public release:

1. Confirm OAuth consent screen public-facing text, privacy policy, and support
   email.
2. After the first AAB upload, add another Android OAuth client using the Play
   Console app signing certificate SHA-1 from App integrity.
3. Publish the OAuth app to production when the app is ready for external users.
4. Re-test Google Drive sign-in/sync from a fresh Google account.

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
   Google Sign-In plugin path. A Desktop app OAuth client ID must be supplied
   through `GOOGLE_DESKTOP_CLIENT_ID`. The generated client secret is optional
   for the installed app token exchange; provide it through
   `GOOGLE_DESKTOP_CLIENT_SECRET` only if that particular OAuth client requires
   it.
3. macOS: local mode builds and runs. Native Google Sign-In is wired to the
   macOS OAuth client and URL scheme, but keychain sharing requires Apple
   development signing. If native Google Sign-In is not suitable for the
   signing environment, build with
   `GOOGLE_MACOS_AUTH_MODE=desktop` and `GOOGLE_DESKTOP_CLIENT_ID` to use the
   browser OAuth flow instead. Add `GOOGLE_DESKTOP_CLIENT_SECRET` only when the
   Google Cloud Desktop client requires it.
4. iOS/iPadOS: local mode builds and runs. Add the iOS Apple OAuth client and
   URL scheme, then test the same Drive AppData sync flow.

## Stage 4: Hardening before public release

- Add encrypted sync snapshots before treating this as production-grade private
  data storage.
- Add conflict UX for simultaneous edits on multiple devices.
- Add a sync status screen or last-sync timestamp.
- Test sign-in and sync with a fresh Google account, two Android installs, and
  then each desktop/mobile platform.
- For public distribution, publish the OAuth consent screen to production and
  provide the required privacy policy/support links.
