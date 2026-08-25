# DailyCalendar 3.2.0 릴리스 노트

## 릴리스 기준

- 앱 표시 버전 및 빌드: `3.2.0 (3.2.0)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준: `3.1.0`

## 주요 변경 사항

- 모든 사용자 일정에 Todo 완료 상태를 추가했습니다. 빠른 보기, 월·주·일
  캘린더, 일정 상세와 Apple 위젯에서 완료 여부를 확인하고 변경할 수 있습니다.
- 기존 사용자 데이터는 원격 복원, 로컬 안전 스냅샷, 검증, 원자적 교체 순서의
  안전 마이그레이션을 거칩니다. 실패 시 원본 데이터를 유지합니다.
- 월간·주간·일간 일정과 macOS 하루 패널에서 길게 눌러 날짜를 이동하거나
  날짜별 수동 순서를 지정할 수 있습니다.
- 분류 순서와 `분류 우선 / 시간 우선` 일정 정렬을 추가하고, 공휴일 분류 색상과
  선택형 날짜 배경을 지원합니다.
- 반복 일정의 종료일 당일이 누락되지 않도록 날짜 포함 규칙을 수정했습니다.
- 주간·일간 스케줄 보기의 주말 색상, 종일 일정 높이, 기간 표기와 macOS 마우스
  이동 동작을 개선했습니다.
- 설정 항목에 의미별 아이콘을 추가하고 일정 제목 정렬, 분석 동의와 데이터
  삭제 등 개인 설정을 보강했습니다.
- 수동 Google Drive 복원은 복원 전에 백업을 실행하지 않으며, 원격 파일을 모두
  검증한 뒤 단일 트랜잭션으로 적용하도록 데이터 안전성을 높였습니다.
- Apple 위젯의 Todo 체크를 실제 일정 데이터와 즉시 동기화하고, 앱의 `자동`,
  `화이트`, `다크` 테마를 모든 위젯이 일관되게 따르도록 수정했습니다.
- macOS 테스트 위젯 확장 중복 등록과 빠른 테마 전환 갱신 경합을 정리해 일부
  위젯만 이전 테마로 남는 문제를 수정했습니다.
- Siri 시그널 단축어 설치 안내와 실행 기록을 개선하고, 앱 아이콘과 시작 화면
  이미지를 최신 DailyCalendar 디자인으로 정리했습니다.
- 익명 사용성 분석은 기본 비활성 상태로 제공하며, 사용자가 명시적으로 허용한
  경우에도 일정 내용, 검색어, 계정 정보와 광고 식별자를 수집하지 않습니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 242개
- `./tool/flutter.sh build macos --debug --no-pub`
- `./tool/flutter.sh build ios --simulator --debug --no-pub`
- macOS에서 오늘 일정·주간 위젯의 화이트·다크·자동 테마 실제 GUI 확인
- iOS/macOS 앱과 위젯 버전 및 빌드 `3.2.0 (3.2.0)` 확인

## GitHub 배포 파일

GitHub Actions는 `v3.2.0` 릴리스에서 다음 공개 검증용 파일을 생성합니다.

- `daily-ios-3.2.0-unsigned.ipa`
- `daily-macos-3.2.0-unsigned.dmg`

GitHub의 unsigned IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store
Transporter 제출용 서명 파일은 공개 릴리스에 포함하지 않습니다.

## 남은 확인

- 실제 iPhone과 Mac에서 신규 설치 및 기존 3.1.0 데이터 마이그레이션 최종 확인
- App Store Connect 제출 전 iOS/macOS Release 아카이브와 서명 검증
- Android 실제 기기와 Windows 실제 OS에서 3.2.0 회귀 검증
