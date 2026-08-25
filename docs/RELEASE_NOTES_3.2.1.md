# DailyCalendar 3.2.1 릴리스 노트

## 릴리스 기준

- 앱 표시 버전 및 빌드: `3.2.1 (3.2.1)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준: `3.2.0`

## 주요 변경 사항

- Google 로그인 사용자가 앱 설정에서 버그 내용을 직접 확인한 뒤
  DailyCalendar GitHub 이슈를 등록할 수 있도록 개선했습니다.
  - Google 인증 상태와 이메일 인증 여부를 서버에서 확인합니다.
  - 제보 내용과 앱 환경만 공개 이슈에 등록하고 Google 이메일은 공개하지
    않습니다.
  - 연락용 이메일은 접근이 제한된 지원 서버에만 보관합니다.
- iPhone과 iPad 설정 화면의 긴 설명을 기기 폭과 글자 크기에 맞춰 단어
  경계에서 줄바꿈하도록 개선했습니다.
- macOS 월간 좌우 보기와 주간·일간 목록/스케줄 보기에서 트랙패드 좌우
  이동이 멈춘 회귀를 수정했습니다.
  - 네이티브 트랙패드 `PointerPanZoom` 페이지 이동을 복원했습니다.
  - 마우스 휠의 한 단계 페이지 이동과 스케줄의 세로 시간 이동은 유지합니다.
- 일정 상세와 macOS 우측 하루 보기의 날짜 헤더에서 공휴일 배경 강조를
  제거해 일반 날짜와 동일한 헤더로 표시합니다.
- 익명 사용성 분석과 인증형 버그 제보의 수집 범위, 보관 위치, 공개/비공개
  경계를 개인정보 및 서버 운영 문서에 명확히 기록했습니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 243개
- `python3 -m unittest test/tool/analytics_receiver_test.py` 전체 4개
- macOS 월간·주간·일간 트랙패드 `PointerPanZoom` 회귀 테스트
- macOS Debug 빌드 및 테스트 앱 코드 서명 검증
- iOS/macOS 앱과 위젯 버전 및 빌드 `3.2.1 (3.2.1)` 확인

## GitHub 배포 파일

GitHub Actions는 `v3.2.1` 릴리스에서 다음 공개 검증용 파일을 생성합니다.

- `daily-ios-3.2.1-unsigned.ipa`
- `daily-macos-3.2.1-unsigned.dmg`

GitHub의 unsigned IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store
Transporter 제출용 서명 파일은 공개 릴리스에 포함하지 않습니다.

## App Store 제출 파일

Transporter 제출용 서명 파일은 로컬 `dist/transporter-upload/3.2.1`에만
생성하며 Git 저장소와 GitHub Release에는 업로드하지 않습니다.

## 배포 후 확인

- App Store Connect에서 iOS와 macOS 빌드가 서로 올바른 플랫폼으로 처리되는지
  확인
- 실제 Mac에서 월간 좌우 보기와 주간·일간 목록/스케줄의 트랙패드 이동 확인
- Google 로그인 상태에서 버그 제보의 동의, 제출, 공개 이슈와 비공개 연락처
  분리 확인
- App Store Connect 개인정보 응답에 이메일 및 고객 지원용 사용자 콘텐츠
  수집 사실 반영
