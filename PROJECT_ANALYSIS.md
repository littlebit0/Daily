# Daily Project Analysis

분석 기준일: 2026-05-26

## 1. 한 줄 요약

Daily는 Flutter 기반 개인 캘린더 앱이다. 로컬 저장소는 Drift/SQLite, 상태 관리는 Riverpod, 계정 기반 백업/동기화는 현재 Google Drive AppData JSON 스냅샷 방식이 실제 활성 경로다. Firestore 동기화 코드는 남아 있지만 현재 Provider wiring에서는 사용되지 않는다.

## 2. 현재 메타데이터

- 패키지명: `daily`
- 버전: `1.1.0+1`
- Dart SDK: `^3.11.5`
- 앱 설명: `Personal month-first calendar app with chat-based event entry.`
- Android applicationId: `com.littlebit0.dailycalendar`
- Windows 실행 파일명: `daily`
- 배포 문서 기준 최신 릴리즈: `v1.1.0`

## 3. 의존성 구조

주요 런타임 의존성은 다음 계층으로 나뉜다.

- UI/상태: `flutter`, `flutter_riverpod`
- 로컬 DB: `drift`, `drift_flutter`, `path`, `path_provider`
- 날짜/지역화: `intl`, `timezone`, `klc`
- ID/유틸: `uuid`, `collection`, `crypto`, `http`, `url_launcher`
- AI 파서: `google_generative_ai`
- 알림: `flutter_local_notifications`
- 설정/보안 저장: `shared_preferences`, `flutter_secure_storage`
- Firebase 레거시/설정: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Google 로그인: `google_sign_in`
- Windows 패키징: `msix`

## 4. 실행 흐름

`lib/main.dart`

- Flutter binding 초기화
- 한국어 날짜 포맷 초기화
- `SharedPreferences` 생성
- `SettingsRepository`를 Riverpod ProviderScope에 override
- `DailyApp` 실행

`lib/app/daily_app.dart`

- 설정을 읽어 앱 진입 게이트를 결정한다.
- `onboardingCompleted == false`면 `WelcomePage` 표시
- 앱 잠금이 켜져 있으면 PIN 게이트를 먼저 표시
- Google 계정 세션이 있으면 `MonthCalendarPage` 진입
- Google Drive 인증 헤더가 없으면 onboarding을 다시 false로 돌려 로그인 화면으로 회귀
- 로그인 후 `syncServiceProvider.start()`를 microtask로 시작

`lib/core/di/app_providers.dart`

- 앱 전체 dependency graph의 중심이다.
- 활성 동기화 서비스는 `GoogleDriveSyncService`
- `FirestoreSyncService`는 import/wiring되지 않는다.
- 이벤트 스트림은 로컬 이벤트와 한국 공휴일 시스템 이벤트를 합쳐 반환한다.

## 5. 데이터 모델

`CalendarEvent`

- 필수 필드: id, title, startAt, endAt, allDay, category, colorValue, createdAt, updatedAt
- 선택 필드: memo, location, url, weather, reminder, recurrence
- 동기화 필드: deletedAt, deviceId, syncStatus
- 표시/보안 필드: showDday, sensitive, readOnly, systemEvent, holiday
- `occurrenceId`는 반복 일정이 펼쳐진 개별 occurrence 식별용이다.

`EventDraft`

- 새 일정/수정 결과를 임시로 담는 입력 모델이다.
- `toEvent()`가 UUID, 현재시각, deviceId를 받아 실제 `CalendarEvent`로 변환한다.

`EventCategory`

- 현재 기본 분류는 `basic`, `holiday` 두 개뿐이다.
- 기존 health/work/appointment 등의 alias는 모두 `basic`으로 collapse된다.
- 사용자 분류는 `custom_<hash>` 형태의 id를 만든다.

`RecurrenceRule`

- frequency: none/daily/weekly/monthly/yearly
- interval, until, count, excludedDates 지원
- 특정 occurrence 삭제/수정은 excludedDates로 표현한다.

## 6. 로컬 DB

`lib/features/events/data/app_database.dart`

- Drift 테이블: `event_records`
- schemaVersion: 3
- 주요 컬럼: 제목, 메모, 장소, URL, 날씨, 시작/종료, 종일, 분류, 색상, 알림, 반복, 생성/수정/삭제, 디바이스, syncStatus, D-day, sensitive
- migration v2: `showDday` 추가, holiday 외 분류를 basic으로 마이그레이션
- migration v3: `url`, `weather`, `sensitive`, `recurrenceExcludedDates` 추가

`app_database.g.dart`

- Drift generated code이다. 직접 수정 대상이 아니다.

