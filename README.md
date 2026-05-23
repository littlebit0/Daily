# Daily

Daily는 Google 계정 기반 백업/동기화를 사용하는 개인용 월간 캘린더 앱입니다. 앱을 열면 월간 달력이 먼저 보이고, 날짜 칸 안에 일정이 색상 플래그 형태로 표시됩니다.

## 현재 버전

- 앱 버전: `1.0.0+1`
- Android 패키지명: `com.littlebit0.dailycalendar`
- 최신 배포: [Daily 1.0.0+1](https://github.com/littlebit0/Daily/releases/tag/v1.0.0%2B1)

## 설치 파일

GitHub Release에서 최신 설치 파일을 받을 수 있습니다.

- Android 직접 설치용 APK: `daily-android-1.0.0+1.apk`
- Android Play Console 제출용 AAB: `daily-android-1.0.0+1.aab`
- Windows 배포용 ZIP: `daily-windows-1.0.0+1.zip`
- Windows 단독 EXE: `daily-windows-1.0.0+1.exe`

Windows는 `zip` 사용을 권장합니다. Flutter Windows 앱은 실행 파일 외에 `data` 폴더와 DLL 파일이 함께 필요하므로 일반 배포에는 `daily-windows-1.0.0+1.zip`을 사용해야 합니다.

최신 로컬 산출물 해시:

- APK: `882CE8229A3EACC2461AF0AC1B2C909D1D0040FAB9E32EB6B0E92F297093F91E`
- AAB: `C9920433D7E83892D964997E075C4D539ECF8DDEBF2FEB5422210E02E7B9BFE0`
- Windows EXE: `3FF39D80210014FF7BBD9E06568CA605FB91548A8533FBAC2BB37D4B88CA72F1`
- Windows ZIP: `59E28DD7F83D907E4C30B86365D7746430E4D8709C3903BA7CCC54D774467C72`

## 핵심 기능

- 월간 달력 중심 UI
- 날짜별 일정 플래그 표시
- 연속 일정은 여러 날짜를 가로지르는 하나의 긴 플래그로 표시
- 모바일에서는 일정 배너 폭을 최대한 확보해 제목 가독성 우선
- 날짜 드래그 범위 선택 후 일정 추가
  - Windows: 마우스 드래그
  - Android: 길게 누른 뒤 드래그
- 월 달력 스와이프 이동 및 페이지 전환 애니메이션
- 상단 연월 선택으로 빠른 연도/월 이동
- 날짜 상세 패널과 모바일 하단 시트
- 일정 추가/수정/삭제
- 삭제 전 확인 팝업
- 일정별 D-day 표시 옵션
- 반복 일정 모델과 확장 로직
- 대한민국 공휴일 자동 표시
- 토요일 파란색, 일요일/공휴일 빨간색 표시
- 음력 날짜 표시 옵션
- 주 시작 요일 설정
- 사용자 분류 추가/삭제
- 로컬 알림과 아침 브리핑 알림
- Windows 창 닫기 시 백그라운드/트레이 유지
- Google 계정 로그인 필수
- Google Drive AppData 기반 백업/복원/동기화

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
- 로컬 변경 후 짧은 지연 뒤 자동 업로드
- 앱 실행 중 주기적으로 원격 변경 확인

Google Drive AppData 방식은 서버 없이 여러 기기 동기화를 구현하기 위한 구조입니다. 완전한 서버 푸시 방식 실시간 동기화는 아니며, 앱 실행 중 짧은 주기의 자동 동기화로 처리합니다.

## Google OAuth 설정

현재 사용하는 Google Cloud 프로젝트:

- 프로젝트 번호: `234127810480`
- Android 패키지명: `com.littlebit0.dailycalendar`
- Web OAuth client: `234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com`
- Windows Desktop OAuth client: `234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com`

Windows 릴리즈 빌드는 Desktop OAuth client secret이 필요할 수 있습니다. secret 값은 Git에 커밋하지 않고 빌드 인자로만 전달합니다.

```powershell
.\tool\flutter.ps1 build windows --release `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" `
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

Google Drive API가 활성화되어 있어야 로그인 후 백업/복원이 정상 동작합니다.

자세한 설정은 [Google Drive 동기화 설정 문서](docs/GOOGLE_DRIVE_SYNC_SETUP.md)를 참고합니다.

## AI 기능 상태

Gemini 연동 구조와 규칙 기반 자연어 일정 파서는 코드에 포함되어 있습니다. 다만 사용자용 설정 화면에서는 AI 기능을 개발 중 상태로 비활성화해 두었습니다.

현재 기본 입력 흐름:

- 단순한 한국어 일정 문장: 규칙 기반 파서 처리
- AI 기능: 추후 활성화 예정
- 로컬 LLM 연동: 예정 항목으로 보류

## 플랫폼 상태

현재 실제 배포 파일이 준비된 플랫폼:

- Android
- Windows

프로젝트 구조는 iOS, iPadOS, macOS 타깃을 포함하지만, 현재 Windows 개발 환경에서는 Apple 플랫폼 설치 파일을 만들 수 없습니다. iOS/macOS 배포는 macOS, Xcode, Apple Developer 설정이 필요합니다.

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
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" `
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
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
- [Notion 작성용 통합 문서](docs/NOTION_DAILY_PROJECT.md)
- [상세 요구사항](DAILY_REQUIREMENTS.md)

## 남은 작업

- Play Console 첫 AAB 업로드 후 App signing SHA-1을 OAuth Android client에 추가
- OAuth 동의 화면, 개인정보 처리방침, 지원 이메일 최종 정리
- fresh Google 계정으로 로그인/동기화 재검증
- Android 실제 기기 알림 검증
- Windows 설치 패키징 방식 고도화
- macOS 환경에서 iOS/macOS 빌드와 Apple Developer 설정 검증
