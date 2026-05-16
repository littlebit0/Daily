# Release Checklist

## Android

- Build artifact: `build/app/outputs/bundle/release/app-release.aab`.
- Confirm `android/key.properties` exists on the release machine and points to
  the upload keystore.
- Confirm Firebase Android app has debug and upload/release SHA-1/SHA-256
  fingerprints.
- Confirm OAuth consent screen is published before external Google accounts are
  expected to sign in.
- Test on a clean Android install:
  1. Welcome screen appears.
  2. Google login restores Drive snapshot.
  3. Notification permission prompt appears.
  4. Create, edit, delete, and sync an event.
  5. Reinstall and confirm restore.
  6. Log out from Settings and confirm the welcome screen appears.
  7. Run membership withdrawal and confirm local data is cleared and the Drive
     app-data backup is deleted.

## Windows

- Build artifact: `build/windows/x64/runner/Release/daily.exe`.
- The Windows app can be packaged from the release directory.
- Google Drive sync currently degrades gracefully on platforms where
  `google_sign_in` has no native implementation. Before public Windows release,
  add and test a desktop OAuth browser flow if Windows sync must be available.

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
