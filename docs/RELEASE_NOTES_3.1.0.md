# Daily 3.1.0 릴리스 노트

## 릴리스 기준

- 앱 표시 버전 및 빌드: `3.1.0 (3.1.0)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준: `3.0.1`

## 주요 변경 사항

- iOS와 macOS에서 Siri 및 App Intents로 일정 조회, 검색, 추가, 수정, 삭제를
  지원합니다.
- Siri가 일정 변경에 필요한 제목, 날짜, 시간, 종일 여부와 분류를 확인하고,
  실제 변경 전 사용자 확인을 받도록 개선했습니다.
- Siri 일정 변경을 앱의 알림, 알람, 위젯과 Google Drive 동기화 흐름에 즉시
  반영하고 실패한 로컬 작업은 재시도하도록 보강했습니다.
- 설정에서 날짜별 Siri 실행 기록과 상세 결과를 확인할 수 있습니다.
- 한국어, 영어, 일본어, 중국어 번체를 지원하며 시스템 언어 자동 적용과 앱 내
  언어 선택을 제공합니다.
- 주간 및 일간 캘린더에 시간대별로 스크롤하는 시간표형 보기와 종일 일정 표시
  제어를 추가했습니다.
- 캘린더 보기 전환, 빠른 보기, 일정 편집, 설정, 가져오기 화면의 다국어 표시와
  반응형 레이아웃을 개선했습니다.
- Google Drive 동기화 후 설정, 알림, 알람과 위젯 상태가 일관되게 갱신되도록
  안정성을 개선했습니다.
- iOS, macOS와 Windows의 앱 아이콘을 새로운 DailyCalendar 디자인으로
  변경했습니다.
- Windows 설치 프로그램과 GitHub 릴리스 기반 자동 업데이트 경로를
  추가했습니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 165개
- iOS App Store IPA 아카이브 및 배포 서명 검증
- macOS App Store PKG 아카이브, 앱 배포 서명 및 설치 프로그램 서명 검증
- iOS/macOS 앱과 위젯 버전 및 빌드 `3.1.0 (3.1.0)` 확인

## GitHub 배포 파일

GitHub Actions는 `v3.1.0` 태그에서 다음 공개 배포 파일을 생성합니다.

- `daily-ios-3.1.0-unsigned.ipa`
- `daily-macos-3.1.0-unsigned.dmg`
- `daily-android-3.1.0.apk`
- `daily-windows-3.1.0.zip`
- `daily-windows-3.1.0-setup.exe`

GitHub의 unsigned IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store
Transporter 제출용 서명 파일은 공개 릴리스에 포함하지 않습니다.

## 남은 확인

- App Store Connect에서 iOS/macOS 3.1.0 빌드 처리 및 심사 제출
- 실제 iPhone과 Mac에서 Siri 문장 인식 및 권한 흐름 최종 확인
- Android 실제 기기와 Windows 실제 OS에서 3.1.0 회귀 검증
