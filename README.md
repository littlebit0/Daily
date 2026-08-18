# DailyCalendar

<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="128" alt="DailyCalendar 앱 아이콘">
</p>

<p align="center">
  일정을 빠르게 기록하고 여러 기기에서 이어서 사용하는 개인 캘린더
</p>

<p align="center">
  <a href="https://github.com/littlebit0/Daily/releases/latest"><img src="https://img.shields.io/github/v/release/littlebit0/Daily?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/version-3.1.0-2f6feb" alt="Version 3.1.0">
  <img src="https://img.shields.io/badge/Flutter-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows-02569B?logo=flutter" alt="Flutter platforms">
</p>

DailyCalendar는 월간, 주간, 일간 및 연간 보기로 일정을 관리하는 Flutter 기반
크로스 플랫폼 캘린더입니다. 계정 없이 로컬로 사용할 수 있으며, Google 계정을
연결하면 Google Drive AppData를 통해 일정과 설정을 백업하고 동기화할 수
있습니다.

## 다운로드

최신 공개 릴리스는 [GitHub Releases](https://github.com/littlebit0/Daily/releases/latest)에서
확인할 수 있습니다.

| 플랫폼 | 배포 상태 | 파일 |
| --- | --- | --- |
| iPhone / iPad | App Store 무료 배포 중 | App Store의 `DailyCalendar` |
| iOS 테스트 | GitHub 공개 검증용 미서명 파일 | [daily-ios-3.1.0-unsigned.ipa](https://github.com/littlebit0/Daily/releases/download/v3.1.0/daily-ios-3.1.0-unsigned.ipa) |
| macOS 테스트 | GitHub 공개 검증용 미서명 파일 | [daily-macos-3.1.0-unsigned.dmg](https://github.com/littlebit0/Daily/releases/download/v3.1.0/daily-macos-3.1.0-unsigned.dmg) |
| Android / Windows | 소스 지원, 3.1.0 실기기 검증 진행 중 | 검증 완료 후 릴리스 제공 |

> GitHub의 IPA와 DMG는 App Store 제출 파일이 아닙니다. 미서명 IPA는 별도
> 서명 없이는 iPhone에 직접 설치할 수 없으며, 재서명 과정에서 Sign in with
> Apple 같은 entitlement가 유지되지 않을 수 있습니다. 일반 사용자는 App Store
> 설치본을 권장합니다.

## 주요 기능

### 캘린더와 일정

- 월간, 주간, 일간, 연간 및 빠른 보기
- 주간·일간 시간표형 보기와 종일 일정 표시 제어
- 일정 추가, 수정, 삭제, 검색 및 분류 필터
- 반복 일정, 연속 일정, D-day, 음력과 대한민국 공휴일
- 날짜 범위 드래그를 통한 연속 일정 입력
- 외부 캘린더 가져오기
- 위치, 지도 바로가기, 링크, 메모와 날씨 정보

### 알림과 위젯

- 일정별 복수 알림과 아침 브리핑
- iOS 26 이상 일정별 시스템 알람
- iPhone, iPad 및 macOS의 오늘 일정·주간·월간·D-day 위젯
- iPhone 및 iPad 잠금화면 위젯
- 일정 변경 시 알림, 알람과 위젯 즉시 갱신

### Siri와 자동화

- iOS 및 macOS Siri/App Intents 일정 조회, 검색, 추가, 수정과 삭제
- 일정 변경 전 필수 정보 확인과 사용자 승인
- 설정에서 날짜별 Siri 실행 기록 및 상세 결과 확인
- Siri 작업 결과를 캘린더, 위젯, 알림과 동기화 상태에 즉시 반영

### 계정과 동기화

- 계정 없는 로컬 모드
- iOS 및 macOS Sign in with Apple
- 선택형 Google 계정 연결
- Google Drive AppData 기반 일정·설정 백업 및 동기화
- 일정별 증분 동기화, 삭제 tombstone과 충돌 병합
- 통합 로그아웃 및 로컬·클라우드 데이터 삭제 흐름

### 개인 설정

- 한국어, 영어, 일본어, 중국어 번체
- 시스템 언어 자동 적용 및 앱별 언어 선택
- 라이트·다크 테마와 반응형 글자 크기
- 사용자 분류, 직접 선택 색상과 분류별 표시 설정
- PIN 없음 보호, Daily PIN 및 Apple 시스템 인증 앱 잠금

## 플랫폼

| 기능 | iOS / iPadOS | macOS | Android | Windows |
| --- | :---: | :---: | :---: | :---: |
| 캘린더와 로컬 저장 | O | O | O | O |
| Google Drive AppData 동기화 | O | O | O | O |
| Sign in with Apple | O | O | - | - |
| Siri / App Intents | O | O | - | - |
| Apple 위젯 | O | O | - | - |
| 앱 잠금 | O | O | O | O |

공유 Flutter 코드가 네 플랫폼의 사용자 경험을 유지합니다. Android와 Windows의
3.1.0 배포 파일은 각 실제 OS에서 계정, 동기화, 알림과 UI 회귀 검증을 마친 뒤
제공할 예정입니다.

## 데이터와 개인정보 보호

- 일정과 설정은 기본적으로 기기의 로컬 SQLite 데이터베이스에 저장됩니다.
- Google 연결은 선택 사항이며 앱 전용 `appDataFolder`만 사용합니다.
- 일반 Google Drive 파일은 읽거나 수정하지 않습니다.
- 별도 일정 백엔드 서버를 운영하지 않습니다.
- 광고, IDFA, 광고 측정, 데이터 브로커 공유 및 앱 간 사용자 추적을 사용하지
  않습니다.

자세한 내용은 [개인정보 처리방침](docs/PRIVACY_POLICY.md)과
[개인정보 및 보안 설계](docs/PRIVACY_AND_SECURITY.md)를 확인하세요.

## 동기화 방식

DailyCalendar는 Google Drive AppData에 일정별 파일과 설정 파일을 분리해
저장합니다.

```text
daily-sync-v2-event-{eventId}.json
daily-sync-v2-settings.json
```

- 일정 생성·수정·삭제 시 변경된 일정만 업로드
- 삭제 상태는 tombstone으로 다른 기기에 전파
- 충돌은 일정별 `updatedAt` 또는 `deletedAt` 기준으로 병합
- 종일 일정은 날짜 전용 필드로 보존해 시간대에 따른 날짜 밀림 방지
- 앱 시작, 로그인, 포그라운드 복귀와 수동 요청 시 필요한 동기화 수행

구성 방법과 데이터 형식은
[Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)을 참고하세요.

## 개발 시작

### 요구 사항

- Flutter SDK
- Dart SDK `^3.11.5`
- Apple 빌드: Xcode 및 Apple Developer 서명 환경
- Android 빌드: Android Studio 또는 Android SDK
- Windows 빌드: Visual Studio의 Desktop development with C++ 워크로드

### 설치와 실행

```bash
git clone https://github.com/littlebit0/Daily.git
cd Daily
./tool/flutter.sh pub get
./tool/flutter.sh run -d macos
```

iOS Simulator 실행 예시:

```bash
./tool/flutter.sh devices
./tool/flutter.sh run -d <simulator-device-id>
```

Windows에서는 `tool/flutter.ps1`을 사용합니다.

```powershell
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 run -d windows
```

Google OAuth 및 Apple 서명 값은 저장소에 포함하지 않습니다. 로컬 설정 방법은
[Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)과
[Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)을 확인하세요.

## 품질 확인

```bash
./tool/flutter.sh analyze --no-pub
./tool/flutter.sh test --no-pub
```

3.1.0 기준 검증 결과:

- Flutter 정적 분석 통과
- 전체 자동화 테스트 165개 통과
- iOS App Store IPA 배포 서명 검증
- macOS App Store PKG 앱·설치 프로그램 서명 검증
- iOS/macOS 앱과 위젯 버전 `3.1.0 (3.1.0)` 확인

## 문서

- [3.1.0 릴리스 노트](docs/RELEASE_NOTES_3.1.0.md)
- [기능 로드맵](docs/FEATURE_ROADMAP.md)
- [프로젝트 분석](PROJECT_ANALYSIS.md)
- [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)
- [Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)
- [개인정보 처리방침](docs/PRIVACY_POLICY.md)
- [릴리스 체크리스트](docs/RELEASE_CHECKLIST.md)

## 문의와 이슈

버그 제보와 기능 제안은 [GitHub Issues](https://github.com/littlebit0/Daily/issues)를
이용해 주세요. 개인정보 및 지원 문의는 `kimhee8953@naver.com`으로 받을 수
있습니다.
