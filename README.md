# Daily

Daily는 Flutter 기반 크로스 플랫폼 개인 캘린더 앱입니다. 로컬 SQLite를 우선 저장소로 사용하고, Google 계정을 연결하면 Google Drive AppData를 통해 Android, Windows, iOS, macOS 사이에서 일정과 앱 설정을 동기화합니다.

앱을 열면 설정한 기본 달력이 보이고 빠른 보기, 주간, 월간, 일간 및 연간 보기로 전환할 수 있습니다. 반복 일정, D-day, 음력, 공휴일, 알림과 알람, 위젯, 앱 잠금, 외부 캘린더 가져오기까지 개인 일정 관리에 필요한 흐름을 한 앱 안에서 처리합니다.

## 현재 버전

- 앱 버전: `3.0.1 (3.0.1)`
- Android 패키지명: `com.littlebit0.dailycalendar`
- Apple 앱/위젯 번들 ID: `com.littlebit0.daily`, `com.littlebit0.daily.widgets`
- 현재 릴리스: `3.0.1`
- 저장소: [littlebit0/Daily](https://github.com/littlebit0/Daily)

## 배포 파일

GitHub Release에는 릴리스별 설치 파일을 업로드합니다.

3.0.1은 2.7.1 이후 추가된 Apple 위젯, 일정 알람, 외부 캘린더 가져오기,
연간 보기, 상하 연속 월 스크롤, 다크 테마, 잠금 방식, Google Drive 동기화
안정화와 검색·스크롤 성능 개선을 포함합니다.

- GitHub Release IPA: `daily-ios-3.0.1-unsigned.ipa`
- GitHub Release macOS DMG: `daily-macos-3.0.1-unsigned.dmg`
- GitHub Release Android APK: `daily-android-3.0.1-debug.apk`
- GitHub Release Windows ZIP: `daily-windows-3.0.1.zip`

공유 설정과 Google Drive 동기화 스키마 변경이 포함되어 네 플랫폼 산출물을 같은
릴리스에 제공합니다. Android와 Windows는 자동 빌드 검증 후 실제 OS에서 계정,
동기화, 알림과 새 공유 화면 흐름을 추가로 확인해야 합니다.

## 지원 플랫폼

- Android
- Windows
- iOS
- macOS

iOS 앱 `DailyCalendar`는 Apple App Store에서 무료 앱으로 배포 중입니다. iOS와
macOS `3.0.1 (3.0.1)` 빌드는 App Store Connect에 업로드되었고, 제품 설명과 심사
메모도 3.0.1 기준으로 갱신했습니다. GitHub IPA와 DMG는 App Store 설치 파일이
아니며 별도 설치 및 검증용 산출물입니다.

현재 계정/동기화 정책은 다음과 같습니다.

- Apple 로그인 지원 플랫폼: iOS, macOS
- Google Drive AppData 동기화 지원 플랫폼: Android, Windows, iOS, macOS
- Apple 로그인 후 저장된 Google Drive 세션이 있으면 자동으로 복원
- 저장된 Google Drive 세션이 없으면 Apple/local 모드로 진입하고 Google 로그인을 강제하지 않음
- Google 로그인 후 현재 기기에 저장된 Apple 연결 표시가 있으면 상태를 유지
- 서버 기반 Apple/Google 계정 병합은 아직 구현하지 않았으며 기기 간 연결 관계 복원은 지원하지 않음
- 설정의 계정 섹션은 Apple/Google 상태를 분리해서 보여주되 `로그아웃` 버튼은 하나만 표시
- 일반 `로그아웃`은 pending 변경 백업을 시도한 뒤 로컬 일정과 설정, 기기 인증 세션을 지우고 시작 화면으로 이동하며 Drive AppData는 유지
- `계정 삭제`는 로컬 데이터, Apple/Google 연결 상태, Google Drive AppData 백업을 삭제하는 파괴적 경로

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
- 일정 URL, 위치와 날씨 메모
- 일정별 D-day 표시와 D-day 알림
- 대한민국 공휴일, 대체공휴일, 토/일/공휴일 색상 표시
- 음력 날짜 표시
- 주 시작 요일 설정
- 사용자 분류 추가/삭제
- 로컬 알림, 하루 종일 일정 알림, 아침 브리핑 알림
- 복수 기본 일정 알림과 일정별 복수 알림
- Apple·Samsung·Google 캘린더 데이터 가져오기
- iOS 26 이상 일정별 시스템 알람, 중지와 10분 후 다시 알림
- macOS 일정별 시스템 알림, 소리와 10분 후 다시 알림
- PIN 없음 보호, Daily PIN, Apple 시스템 인증 방식의 앱 잠금
- iPhone/iPad 홈 화면용 오늘 일정, 주간·월간 달력, D-day 위젯
- iPhone/iPad 잠금화면용 오늘 일정 한 줄형·원형·직사각형 위젯
- macOS 알림 센터와 바탕화면용 오늘 일정, 월간 달력, D-day 위젯
- Android 월간/오늘/D-day 위젯 진입점
- Windows 창 닫기 후 백그라운드/트레이 유지
- Windows 트레이 미니 캘린더
- macOS 마지막 창 닫기 후 앱 유지
- iOS/macOS 빠른 접근 패널
- Apple 로그인
- Google 계정 로그인
- Apple/Google 계정 연결 상태 자동 복원
- 설정의 통합 로그아웃과 계정 삭제
- Google Drive AppData 기반 백업, 복원, 자동 동기화

Apple 위젯은 앱의 로컬 일정 스냅샷을 App Group으로 공유합니다. 잠금화면 위젯은
오늘 남은 일정을 표시하며, 시스템 개인정보 설정에 따라 일정 제목이 가려질 수
있습니다.

iOS 26 이상에서는 반복하지 않는 일정마다 시스템 알람을 선택할 수 있습니다.
시간 일정은 시작 시각에 울리고, 종일 일정은 사용자가 지정한 시각에 울립니다.
일반 일정 알림은 함께 유지되며 알람을 선택한 경우에만 시작 시각의 정시 알림을
알람으로 대체합니다. 반복 일정 알람은 추후 루틴 기능에서 별도로 제공합니다.

macOS에서는 같은 일정 알람 설정을 앱이 종료된 상태에서도 전달되는 예약 시스템
알림으로 제공합니다. 알림에는 소리, 중지, 10분 후 다시 알림이 포함됩니다.
macOS는 AlarmKit을 지원하지 않으므로 iPhone의 전체 화면 지속 알람 UI 대신
macOS 알림센터의 네이티브 알림 형태로 동작합니다.

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

iOS Google Drive 연결은 `ASWebAuthenticationSession` 기반 인앱 인증 시트를
사용합니다. 앱 밖 Safari로 완전히 전환하지 않고 Daily 위에 인증 화면을 띄우며,
Google callback URL은 iOS 네이티브 브리지에서 처리합니다.

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

3.0.1 Apple 제출 후보 기준 확인한 항목:

- `./tool/flutter.sh analyze --no-pub`: 통과
- `./tool/flutter.sh test --no-pub`: 전체 142개 통과
- `./tool/flutter.sh test --no-pub test/widget_test.dart`: 48개 통과
- `./tool/flutter.sh build ios --simulator --debug --no-pub`: 통과
- App Store iOS IPA와 macOS PKG의 앱/위젯 버전 및 빌드 `3.0.1`: 확인
- iPhone 17 시뮬레이터 설치 확인
- Apple 로그인 후 Google Drive 자동 연결/복원 흐름 회귀 테스트 통과
- Google 로그인 후 Apple 연결 표시 보존 회귀 테스트 통과
- 설정 통합 로그아웃 정책 회귀 테스트 통과

macOS, Android, Windows는 같은 공유 Flutter 계정/동기화 정책을 따라야 합니다.
다음 각 플랫폼 작업자는 실제 기기 또는 해당 OS에서 아래 항목을 다시 확인해야 합니다.

- fresh install 후 Apple/Google/local 시작 흐름
- Apple 로그인 후 Google Drive 자동 복원 또는 Apple/local 모드 진입
- Google 로그인 후 기존 Apple 연결 표시 유지
- 일반 로그아웃 후 재로그인 시 저장된 계정 연결 자동 복원
- 계정 삭제 후 로컬 데이터, 계정 표시, Drive 백업 삭제
- 일정 생성/수정/삭제 v2 AppData 동기화

## 스토어 배포 상태

`DailyCalendar` iOS 앱은 App Store에서 무료 앱으로 배포 중입니다. iOS와 macOS
`3.0.1 (3.0.1)` 제출 빌드는 Transporter 업로드 및 Apple 처리 완료 상태이며,
App Store Connect의 3.0.1 제품 정보와 심사 메모가 준비되어 있습니다.

App Store Connect에서 확인 또는 수정할 항목:

- App Review Notes:
  - Apple과 Google 로그인이 모두 제공됨
  - Google Drive 권한은 Google Drive AppData의 Daily 전용 백업/동기화에만 사용됨
  - 일반 Google Drive 파일은 읽거나 수정하지 않음
  - 광고, IDFA, 앱/웹사이트 간 사용자 추적, 데이터 브로커 공유 없음
- App Privacy:
  - 추적 목적 데이터 수집으로 표시하지 않기
  - 실제 사용하는 데이터 유형만 표시
  - Google Drive AppData 동기화와 Apple/Google 로그인은 앱 기능 목적
- Encryption:
  - 별도 독자 암호화 알고리즘을 구현하지 않았다면 해당 없음으로 답변
- Build:
  - iOS와 macOS에서 각각 `3.0.1 (3.0.1)` 빌드를 선택
  - 수출 규정 질문을 확인한 뒤 두 플랫폼을 같은 심사 제출에 추가

Android Play Store와 Microsoft Store 배포는 보류 상태입니다. 다음 플랫폼 릴리스
전에는 Android와 Windows 체크리스트 검증을 완료해야 합니다.

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
- [릴리스 노트 3.0.1](docs/RELEASE_NOTES_3.0.1.md)
- [App Store 업그레이드 사항 3.0.1](docs/APP_STORE_WHATS_NEW_3.0.1.md)
- [App Review 메모 3.0.1](docs/APP_REVIEW_NOTES_3.0.1.md)
- [릴리스 노트 2.6.0](docs/RELEASE_NOTES_2.6.0.md)
- [릴리스 노트 2.0.4](docs/RELEASE_NOTES_2.0.4.md)
- [릴리스 노트 2.5.17](docs/RELEASE_NOTES_2.5.17.md)
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
- App Store Connect에서 iOS/macOS 3.0.1 최종 심사 제출
- macOS App Store 승인 후 실제 설치·업데이트 검증
- Google Drive AppData v2 파일 암호화 검토
- 동시 수정 충돌을 사용자에게 보여주는 conflict UX 추가
