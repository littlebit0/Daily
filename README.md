# Daily

Daily는 Flutter 기반 크로스 플랫폼 개인 캘린더 앱입니다. 로컬 SQLite를 우선 저장소로 사용하고, Google 계정을 연결하면 Google Drive AppData를 통해 Android, Windows, iOS, macOS 사이에서 일정과 앱 설정을 동기화합니다.

앱을 열면 주간 달력이 먼저 보이고, 필요할 때 월간/일간 보기로 전환할 수 있습니다. 날짜 칸 안에는 일정이 색상 플래그로 표시되며, 반복 일정, D-day, 음력, 공휴일, 로컬 알림, 민감 일정 숨김까지 개인 일정 관리에 필요한 흐름을 한 앱 안에서 처리합니다.

## 현재 버전

- 앱 버전: `2.5.14`
- Android 패키지명: `com.littlebit0.dailycalendar`
- 최신 공개 배포: [Daily 2.0.4](https://github.com/littlebit0/Daily/releases/tag/v2.0.4)
- 다음 Android Play 배포 준비 버전: `2.5.14`
- 저장소: [littlebit0/Daily](https://github.com/littlebit0/Daily)

## 배포 파일

GitHub Release에서 최신 설치 파일을 받을 수 있습니다.

- Android 직접 설치용 APK: `daily-android-2.0.4.apk`
- Windows 권장 배포 파일: `daily-windows-2.0.4.zip`
- macOS/iOS: 이번 2.0.4 릴리스에서는 신규 산출물을 만들지 않았습니다. macOS/iOS 작업자는 동일한 공유 Flutter 변경 적용 여부와 실제 UX/UI 시연 테스트를 별도로 진행해야 합니다.

Windows는 ZIP 사용을 권장합니다. Flutter Windows 앱은 실행 파일 외에도 DLL과 `data` 폴더가 필요하므로 일반 배포에는 `daily-windows-2.0.4.zip`을 사용해야 합니다.

SHA-256:

- `daily-android-2.0.4.apk`: `18080e2fedebbc48a2e685e8d7a529930125b26e795c1af31fc8732b72385681`
- `daily-windows-2.0.4.zip`: `5f465ed937a2afd9079ff7c62b78a68890bc11686073261031fcf4d042faec87`

## 지원 플랫폼

- Android
- Windows
- iOS
- macOS

Android와 Windows 산출물은 2.0.4 릴리스에 포함되어 있습니다. iOS/macOS는 같은 Flutter 기능 세트와 동기화 구조를 기준으로 유지되어야 하며, 이번 Windows/Android 작업에서 확인한 항목 중 Android/Windows에만 고질적으로 발생한 현상을 제외하고 동일하게 검토해야 합니다. 실제 App Store/TestFlight/Developer ID 배포에는 Apple Developer 서명과 provisioning 설정이 필요합니다.

## 핵심 기능

- 주간/월간/일간 달력 보기 전환
- 월간 달력 스와이프 이동과 자연스러운 페이지 전환
- 날짜별 일정 색상 플래그 표시
- 연속 일정의 다중 날짜 플래그 표시
- 날짜 드래그 범위 선택 후 일정 추가
  - Windows: 마우스 드래그
  - Android: 길게 누른 뒤 드래그
- 날짜 상세 패널과 모바일 하단 시트
- 일정 추가, 수정, 삭제, 삭제 확인
- 반복 일정 모델과 반복 일정 수정/삭제 범위 선택
- 일정 검색과 달력 필터
- 일정 URL, 위치, 날씨 메모, 민감 일정 표시
- 일정별 D-day 표시와 D-day 알림
- 대한민국 공휴일, 대체공휴일, 토/일/공휴일 색상 표시
- 음력 날짜 표시
- 주 시작 요일 설정
- 사용자 분류 추가/삭제
- 로컬 알림, 하루 종일 일정 알림, 아침 브리핑 알림
- 앱 잠금 PIN과 민감 일정 숨김
- Android 월간/오늘/D-day 위젯 진입점
- Windows 창 닫기 후 백그라운드/트레이 유지
- Windows 트레이 미니 캘린더
- macOS 마지막 창 닫기 후 앱 유지
- iOS/macOS 빠른 접근 패널
- Google 계정 로그인
- Google Drive AppData 기반 백업, 복원, 자동 동기화

## 동기화 구조

Daily는 자체 서버를 운영하지 않고 Google Drive `appDataFolder`에 앱 전용 JSON 파일을 저장합니다.

2.0.0부터 기존 단일 `daily-sync-v1.json` 방식은 정상 동기화 경로에서 사용하지 않습니다. 현재 동기화는 v2 파일 세트를 사용합니다.

```plain text
daily-sync-v2-event-{eventId}.json
- schemaVersion: 2
- type: event
- event: 단일 일정 JSON
- 하루 종일 일정: startDate, endDate 날짜 전용 필드 포함

daily-sync-v2-settings.json
- schemaVersion: 2
- type: settings
- settings: 비밀값을 제외한 앱 설정
```

동작 방식:

- 일정 생성, 수정, 삭제 시 변경된 일정 파일만 업로드
- 삭제는 tombstone으로 남겨 다른 기기에 삭제 상태 전파
- 앱 첫 실행, Google 로그인 직후, 포그라운드 복귀, 수동 동기화 때 v2 일정 파일 목록 병합
- 로컬/원격 충돌은 일정별 `updatedAt` 또는 `deletedAt` 기준으로 최신 상태 선택
- 하루 종일 일정은 `startDate`/`endDate`를 우선 사용해 플랫폼별 시간대 변환으로 날짜가 밀리지 않도록 처리
- 설정은 `daily-sync-v2-settings.json`으로 일정 파일과 분리

이 방식은 전체 백업 파일을 반복 업로드하지 않기 때문에 셀룰러 데이터 사용량과 동시 수정 충돌 가능성을 줄입니다.

## Google OAuth 설정

현재 Google Drive AppData 동기화 기준 프로젝트는 `234127810480`입니다.

- Android 패키지명: `com.littlebit0.dailycalendar`
- Android Web OAuth client: `234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com`
- Windows Desktop OAuth client: `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`
- iOS OAuth client: `234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa.apps.googleusercontent.com`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`

Windows/macOS Desktop OAuth는 PKCE loopback callback을 사용합니다. 현재 Windows Desktop OAuth client는 token exchange에 client secret을 요구하므로 secret은 Git에 커밋하지 않고 로컬 환경 변수 또는 로컬 OAuth JSON 파일로만 공급합니다.

Windows 로컬 OAuth JSON 예시:

```json
{
  "installed": {
    "client_id": "<desktop-client-id>",
    "client_secret": "<desktop-client-secret>"
  }
}
```

지원 경로:

- `%APPDATA%\Daily\google_desktop_oauth.json`
- `%LOCALAPPDATA%\Daily\google_desktop_oauth.json`
- `GOOGLE_DESKTOP_OAUTH_CONFIG`
- `GOOGLE_DESKTOP_CLIENT_SECRET`

자세한 설정은 [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)을 참고합니다.

## 프로젝트 구조

```plain text
lib/
- app/                         앱 루트와 lifecycle sync
- core/calendar/               공휴일, 음력 계산
- core/notifications/          로컬 알림, D-day, 브리핑 알림
- core/settings/               앱 설정과 secure storage
- core/sync/                   Google OAuth, Google Drive v2 sync
- features/calendar/           주간/월간/일간 달력 UI
- features/events/             일정 도메인, drift 저장소, 입력/수정 흐름
- features/onboarding/         첫 실행과 Google 연결
- features/search/             일정 검색
- features/settings/           설정, 동기화 상태, 계정/데이터 관리
```

## 개발 명령

```powershell
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
```

Android debug:

```powershell
.\tool\flutter.ps1 build apk --debug
```

Android release:

```powershell
.\tool\flutter.ps1 build apk --release
.\tool\flutter.ps1 build appbundle --release
```

Windows debug:

```powershell
.\tool\flutter.ps1 build windows --debug
```

Windows release:

```powershell
.\tool\flutter.ps1 build windows --release
```

`tool/flutter.ps1`은 프로젝트 상위 폴더의 `flutter-sdk`, `PubCache`, `GradleCache`, `AndroidSdk`, `Temp`를 우선 사용합니다.

## 검증 상태

2.0.0 기준 확인한 항목:

- `.\tool\flutter.ps1 analyze --no-pub`: 통과
- `.\tool\flutter.ps1 test --no-pub`: 통과
- Google Drive v2 동기화 테스트 통과
- Android debug APK 빌드, 에뮬레이터 삭제 후 재설치/실행 확인
- Android release APK 빌드 통과
- Android release AAB 빌드 통과
- Android APK badging 확인
  - package: `com.littlebit0.dailycalendar`
  - versionName: `2.0.0`
  - versionCode: `4`
- Windows debug/release 빌드 통과
- Windows release 실행 확인
- GitHub Release 2.0.0 업로드 확인

## 스토어 배포 상태

GitHub Release 배포는 완료했습니다.

Android Play Store 배포는 보류 상태입니다. 업로드 파일은 준비되어 있습니다.

```plain text
dist/daily-android-2.0.0.aab
```

Play Console 업로드 후 Play App Signing SHA-1이 기존 OAuth Android client와 다르면 Google Cloud Console에 Android OAuth client를 추가해야 합니다.

Microsoft Store 배포도 보류 상태입니다. Store 제출용 MSIX를 만들려면 Partner Center의 Product identity 값이 필요합니다.

- Package/Identity/Name
- Package/Properties/Publisher
- PublisherDisplayName

## 보안과 로컬 비밀값

다음 파일과 값은 Git에 커밋하지 않습니다.

- Android upload keystore: `android/app/upload-keystore.jks`
- Android signing config: `android/key.properties`
- Desktop OAuth client secret
- Apple signing identity와 provisioning profile
- GitHub/Google API token

Android keystore는 이후 Play Store 업데이트에 필요하므로 별도 안전한 위치에 백업해야 합니다.

## 문서

- [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)
- [릴리스 노트 2.0.4](docs/RELEASE_NOTES_2.0.4.md)
- [릴리스 노트 2.0.0](docs/RELEASE_NOTES_2.0.0.md)
- [현재 진행상태](docs/PROGRESS_STATUS.md)
- [릴리스 체크리스트](docs/RELEASE_CHECKLIST.md)
- [Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)
- [후속 기능 로드맵](docs/FEATURE_ROADMAP.md)
- [상세 요구사항](DAILY_REQUIREMENTS.md)

## 남은 작업

- Play Console 배포와 심사 정보 작성
- Microsoft Store Partner Center identity 확보 후 Store용 MSIX 생성
- fresh Google 계정으로 Android/Windows/iOS/macOS 간 v2 동기화 재검증
- Android 실제 기기 알림 검증
- Apple Developer 서명, TestFlight/App Store, macOS Developer ID 배포 설정
- Google Drive AppData v2 파일 암호화 검토
- 동시 수정 충돌을 사용자에게 보여주는 conflict UX 추가
