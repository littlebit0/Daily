# Daily

Daily는 로컬 우선으로 바로 사용할 수 있고, Google 계정을 연결하면 Google Drive AppData 백업/동기화를 사용할 수 있는 개인용 캘린더 앱입니다. 앱을 열면 주간 달력이 먼저 보이고, 필요할 때 월간/일간 보기로 전환할 수 있습니다. 날짜 칸 안에는 일정이 색상 플래그 형태로 표시됩니다.

## 현재 버전

- 앱 버전: `1.1.1+2`
- Android 패키지명: `com.littlebit0.dailycalendar`
- 최신 배포: [Daily 1.1.1+2](https://github.com/littlebit0/Daily/releases/tag/v1.1.1%2B2)

## 설치 파일

GitHub Release에서 최신 설치 파일을 받을 수 있습니다.

- iOS unsigned IPA: `daily-ios-1.1.1+2-unsigned.ipa`
- macOS 앱 DMG: `daily-macos-1.1.1+2.dmg`

iOS unsigned IPA는 서명되지 않은 검증용 산출물입니다. 실제 iPhone에 설치하려면 연결된 iPhone을 Xcode에 신뢰/등록해 Development provisioning profile을 만들거나, Apple Developer Program의 TestFlight/App Store/Ad Hoc 배포 서명이 필요합니다.

이전 1.1.0 Android/Windows 산출물:

- Android 직접 설치용 APK: `daily-android-1.1.0.apk`
- Android Play Console 제출용 AAB: `daily-android-1.1.0.aab`
- Windows 배포용 ZIP: `daily-windows-1.1.0.zip`
- Windows 단독 EXE: `daily-windows-1.1.0.exe`

Windows는 `zip` 사용을 권장합니다. Flutter Windows 앱은 실행 파일 외에 `data` 폴더와 DLL 파일이 함께 필요하므로 일반 배포에는 `daily-windows-1.1.0.zip`을 사용해야 합니다.

최신 로컬 산출물 해시:

- APK: `2D613A066840609832836C205645C9D88E6706DC7C31D9EC42AA5488BD9D73E9`
- AAB: `902C05034389A0F8EEA41F00145A9B69FD619371BE5312F7E27335DCBDAE0143`
- macOS DMG: `0effbf8366c7408711336868fb759b18aaaf903ada51eceaadb3a91a03f8fd06`
- iOS unsigned IPA: `071a42ec0c186e3a968d62b0f10a18974695b0ad592a8312c77491eefd5333bf`
- Windows EXE: `47332EA06B42272CDBD3515211B4252F41AA8ADEEE7E2A598D99BA48809352AC`
- Windows ZIP: `247AEC22C6DB458672FC8931626D00EF31AB173261B516B8D896A367B0B2A031`

## 핵심 기능

- 주간/월간/일간 달력 보기 전환
- 기본 주간 보기와 월간 보기 토글
- 날짜별 일정 플래그 표시
- 연속 일정은 여러 날짜를 가로지르는 하나의 긴 플래그로 표시
- 모바일에서는 일정 배너 폭을 최대한 확보해 제목 가독성 우선
- 월간 달력 표시 밀도 조절
- 일정 검색과 달력 필터
- 날짜 드래그 범위 선택 후 일정 추가
  - Windows: 마우스 드래그
  - Android: 길게 누른 뒤 드래그
- 월 달력 스와이프 이동 및 페이지 전환 애니메이션
- 상단 연월 선택으로 빠른 연도/월 이동
- 날짜 상세 패널과 모바일 하단 시트
- 일정 추가/수정/삭제
- 삭제 전 확인 팝업
- 일정별 D-day 표시 옵션
- 반복 일정 모델과 반복 일정 수정/삭제 범위 선택
- 일정별 URL, 날씨 메모, 민감 일정 표시
- 대한민국 공휴일 자동 표시
- 토요일 파란색, 일요일/공휴일 빨간색 표시
- 음력 날짜 표시 옵션
- 주 시작 요일 설정
- 사용자 분류 추가/삭제
- 로컬 알림과 아침 브리핑 알림
- 앱 잠금 PIN과 민감 일정 숨김 옵션
- Android 월간/오늘/D-day 위젯 진입점
- Windows 창 닫기 시 백그라운드/트레이 유지
- Windows 트레이 미니 캘린더
- macOS 마지막 창 닫기 후 앱 유지
- iOS/macOS 공통 빠른 접근 패널
- Google 계정 로그인 선택
- Google Drive AppData 기반 백업/복원/자동 동기화

## 동기화 방식

Daily는 자체 서버를 사용하지 않고 Google Drive `appDataFolder`에 앱 전용 동기화 파일을 저장합니다.

- 저장 파일: `daily-sync-v1.json`
- 저장 위치: 사용자의 Google Drive AppData 영역
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`
- 동기화 대상:
  - 일정
  - 삭제 tombstone
  - 분류
  - 알림 기본값
  - 주 시작 요일
  - 음력 표시 여부
  - D-day 알림 설정
  - 기본 달력 보기
  - 달력 필터 설정
  - 일정 URL, 날씨 메모, 민감 일정 여부
- 로컬 변경 후 짧은 지연 뒤 자동 업로드
- 앱 실행 중 주기적으로 원격 변경 확인
- 설정 화면에서 최근 동기화 상태 확인

Google Drive AppData 방식은 서버 없이 여러 기기 동기화를 구현하기 위한 구조입니다. 완전한 서버 푸시 방식 실시간 동기화는 아니며, 앱 실행 중 짧은 주기의 자동 동기화로 처리합니다.

## Google OAuth 설정

현재 체크인된 Firebase/Google 설정:

- 프로젝트 번호: `424765276744`
- Android 패키지명: `com.littlebit0.dailycalendar`
- Web OAuth client: `424765276744-j32k4bdck7lr4ba0lg5s99u91c4849bp.apps.googleusercontent.com`
- Windows Desktop OAuth client: `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`
- macOS OAuth client: `424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com`

Windows/macOS 브라우저 로그인은 Desktop OAuth client와 PKCE loopback callback을 사용합니다. Desktop OAuth client secret은 Google 토큰 교환에서 선택값이지만, 현재 연결된 Desktop OAuth client는 token exchange에서 secret을 요구하므로 릴리즈 빌드에는 함께 전달합니다. macOS Google 로그인은 기본적으로 Desktop OAuth 경로를 사용하고, iOS Google 로그인은 `com.littlebit0.daily`용 iOS OAuth client ID와 reversed client ID URL scheme이 필요합니다. secret 값은 Git에 커밋하지 않고 빌드 인자로만 전달합니다.

```powershell
.\tool\flutter.ps1 build windows --release `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"
# Optional, only when the Google OAuth client requires it:
# --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

Google Drive API가 활성화되어 있어야 로그인 후 백업/복원이 정상 동작합니다.

자세한 설정은 [Google Drive 동기화 설정 문서](docs/GOOGLE_DRIVE_SYNC_SETUP.md)를 참고합니다.
iOS/macOS 빌드 준비는 [Apple 빌드 설정 문서](docs/APPLE_BUILD_SETUP.md)를 참고합니다.

## AI 기능 상태

Gemini 연동 구조와 규칙 기반 자연어 일정 파서는 코드에 포함되어 있습니다. 다만 사용자용 설정 화면에서는 AI 기능을 개발 중 상태로 반투명 비활성화 처리해 두었습니다.

현재 기본 입력 흐름:

- 단순한 한국어 일정 문장: 규칙 기반 파서 처리
- AI 기능: 추후 활성화 예정
- 로컬 LLM 연동: 예정 항목으로 보류

## 플랫폼 상태

현재 실제 배포 파일이 준비된 플랫폼:

- Android
- Windows
- iOS 시뮬레이터
- macOS debug 앱

iOS/macOS는 현재 로컬 모드로 실행 확인이 완료되었습니다. macOS는 Google 로그인 설정까지 코드와 plist/entitlement가 연결되어 있고, iOS는 Google Cloud에서 iOS OAuth client와 URL scheme을 추가해야 Drive 동기화까지 사용할 수 있습니다. 실제 기기, TestFlight, App Store, Developer ID 배포는 Apple Developer Team과 서명 인증서/프로비저닝 프로파일 설정이 필요합니다.

## 개발 명령

```powershell
cd E:\From_D_Drive\Daily
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 pub run build_runner build
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
```

Android 릴리즈 빌드:

```powershell
.\tool\flutter.ps1 build apk --release
.\tool\flutter.ps1 build appbundle --release
```

Windows 릴리즈 빌드:

```powershell
.\tool\flutter.ps1 build windows --release `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"
# Optional, only when the Google OAuth client requires it:
# --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

`tool/flutter.ps1`은 프로젝트 상위 폴더의 `flutter-sdk`, `PubCache`, `GradleCache`, `AndroidSdk`, `Temp`를 우선 사용합니다. 현재 로컬 환경에서는 `E:\From_D_Drive` 아래 도구 폴더를 사용합니다.

## 검증 상태

최근 확인한 검증:

- `.\tool\flutter.ps1 analyze`: 통과
- `.\tool\flutter.ps1 test`: 통과
- `.\tool\flutter.ps1 build apk --release`: 통과
- `.\tool\flutter.ps1 build appbundle --release`: 통과
- `.\tool\flutter.ps1 build windows --release`: 통과
- Android 에뮬레이터 설치 및 실행 확인
- Windows 릴리즈 실행 확인
- `./tool/flutter.sh test`: 통과
- `./tool/flutter.sh analyze`: 통과
- `./tool/flutter.sh build ios --simulator`: 통과
- `./tool/flutter.sh build macos --debug`: 통과
- iPhone 17 iOS 26.5 시뮬레이터 로컬 모드 실행 확인
- macOS debug 앱 로컬 모드 실행 확인

현재 로컬 개발 환경:

- Android SDK: `E:\From_D_Drive\AndroidSdk`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Firebase CLI: `15.17.0`
- FlutterFire CLI: `1.3.2`
- Visual Studio Build Tools 2022

## 서명 파일

Android release 서명 파일은 로컬에만 보관하고 Git에는 올리지 않습니다.

- Keystore: `android\app\upload-keystore.jks`
- 설정 파일: `android\key.properties`

이 keystore는 향후 Play Store 업데이트에 필요하므로 별도 안전한 위치에 백업해야 합니다.

## 문서

- [초기 기획안](docs/INITIAL_PLAN.md)
- [현재 진행상태](docs/PROGRESS_STATUS.md)
- [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)
- [Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)
- [후속 기능 로드맵](docs/FEATURE_ROADMAP.md)
- [Notion 작성용 통합 문서](docs/NOTION_DAILY_PROJECT.md)
- [상세 요구사항](DAILY_REQUIREMENTS.md)

## 남은 작업

- Play Console 첫 AAB 업로드 후 App signing SHA-1을 OAuth Android client에 추가
- OAuth 동의 화면, 개인정보 처리방침, 지원 이메일 최종 정리
- fresh Google 계정으로 로그인/동기화 재검증
- Android 실제 기기 알림 검증
- Windows 설치 패키징 방식 고도화
- iOS/macOS Google OAuth client와 URL scheme 설정
- Apple Developer 서명 및 배포 설정 검증
