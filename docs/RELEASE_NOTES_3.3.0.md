# DailyCalendar 3.3.0 릴리스 노트

## 릴리스 기준

- 앱 표시 버전 및 빌드: `3.3.0 (3.3.0)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준: `3.2.1`

## 주요 변경 사항

- Daily 소개, 익명 사용성 분석 선택, Siri 설정, 알림·알람 권한과 계정 선택을
  하나의 단계형 온보딩 흐름으로 정리했습니다.
  - 익명 분석은 기본 비활성화이며 명시적으로 동의한 경우에만 작동합니다.
  - 분석을 거절해도 앱을 사용할 수 있고 선택 결과를 다시 강요하지 않습니다.
  - Apple 플랫폼에서는 검증된 `시그널` 단축어 추가 화면으로 이동할 수 있습니다.
- 빠른 보기, 설정, 검색·필터, 일정 편집, 캘린더 가져오기와 Siri 기록 화면을
  iOS와 macOS에 어울리는 공통 정보 구조와 라이트·다크 색상 체계로 정리했습니다.
- 온보딩 권한 단계를 마친 뒤 계정 선택 버튼이 비활성화된 채 남던 문제를
  수정했습니다.
- 설정의 Apple·Google 연결, 백업·복원, 로그아웃과 계정 삭제 버튼을 동일한
  상태·아이콘·높이 규칙으로 통일했습니다.
- 사용자용 일정 알림, 아침 브리핑과 D-day 알림은 유지하면서 개발 확인용
  `알림 테스트` 기능만 제거했습니다.
- 같은 반복 일정의 한 발생분을 Todo 완료했을 때 다른 발생분까지 완료되는
  문제를 수정했습니다.
  - 선택한 발생분만 고유 일정으로 안전하게 분리합니다.
  - 반복 원본과 분리 일정의 변경을 함께 원자 저장하고 v2 동기화 큐에 반영합니다.
- 주·월·일 캘린더의 동작과 배치 계산은 유지하면서 상·하단 조작부를 정리했습니다.
  - 연·연월 선택 버튼은 단순한 투명 디자인으로 복원했습니다.
  - 상단 메뉴와 iOS 하단 슬라이드의 불필요한 외곽선을 제거했습니다.
  - 오늘, 이동, 필터, 설정, 빠른 보기, 달력과 AI 아이콘을 더 명확한 형태로
    교체했습니다.
- 신규·변경 화면의 문구를 한국어, 영어, 일본어와 중국어 번체에 반영했습니다.

## 검증

- `git diff --check`
- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 250개
- `python3 -m unittest test/tool/analytics_receiver_test.py` 전체 4개
- macOS Debug 및 iOS Simulator Debug 빌드
- iOS/macOS 앱과 위젯 버전 및 빌드 `3.3.0 (3.3.0)` 확인
- 캘린더 보기 전환, 하단 슬라이드 크기와 무테두리 상태 회귀 테스트

## GitHub 배포 파일

GitHub Actions는 `v3.3.0` 릴리스에서 다음 공개 검증용 파일을 생성합니다.

- `daily-ios-3.3.0-unsigned.ipa`
- `daily-macos-3.3.0-unsigned.dmg`

GitHub의 unsigned IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store
Transporter 제출용 서명 파일은 공개 릴리스에 포함하지 않습니다.

## App Store 제출 파일

Transporter 제출용 서명 파일은 로컬 `dist/transporter-upload/3.3.0`에만
생성하며 Git 저장소와 GitHub Release에는 업로드하지 않습니다.

## 배포 후 확인

- 새 설치와 기존 사용자 업데이트에서 온보딩·분석 동의 분기 확인
- Apple·Google·로컬 계정 진입과 설정의 계정 작업 확인
- 실제 iPhone/iPad와 Mac에서 빠른 보기, 검색·필터, 일정 편집과 캘린더 버튼 확인
- 반복 일정 한 발생분 Todo 완료가 다른 발생분에 영향을 주지 않는지 확인
- App Store Connect에서 iOS와 macOS 빌드가 올바른 플랫폼으로 처리되는지 확인
