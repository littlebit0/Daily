# Daily 2.7.1 릴리스 노트

## 주요 변경 사항

- 설정의 기본 일정 알림을 복수 선택할 수 있습니다.
  - 시작 시, 10분 전, 30분 전, 1시간 전, 1일 전과 직접 입력값을 조합할 수 있습니다.
  - 달력과 빠른 입력으로 만든 새 일정에 선택한 기본 알림이 모두 적용됩니다.
  - 기존 단일 알림 설정과 Google Drive 백업은 자동으로 호환됩니다.
- Google 계정 연결을 앱 재실행과 업데이트 후에도 안정적으로 복원합니다.
  - 저장된 세션은 대화형 로그인 창 없이 복원합니다.
  - 일시적인 복원 실패는 재시도하며 로컬 캘린더 진입을 막지 않습니다.
- macOS Keychain 서명 구성을 바로잡아 Google 세션과 앱 잠금 정보를 안정적으로 보존합니다.
- macOS 주간·일간 보기의 가로 스크롤과 월간 보기의 트랙패드 이동을 지원합니다.
- 주간·월간·일간 이전/다음 이동 애니메이션을 통일했습니다.
- 모바일 날짜 일정 시트를 위아래로 확장하고, 최대 높이에서 일정 목록을 이어서 스크롤할 수 있습니다.
- 설정의 앱 정보에 버전과 빌드 번호를 함께 표시합니다.

## 동기화 및 호환성

- 복수 기본 알림은 Google Drive AppData의 `daily-sync-v2-settings.json`에 저장됩니다.
- 기존 `defaultReminderMinutes` 단일 값은 복수 목록의 한 항목으로 자동 이전됩니다.
- iOS, macOS, Android, Windows가 동일한 설정 형식과 일정 생성 동작을 사용합니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` (77 tests)
- iPhone 17 시뮬레이터 빌드·설치·실행
- macOS 개발 서명 빌드·설치·실행
- macOS Google 세션 종료 후 자동 복원 확인

## 배포 파일

- `daily-ios-2.7.1-unsigned.ipa`
- `daily-macos-2.7.1-unsigned.dmg`
- `daily-android-2.7.1-debug.apk`
- `daily-windows-2.7.1.zip`

iOS IPA와 macOS DMG는 App Store/공증용 서명 파일이 아닌 GitHub 검증용 산출물입니다.
Android APK는 Play Store 배포용 키로 서명하지 않은 디버그 설치본입니다.
