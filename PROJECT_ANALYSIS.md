# Daily Project Analysis

최종 갱신: 2026-08-03
현재 기준: `3.0.1 (3.0.1)`

## 제품 요약

DailyCalendar는 Flutter 기반 개인 캘린더 앱이다. Drift/SQLite를 로컬 원본
저장소로 사용하며, 사용자가 Google 계정을 연결한 경우 Google Drive AppData의
일정별 v2 파일로 백업과 기기 간 동기화를 수행한다. 자체 동기화 서버는 없다.

## 플랫폼 상태

- iOS/iPadOS: App Store 배포 중, 3.0.1 업데이트 빌드 업로드 완료
- macOS: App Store Connect 3.0.1 빌드 업로드 완료
- Android: 공유 Flutter 기능 포함, 실제 기기 회귀 검증 필요
- Windows: 공유 Flutter 기능 포함, 실제 Windows 회귀 검증 필요

Apple 앱과 위젯은 각각 `com.littlebit0.daily`,
`com.littlebit0.daily.widgets`를 사용한다. Android 패키지명은
`com.littlebit0.dailycalendar`이다.

## 기술 구조

- UI/상태: Flutter, Riverpod
- 로컬 저장소: Drift, SQLite
- 알림: `flutter_local_notifications`와 Apple 네이티브 브리지
- iOS 일정 알람: AlarmKit 지원 OS에서 일정별 시스템 알람
- Apple 위젯: WidgetKit, App Group 공유 스냅샷
- 로그인: Sign in with Apple, Google OAuth
- 동기화: Google Drive AppData v2 JSON
- 외부 캘린더: EventKit 및 Google Calendar API

## 핵심 화면과 기능

- 빠른 보기, 주간, 월간, 일간, 연간 캘린더
- 월간 좌우 페이지 이동 또는 상하 연속 스크롤
- 검색, 필터, 월 경계를 넘는 날짜 범위 선택
- 반복 일정, D-day, 음력, 대한민국 공휴일
- 일정 알림, 아침 브리핑, D-day 알림, 일정별 시스템 알람
- Apple 홈 화면·잠금 화면·macOS 데스크톱 위젯
- 외부 캘린더 가져오기와 분류 이름·색상 보존
- 분류 표시 여부와 사용자 지정 RGB 색상
- PIN 없음 보호, Daily PIN, Apple 시스템 인증 앱 잠금
- 자동·화이트·다크 테마와 3단계 전체 글자 크기
- 일정 장소의 지도 서비스 바로가기

비공개 일정 기능은 3.0.1 이전 개발 과정에서 제거되었다. 현재 모델, DB,
화면, 알림, 위젯과 동기화 payload에 해당 필드가 없다.

## 동기화 규칙

```text
daily-sync-v2-event-{eventId}.json
daily-sync-v2-settings.json
```

- 일정 생성·수정·삭제는 변경된 일정 파일만 백업한다.
- 삭제는 tombstone으로 전파한다.
- 백업은 로컬 데이터를 원격 데이터로 덮어쓰지 않는다.
- 복원만 원격 데이터를 로컬에 병합할 수 있다.
- 수동 동기화는 백업, 3초 대기, 복원 순서다.
- 앱 시작은 다른 기기 변경을 확인·복원한 뒤 로컬 pending 변경을 백업한다.
- 앱 복귀는 pending 변경 백업 후 Drive Changes API로 다른 기기 변경을 확인한다.
- 인증 실패, 취소와 네트워크 오류는 성공으로 표시하지 않는다.
- 실패한 변경은 영속 pending 상태와 제한된 재시도를 사용한다.
- 자동 동기화는 대화형 Google 로그인 창을 열지 않는다.

## 계정 정책

- 로컬 모드는 계정 없이 전체 기본 캘린더 기능을 제공한다.
- Sign in with Apple은 Google 로그인을 요구하지 않는다.
- 유효한 기존 Google 세션만 사용자 개입 없이 복원한다.
- Google 연결이 없어도 Apple/local 모드 진입을 막지 않는다.
- 로그아웃은 pending 백업을 시도한 뒤 기기 로컬 데이터와 인증 세션을 지우고
  Drive AppData는 유지한다.
- 계정 삭제는 로컬 데이터, 연결 정보와 Drive AppData 삭제를 시도한다.
- Apple/Google 신원을 여러 기기에서 하나의 Daily 계정으로 병합하는 백엔드는
  아직 구현하지 않았다. 로컬 표시 상태를 서버 계정처럼 취급하지 않는다.

## 3.0.1 검증 상태

- 정적 분석 통과
- Flutter 전체 테스트 142개 통과
- 핵심 widget 테스트 48개 통과
- iPhone 17 Simulator 빌드 및 업데이트 설치
- macOS debug 빌드 및 테스트 앱 업데이트 설치
- iOS/macOS App Store 앱과 위젯의 버전·빌드·번들·서명 검증
- iOS IPA와 macOS PKG Transporter 업로드 및 Apple 처리 완료

## 남은 위험과 확인 사항

- App Store Connect에서 두 플랫폼의 3.0.1 빌드 선택, 수출 규정 응답과 최종
  심사 제출이 남아 있다.
- AlarmKit 실제 울림과 ProMotion 120Hz는 지원 물리 기기에서 profile/release
  검증이 필요하다.
- Android와 Windows는 3.0.1 공유 설정, DB migration, 동기화와 UI를 실제 OS에서
  회귀 검증해야 한다.
- Apple/Google 계정의 서버 기반 병합은 별도 HTTPS 백엔드 없이는 제공할 수 없다.

## 문서 기준

- 현재 제품 상태: `README.md`, `PROJECT_ANALYSIS.md`, `docs/PROGRESS_STATUS.md`
- 현재 Apple 제출: `docs/STORE_SUBMISSION.md`, `docs/APP_REVIEW_NOTES_3.0.1.md`
- 현재 릴리스: `docs/RELEASE_NOTES_3.0.1.md`
- 과거 `RELEASE_NOTES_*`는 당시 릴리스의 역사 기록이며 현재 동작 설명이 아니다.
