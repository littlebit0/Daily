# Daily 3.0.1 릴리스 노트

## 릴리스 기준

- 앱 표시 버전 및 빌드: `3.0.1 (3.0.1)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- App Store Connect: iOS/macOS 3.0.1 빌드 업로드 및 처리 완료
- 비교 기준: App Store 공개 버전 `2.7.1`

## 주요 변경 사항

- 좌우 월 이동과 상하 연속 월 스크롤, 12개월 연간 보기를 추가했습니다.
- iOS 홈 화면·잠금 화면 및 macOS 데스크톱·알림 센터 위젯을 추가했습니다.
- iOS AlarmKit 일정 알람과 macOS 네이티브 일정 알림을 추가했습니다.
- iOS Apple Calendar 및 Google Calendar 가져오기를 추가했습니다.
- 가져온 캘린더의 분류 이름과 색상, 반복, 알림 정보를 보존하고 중복 가져오기를 방지합니다.
- 분류별 표시 여부와 드래그 및 RGB 입력을 지원하는 사용자 지정 색상을 추가했습니다.
- 앱 잠금을 PIN 없음, Daily PIN, Apple 시스템 인증의 세 방식으로 정리했습니다.
- 자동·화이트·다크 테마와 기본·크게·더 크게 글자 크기 설정을 추가했습니다.
- Google Drive 백업과 복원을 분리하고 다른 기기의 변경 감지, 충돌 처리,
  제한된 재시도와 분류 색상 동기화 일관성을 개선했습니다.
- Apple 로그인 뒤 Google 로그인을 강제하지 않으며, 기존 Google 세션을 조용히
  복원할 수 없는 경우에도 Apple 또는 로컬 모드 사용을 막지 않습니다.
- 제거하기로 결정한 비공개 일정 기능과 데이터 필드를 앱 및 동기화 스키마에서 정리했습니다.
- 검색 전환, 상하 월 스크롤, 연간 보기 크기 변경, 반복 일정 계산과 위젯 갱신 성능을 개선했습니다.
- 월 경계를 넘는 날짜 범위 선택, 빈 날짜 선택, 연간 보기 이동, 잠금 반복 인증,
  Google 세션 복원과 여러 화면 표시 오류를 수정했습니다.
- 지원하는 iPhone 및 Mac 디스플레이에서는 시스템의 동적 고주사율을 사용합니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 142개
- `./tool/flutter.sh test --no-pub test/widget_test.dart` 48개
- iPhone 17 Simulator debug 빌드 및 업데이트 설치
- macOS debug 빌드 및 테스트 앱 업데이트 설치
- iOS App Store IPA 앱/위젯 버전 및 빌드 `3.0.1`
- macOS App Store PKG 앱/위젯 버전 및 빌드 `3.0.1`
- iOS/macOS App Store 배포 서명과 번들 ID 검증

## GitHub 배포 파일

- `daily-ios-3.0.1-unsigned.ipa`
- `daily-macos-3.0.1-unsigned.dmg`
- `daily-android-3.0.1-debug.apk`
- `daily-windows-3.0.1.zip`

GitHub IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store 제출용 서명 파일은
로컬 `dist/transporter-ios-3.0.1` 및 `dist/transporter-macos-3.0.1`에 별도로
보관합니다.

## 남은 확인

- App Store Connect에서 iOS/macOS 3.0.1 빌드 선택 및 수출 규정 응답
- 두 플랫폼을 심사에 추가한 뒤 최종 제출
- Android 실제 기기 및 Windows 실제 OS에서 공유 설정·동기화 변경 회귀 검증