`DriftEventRepository`

- `watchEventsInRange()`는 삭제되지 않은 모든 row를 가져와 `RecurrenceExpander`로 요청 범위에 맞게 펼친다.
- `search()`는 title/memo/location/url/weather/category를 문자열 contains로 검색한다.
- `delete()`는 hard delete가 아니라 `deletedAt`과 `pending_delete`를 기록한다.
- `hardDelete()`는 실제 DB 삭제다.

## 7. 반복 일정

`RecurrenceExpander`

- 반복이 없으면 단순 overlap만 확인한다.
- 반복이 있으면 startAt부터 rangeEnd 전까지 occurrence를 생성한다.
- monthly/yearly는 말일 clamp를 한다.
- until/count/excludedDates를 반영한다.

편집/삭제 UX

- `EventDetailsPanel`에서 반복 일정 수정/삭제 시 `이 일정만`, `이후 일정`, `전체 반복`을 선택한다.
- 이 일정만: 원본 반복에 excluded date 추가 후 새 단일 일정 생성
- 이후 일정: 원본 반복의 until을 occurrence 전날로 자르고 새 반복 일정 생성
- 전체 반복: 원본 이벤트 자체 수정/삭제

## 8. 주요 화면

`WelcomePage`

- Google 계정 로그인 필수 흐름
- 로그인 성공 후 Google Drive AppData 동기화 수행
- 복원된 설정에 `onboardingCompleted: true`를 저장
- 알림 권한 요청 버튼 제공

`MonthCalendarPage`

- 주간/월간/일간 보기 전환
- 넓은 화면은 달력 + 우측 상세 패널
- 좁은 화면은 날짜 선택 시 하단 시트
- 하단에는 항상 `ChatInputBar`
- 헤더 기능: 이전/다음, 오늘, 빠른 보기, 검색/필터, 전체 검색, 설정
- 현재 보기 필터: 검색어, 표시 밀도, D-day only, 공휴일 표시, 분류 숨김

`CalendarMonthGrid`

- 42일/6주 월간 grid
- 일요일/공휴일 빨강, 토요일 파랑
- 음력 표시 옵션
- 멀티데이 일정은 주 단위로 하나의 spanning flag로 배치
- lane 기반 충돌 회피와 `+N` overflow 표시
- Windows/desktop: 마우스 드래그 범위 선택
- mobile/touch: long press drag 범위 선택

`EventDetailsPanel`

- 특정 날짜의 일정 목록
- 일정 추가/수정/삭제
- 읽기 전용 시스템 공휴일은 편집/삭제 불가
- URL은 `url_launcher`로 외부 브라우저 실행
- D-day, 장소, 날씨를 상세에 표시

`EventEditorDialog`

- 입력 필드: 제목, 시작/종료일, 시작/종료시간, 종일, 분류, 알림, 반복, D-day, 민감 일정, 장소, URL, 날씨, 메모
- 반복 설정: 빈도, 간격, 종료 없음/날짜까지/횟수만큼
- 종일 일정은 endAt을 종료일 다음날 00:00으로 저장한다.

`SearchPage`

- 전체 이벤트 검색
- 결과 탭 시 해당 이벤트의 월/일로 달력 상태 이동
- 반복 occurrence가 아니라 저장된 원본 이벤트 기준 검색 결과를 반환한다.

`SettingsPage`

- 알림: 기본 알림, 종일 알림 시간, 아침 브리핑, D-day offsets
- 달력: 주 시작 요일, 음력 표시, 기본 보기, 월간 밀도
- 개인정보: 민감 일정 숨김, 알림 제목 숨김, 앱 잠금 PIN
- 분류: 사용자 분류 추가/삭제
- AI: UI는 존재하지만 `Opacity + IgnorePointer`로 비활성화
- 백업: SQLite 파일 백업/최신 백업 복원
- 계정: Google Drive 로그인, 즉시 동기화, 로그아웃, 회원탈퇴/데이터 삭제

## 9. 자연어 일정 입력

`ChatInputBar`

- 하단 고정 입력창
- 입력 문장을 `scheduleParserProvider`로 파싱
- 결과는 바로 저장하지 않고 확인 시트에서 사용자가 등록을 확정한다.

`RuleBasedScheduleParser`

- 지원 날짜: 오늘, 내일, 모레, 월/일, 요일, 다음주 요일, 선택된 날짜 fallback
- 지원 기간: A부터 B까지, N일간, N박 M일
- 지원 시간: 오전/오후/아침/점심/저녁/밤, `3시`, `3:30`
- 지원 알림: N시간 전, N분 전
- 지원 반복: 매일/매주/매월/매년
- 제목 정리는 날짜/시간/반복/명령 표현을 제거하는 정규식 기반이다.

