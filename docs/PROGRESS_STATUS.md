# Daily 현재 진행 상태

최종 갱신: 2026-08-03
현재 버전: `3.0.1 (3.0.1)`

## 완료

- 빠른 보기, 주간, 월간, 일간 및 연간 캘린더
- 좌우 월 이동과 상하 연속 월 스크롤
- 일정 생성·수정·삭제, 반복, D-day, 검색과 필터
- 대한민국 공휴일과 음력 표시
- 분류별 표시, 가져온 분류 이름·색상, 사용자 지정 RGB 색상
- iOS Apple Calendar 및 Google Calendar 가져오기
- 일정 알림, 아침 브리핑, D-day 알림
- iOS AlarmKit 일정 알람과 macOS 네이티브 일정 알림
- iOS 홈 화면·잠금 화면 및 macOS 데스크톱·알림 센터 위젯
- Sign in with Apple, Google 로그인, 로컬 모드
- Google Drive AppData 일정별 v2 백업·복원·동기화
- 다른 기기 변경 감지, 충돌 처리와 제한된 실패 재시도
- PIN 없음 보호, Daily PIN, Apple 시스템 인증 앱 잠금
- 자동·화이트·다크 테마와 3단계 글자 크기
- 검색, 상하 스크롤, 연간 보기, 반복 계산과 위젯 갱신 최적화

## Apple 배포

- iOS App Store 공개 기준: `2.7.1`
- 다음 iOS/macOS 제출 버전: `3.0.1 (3.0.1)`
- iOS IPA Transporter 업로드 및 처리 완료
- macOS PKG Transporter 업로드 및 처리 완료
- App Store 설명, 업그레이드 사항과 심사 메모 3.0.1 기준 저장
- 남은 작업: 각 플랫폼 3.0.1 빌드 선택, 수출 규정 확인, 심사 추가 및 제출

## GitHub 릴리스

- `docs/RELEASE_NOTES_3.0.1.md` 준비
- `release-installers.yml`의 릴리스 본문을 3.0.1 노트로 변경
- v3.0.1 태그에서 iOS unsigned IPA, macOS unsigned DMG, Android debug APK,
  Windows release ZIP 생성 예정

## 검증

- `./tool/flutter.sh analyze --no-pub`: 통과
- `./tool/flutter.sh test --no-pub`: 142개 통과
- `./tool/flutter.sh test --no-pub test/widget_test.dart`: 48개 통과
- iPhone 17 Simulator 및 macOS 테스트 앱 업데이트 설치
- Apple 제출 IPA/PKG의 앱·위젯 버전, 빌드, 번들 ID와 서명 확인

## 남은 플랫폼 확인

- Android 실제 기기: DB migration, 캘린더 가져오기, 알림, 동기화와 공유 UI
- Windows 실제 OS: DB migration, Google OAuth, 트레이, 동기화와 공유 UI
- Apple 물리 기기: AlarmKit 실제 울림 및 ProMotion 동적 주사율
- 서버 기반 Apple/Google 계정 병합은 미구현
