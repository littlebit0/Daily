# Daily 2.6.0 릴리스 노트

## 적용 범위

이번 릴리스는 iOS App Review 재제출 대응과 macOS Google Drive 연결 안정화를
포함합니다. GitHub Release에는 iOS IPA와 macOS DMG를 함께 업로드합니다.

## 변경 사항

- Apple 로그인 후 Google 로그인 화면이 자동으로 열리던 동작을 제거했습니다.
  - Apple 로그인은 Google Drive 연결 없이도 로컬 캘린더로 바로 진입합니다.
  - 기존 Google Drive 세션이 기기에 남아 있는 경우에만 조용히 복원합니다.
  - 세션 복원에 실패해도 Apple 로그인 완료를 막지 않습니다.
- Apple 계정에 연결된 Google 계정 이메일/표시명을 로컬 설정에 보존합니다.
  - 명시적으로 Google Drive를 연결하면 Apple 계정과의 연결 관계가 저장됩니다.
  - 계정 삭제/전체 초기화 시에는 연결 정보도 함께 삭제됩니다.
- 설정의 파괴적 계정 제거 경로를 `계정 삭제`로 명확히 표시합니다.
  - Apple만 로그인한 상태에서도 `계정 삭제` 버튼이 표시됩니다.
  - 삭제 확인 후 Daily 계정 연결, 로컬 일정/설정, Google Drive AppData 백업,
    Apple/Google 로그인 정보가 삭제됩니다.
- 일정 장소가 입력된 경우 `지도 바로가기` 버튼을 제공합니다.
  - 하나의 버튼에서 카카오맵, 네이버지도, Apple 지도 중 선택할 수 있습니다.
  - 지도 앱이 없는 경우 가능한 웹/Apple Maps URL로 fallback합니다.
- GitHub 이슈 #16 후속 보강:
  - 분류 추가/수정/삭제 후 Google Drive 설정 백업을 한 번 더 확정해 다른 기기
    설정 화면의 분류 색상이 늦게 반영되는 문제를 줄였습니다.
- macOS/Windows 데스크톱 Google Drive 연결 안정화:
  - 브라우저 전환을 OAuth 취소로 오인하던 자동 취소 로직을 제거했습니다.
  - 인증은 사용자가 완료하거나 명시적으로 `연결 취소`를 누를 때만 종료됩니다.
- Android/Windows 계정 흐름을 iOS/macOS 정책에 맞게 정리했습니다.
  - Android는 모바일 인증 중 `Google 연결 중` 상태를 사용합니다.
  - Windows는 macOS와 동일하게 시스템 브라우저 OAuth와 명시적 취소를 사용합니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- `./tool/flutter.sh build ipa --release --no-pub`
- iOS archive validation:
  - Version Number: `2.6.0`
  - Build Number: `2.6.0`
  - Bundle Identifier: `com.littlebit0.daily`

## 배포 파일

- GitHub Release IPA:
  - `daily-ios-2.6.0-unsigned.ipa`
- GitHub Release macOS DMG:
  - `daily-macos-2.6.0-unsigned.dmg`
- 로컬 GitHub 업로드용 IPA:
  - `dist/release-2.6.0/daily-ios-2.6.0.ipa`
- 로컬 GitHub 업로드용 macOS DMG:
  - `dist/release-2.6.0/daily-macos-2.6.0.dmg`
- App Store Connect Transporter 업로드용 IPA:
  - `dist/transporter-upload/Daily-iOS-Transporter-2.6.0.ipa`
- 실사용 iPhone 설치 확인용 IPA:
  - `dist/device-install/Daily-iOS-Device-2.6.0.ipa`

SHA-256:

- `daily-ios-2.6.0.ipa`:
  `a748b495d37ff918f5bcd71bcc334a6d4ff12b75b88d139e65645db4a485427c`
- `daily-macos-2.6.0.dmg`:
  `59da7dd629f40b9023cda8b337223e4b394e3b8de36850ef97717d1a2e8346f7`

## App Review 확인 포인트

- 신규 설치 후 `Apple로 계속`을 선택해도 Google 로그인 화면이 자동으로 열리지
  않아야 합니다.
- Google Drive는 사용자가 `Google로 계속` 또는 설정의 Google Drive 연결 버튼을
  직접 선택한 경우에만 대화형 로그인을 엽니다.
- Apple 로그인은 Google Drive 없이도 앱의 캘린더 기능을 사용할 수 있습니다.