`HybridScheduleParser`

- 규칙 기반 결과가 있고 문장이 복잡하지 않거나 AI가 꺼져 있으면 규칙 기반 결과를 사용한다.
- AI가 켜져 있고 민감 키워드 차단에 걸리지 않으면 Gemini 파서로 fallback한다.

`GeminiScheduleParser`

- `flutter_secure_storage`에 저장된 Gemini API key 사용
- 모델: `gemini-2.0-flash`
- JSON 응답을 기대한다.
- 현재 설정 화면에서 AI 입력 UI가 비활성화되어 실사용 경로는 사실상 막혀 있다.

## 10. 알림

`LocalNotificationService`

- 플랫폼 초기화: Android, iOS/macOS Darwin, Windows
- Android 알림 권한 요청
- Asia/Seoul timezone 설정
- 일정 알림: 일정 시작 전 `reminderMinutesBefore`
- 종일 일정: 설정의 종일 알림 시각 기준
- D-day 알림: 설정된 offsets 기준 예약
- 민감 일정 알림 제목 숨김 지원
- 아침 브리핑은 매일 지정 시각 반복 알림으로 예약되지만 본문은 아직 일반 문구다.

## 11. 동기화

실제 활성 경로: `GoogleDriveSyncService`

- 저장 파일: `daily-sync-v1.json`
- 저장 위치: Google Drive `appDataFolder`
- scope: `https://www.googleapis.com/auth/drive.appdata`
- 자동 동기화: 20초 주기
- 로컬 변경 후 지연 동기화: 300ms
- 저장 대상: 이벤트, tombstone, non-secret 설정
- 앱 잠금 PIN은 원격 스냅샷에 포함하지 않는다.
- 원격 설정 채택은 로컬 설정이 거의 기본값일 때만 수행한다.
- 병합은 이벤트 id 기준이며, `syncStatus != synced`인 로컬 변경은 원격보다 우선한다.

`GoogleDriveAuthService`

- Android/iOS/macOS 계열은 `google_sign_in`
- Windows는 loopback redirect + PKCE desktop OAuth 자체 구현
- Windows client id/secret은 dart-define 또는 환경변수에서 읽는다.
- 토큰과 계정 정보는 secure storage에 저장한다.

레거시 경로: `FirestoreSyncService`

- Firebase Auth user uid 아래 `users/{uid}/events`를 사용한다.
- 실시간 snapshots listener와 pending flush가 구현되어 있다.
- 현재 `app_providers.dart`에서 선택되지 않아 앱 기본 동기화에는 사용되지 않는다.

## 12. 백업/복원

`FileBackupService`

- DB 파일 `daily.sqlite`를 앱 문서 폴더의 `Daily Backups` 아래로 복사한다.
- 복원은 가장 최근 `.sqlite` 파일을 현재 DB 파일에 덮어쓴다.
- 복원 전 `daily-before-restore-...sqlite` 안전 백업을 만든다.

## 13. 한국 달력

`KoreanLunarCalendar`

- `klc` 패키지로 양력/음력 변환
- 월간 셀에 `음`, `윤` 표시

`KoreanHolidayService`

- 고정 공휴일, 설날/추석/부처님 오신 날, 대체공휴일 계산
- 2026년 제헌절, 2027년 노동절 조건 포함
- 공휴일은 `readOnly`, `systemEvent`, `holiday` 이벤트로 합성된다.

## 14. 플랫폼별 코드

Android

- `POST_NOTIFICATIONS` 권한 선언
- `DailyMonthWidgetProvider`, `DailyTodayWidgetProvider`, `DailyDdayWidgetProvider`
- 현재 위젯은 실제 일정 데이터가 아니라 앱 진입점/정적 텍스트 중심이다.
- release signing은 `android/key.properties`가 있을 때 적용한다.

iOS

- 기본 Flutter Runner 구조
- GoogleService-Info.plist 포함
- SceneDelegate 사용

macOS

- 마지막 창을 닫아도 앱 종료하지 않음
- reopen 시 숨겨진 창을 다시 앞으로 가져옴
- release entitlement는 sandbox만 있고 network client entitlement는 명시되어 있지 않다.

Windows

- Flutter runner에 트레이 아이콘 직접 구현
- 창 닫기 시 `SW_HIDE`로 숨기고 프로세스 유지
- 트레이 메뉴: Open Daily, Mini Calendar, Exit
- Mini Calendar는 Win32 MessageBox 기반 정적 월 표시이며 앱 일정 데이터와 연결되지는 않는다.

