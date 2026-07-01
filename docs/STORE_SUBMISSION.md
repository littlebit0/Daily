# Daily Apple App Store Submission Plan

Current app version: `2.0.5`

Scope for this pass: Apple App Store submission only. Google Play and
Microsoft Store submission are intentionally deferred.

## Store Metadata Draft

- App name: `Daily`
- Subtitle: `계정 없이 시작하고 필요할 때 동기화하는 개인 캘린더`
- Primary category: Productivity
- Secondary category: Lifestyle
- Support URL: `https://github.com/littlebit0/Daily/issues`
- Marketing URL: `https://github.com/littlebit0/Daily`
- Privacy policy URL: pending public hosted URL
- Contact email: pending

## Korean Listing Draft

### Short Description

일정 입력, 알림, D-day, 선택적 Google Drive 동기화를 지원하는 개인 캘린더입니다.

### Full Description

Daily는 일정을 빠르게 기록하고 여러 기기에서 이어서 사용할 수 있는 개인 캘린더 앱입니다.

- 월간, 주간, 일간 보기
- 일정 알림과 아침 브리핑
- D-day 표시와 알림
- 민감 일정 숨김
- 선택적 Google Drive AppData 백업 및 동기화
- 로컬 모드 사용
- iPhone, iPad, Mac 지원

Daily의 Google 동기화는 사용자의 Google Drive AppData 영역에 앱 전용
데이터만 저장합니다. 사용자의 일반 Drive 파일을 읽거나 변경하지 않습니다.

## English Listing Draft

### Short Description

A personal calendar with reminders, D-day tracking, and optional Google Drive sync.

### Full Description

Daily is a personal calendar for quickly saving schedules and keeping them
available across Apple devices.

- Month, week, and day calendar views
- Event reminders and morning briefing
- D-day tracking and notifications
- Sensitive event hiding
- Optional Google Drive AppData backup and sync
- Local-only mode
- iPhone, iPad, and Mac support

Daily stores sync data only in your app-specific Google Drive AppData folder.
It does not read or edit your regular Drive files.

## Apple References

- Create an App Store Connect app record:
  https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- Upload builds:
  https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Create an App Store provisioning profile:
  https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/
- Xcode distribution overview:
  https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/

## Identifiers

- iOS bundle ID: `com.littlebit0.daily`
- macOS bundle ID: `com.littlebit0.daily.macos`
- Version: `2.0.5`
- Build: `11`

## Local Submission Readiness

- Daily app icons have replaced the default Flutter icons for iOS and macOS.
- The iOS launch image has been replaced with a Daily-branded launch image.
- iOS archive creation succeeds at `build/ios/archive/Runner.xcarchive`.
- App Store IPA export is currently blocked by Apple signing/provisioning.

Current local signing state:

- Local keychain has only:
  `Apple Development: kimhee8953@naver.com (739BC896PZ)`
- No `Apple Distribution` / `iOS Distribution` certificate is installed.
- No local App Store provisioning profile exists for `com.littlebit0.daily`.
- Xcode reports that team `Hwi Kim` cannot create iOS App Store provisioning
  profiles from this account/session.
- A direct `xcodebuild -exportArchive -allowProvisioningUpdates` retry on
  2026-06-01 also failed with `No provider associated with App Store Connect
  user`, `No Account for Team "739BC896PZ"`, and no `iOS Distribution`
  certificate. This means the local Xcode account is not yet connected to a
  usable App Store Connect provider for distribution uploads.

## Required Apple Account Actions

1. In App Store Connect, create the app record before uploading the first build.
2. Make sure the account has Account Holder or Admin rights for Certificates,
   Identifiers & Profiles.
3. Create or let Xcode create an Apple Distribution certificate.
4. Create App Store Connect provisioning profiles for:
   - `com.littlebit0.daily`
   - `com.littlebit0.daily.macos` if submitting the Mac app in the same pass
5. Re-run the App Store archive/export from Xcode Organizer or Flutter.
6. Upload the build with Xcode Organizer, Transporter, or `xcrun altool`.
7. Complete screenshots, privacy nutrition labels, age rating, support URL,
   privacy policy URL, and review notes.

## Review Notes Draft

Daily can be used in local-only mode without signing in or creating an account.
Google authorization is optional and is used only when the user chooses Google
Drive backup/sync for their own calendar data through the app-specific Google
Drive AppData folder.

Suggested reviewer note:

```text
Daily does not require users to sign in or create a Daily account. The app can
be fully reviewed in local-only mode by choosing "로컬로 시작" on the welcome
screen.

The Google option is not used to create or authenticate a Daily primary account.
It is an optional Google Drive authorization used only when the user chooses
Google Drive backup/sync. Daily uses the Google Drive AppData folder only for
app-specific calendar sync and does not read, list, or modify the user's regular
Google Drive files.
```

## App Review 2026-06-25 Response

### Guideline 5.1.2(i)

App Privacy should be updated in App Store Connect so the collected data is not
marked as "Data Used to Track You." Daily does not use advertising, ad
measurement, data brokers, IDFA, or cross-app/site tracking.

Use the following privacy label structure:

- Data collection: Yes.
- Data types: Email Address, User ID, Other User Content.
- Purpose: App Functionality only.
- Linked to identity: Yes for the Google account email/user ID and synced
  calendar content when Google Drive sync is enabled.
- Used for tracking: No.

Suggested reply:

```text
We have updated the App Privacy information. Daily does not track users across
apps or websites, does not use IDFA, does not include advertising or advertising
measurement, and does not share collected data with data brokers. The Google
account email/user ID and calendar content are used only for app functionality:
optional Google Drive AppData backup and sync selected by the user.
```

### Guideline 4.8

The submitted UI used "Google login" wording, which could make the optional
Google Drive authorization appear to be a primary account login. The app has
been updated to clarify that Daily can be fully used without an account and
that Google is only an optional Drive backup/sync connection.

Suggested reply:

```text
Daily does not use Google to set up or authenticate a Daily primary account.
Users can use all calendar features without signing in by selecting local mode
on the welcome screen. The Google option is an optional Google Drive
authorization for app-specific backup and sync in the user's Google Drive
AppData folder.

We updated the app UI to make this clearer: the welcome screen now states that
all calendar features are available without an account, and the Google action
is labeled as Google Drive backup/sync rather than primary account login.
```
