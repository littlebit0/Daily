# Release Checklist

## Android

- Build artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Confirm `android/key.properties` exists on the release machine and points to
  the upload keystore.
- Confirm Google OAuth Android client has the package name and upload/release
  SHA-1/SHA-256 fingerprints.
- Confirm OAuth consent screen is published before external Google accounts are
  expected to sign in.
- Test on a clean Android install:
  1. Welcome screen appears.
  2. Google login restores the Drive v2 event/settings file set.
  3. Notification permission prompt appears.
  4. Create, edit, delete, and sync an event.
  5. Reinstall and confirm restore.
  6. Log out from Settings and confirm the welcome screen appears.
  7. Add URL, weather, sensitive flag, D-day, and recurrence edits to a sample
     event.
  8. Run membership withdrawal and confirm local data is cleared and the Drive
     app-data backup is deleted.

## Windows

- Build artifact: `build/windows/x64/runner/Release/daily.exe`.
- The Windows app can be packaged from the release directory.
- The distributed ZIP must include `daily.exe`, DLL files, and the `data`
  directory from `build/windows/x64/runner/Release`.
- Google Drive sync uses the desktop OAuth browser flow on Windows. Build with
  the Desktop OAuth client ID and secret supplied through dart defines.
- Closing the main window should leave the app running in the tray, and the
  tray mini calendar should open from the tray menu.

## Store and Consent Assets

- Privacy policy URL
- Support email
- Data deletion instructions
- Short app description
- Screenshots for Android and Windows
- Clear statement that AI features are currently in development and disabled

## Final QA Pass

- Run `flutter analyze`.
- Run `flutter test`.
- Build Android release.
- Build Windows release.
- Verify Google Drive sync with at least one fresh account.
- Verify Korea public holidays around Seollal, Chuseok, Buddha's Birthday,
  Children's Day, Constitution Day, Labor Day from 2027, and substitute
  holidays.