## 15. 테스트 현황

테스트 파일

- `test/widget_test.dart`: 앱 셸, 주간 기본 표시, 월간 PageView swipe
- `test/features/events/recurrence_expander_test.dart`: 주간 반복 occurrence 확장
- `test/features/calendar/calendar_month_grid_test.dart`: 멀티데이 일정 spanning flag
- `test/features/chat/rule_based_schedule_parser_test.dart`: 규칙 기반 파서의 시간/선택 날짜/반복/멀티데이/기간 표현

현재 작업 환경 검증

- 이 macOS 작업 환경에서는 `flutter`, `dart`, `pwsh`가 PATH에 없고 `tool/flutter.ps1`은 Windows용 스크립트라 테스트를 실행하지 못했다.
- README에는 Windows 개발 환경에서 `analyze`, `test`, Android/Windows release build가 통과했다고 기록되어 있다.

## 16. 문서 상태

최신 README/PROGRESS는 Google Drive AppData 동기화 방향을 반영한다.

초기 요구사항/일부 Notion 문서는 Firebase Auth + Firestore 실시간 동기화 중심 설명이 남아 있다. 코드도 Firestore 서비스를 보존하지만 실제 wiring은 Google Drive다. 앞으로 문서를 정리할 때 "초기안"과 "현재 구현"을 분리해 명시하는 것이 좋다.

## 17. 주요 리스크와 갭

1. 현재 환경에서는 Flutter SDK가 없어 테스트/분석/빌드를 직접 실행하지 못했다.
2. `DAILY_REQUIREMENTS.md`는 첫 화면 월간을 요구하지만 현재 기본 설정은 주간 보기다. README는 최신 주간 기본 동작을 설명한다.
3. Firestore 동기화 코드와 문서가 남아 있어 신규 개발 시 실제 동기화 경로를 혼동하기 쉽다.
4. AI 설정 UI는 비활성화되어 있고 API key 저장 버튼도 현재 실사용 경로가 없다.
5. Gemini prompt는 예전 category 이름을 요구하지만 현재 카테고리 모델은 대부분 basic으로 collapse한다.
6. 반복 일정 알림은 현재 원본 event.startAt 기준 예약에 가깝고, 앞으로의 반복 occurrence별 알림 예약은 별도 고도화가 필요하다.
7. 아침 브리핑 알림 본문은 오늘 일정 요약이 아니라 일반 문구다.
8. 앱 시작 시 아침 브리핑을 자동 재예약하는 흐름은 뚜렷하지 않고, 설정 변경 시에 주로 예약된다.
9. SQLite 복원은 실행 중인 Drift connection/state와 충돌 가능성이 있어 복원 후 재시작/DB reopen 전략이 필요하다.
10. Google Drive 스냅샷은 아직 end-to-end encryption이 없다. 개인정보 문서도 공개 전 blocker로 적고 있다.
11. 앱 잠금 PIN은 SHA-256 단순 해시로 저장된다. salt/시도 제한/생체 인증은 없다.
12. Android 위젯과 Windows mini calendar는 실제 일정 데이터를 표시하지 않는 진입점 수준이다.
13. 검색은 반복 occurrence를 별도로 펼쳐 보여주지 않고 원본 이벤트 기준으로 이동한다.
14. 분류 삭제 시 기존 일정의 custom category를 basic으로 마이그레이션하지 않는다.
15. 회원탈퇴 문구는 실제 Google 계정을 삭제하는 것이 아니라 앱의 로컬/Drive 백업 데이터를 삭제하는 흐름이다.
16. `KoreaTime.now()`는 UTC 시각에 9시간을 더한 DateTime을 반환해 DateTime kind/로컬시간 의미가 섞일 여지가 있다.
17. macOS release entitlement에 network client 권한이 명시되어 있지 않아 sandbox 배포 시 Google/HTTP 통신 검증이 필요하다.

## 18. 개발 시 우선순위 제안

1. 현재 동기화 방향 확정: Google Drive만 유지할지 Firestore를 삭제/보류 표시할지 결정
2. Flutter SDK가 있는 환경에서 `flutter analyze`와 `flutter test` 재실행
3. 반복 일정 알림과 아침 브리핑 실제 요약 구현
4. Google Drive 스냅샷 암호화 또는 개인정보 정책상 공개 기준 확정
5. AI 설정 UI를 계속 비활성으로 둘지, 완전히 숨길지, 저장/활성화까지 완성할지 결정
6. Android 위젯/Windows mini calendar를 실제 일정 데이터와 연결할지 범위 결정
7. 문서의 "초기 설계", "현재 구현", "보류/삭제된 방향"을 분리 정리
