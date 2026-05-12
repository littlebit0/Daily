# Daily 프로젝트 문서

이 문서는 Notion에 그대로 옮기기 위한 통합 문서다.

## 1. 프로젝트 목적

Daily는 개인이 혼자 사용하는 독립 캘린더 앱이다. 기존 캘린더 서비스와 연결하지 않고, 앱 자체 데이터와 동기화 구조로 일정 관리를 제공한다.

가장 중요한 사용 경험은 앱을 열자마자 월간 달력에서 일정을 한눈에 확인하는 것이다.

## 2. 핵심 요구사항

- 첫 화면은 월간 달력
- 날짜 칸 안에 일정 플래그 바 표시
- 날짜 선택 시 세부 일정 표시
- 채팅형 자연어 일정 입력
- 한국어 UI
- 한국 시간 기준
- 기본 알림 1시간 전
- 오전 8시 아침 브리핑
- 반복 일정 지원
- 검색 지원
- 로컬 백업/복원
- Firebase 기반 실시간 동기화

## 3. 주요 결정

### Flutter 채택

iOS, iPadOS, macOS, Android, Windows를 하나의 코드베이스로 관리하기 위해 Flutter를 선택했다.

### Firebase 동기화

초기에는 Apple 생태계 중심 접근도 검토했지만 Android와 Windows까지 지원해야 하므로 CloudKit 대신 Firebase Auth + Cloud Firestore를 사용한다.

### AI 입력 방식

일상적인 일정 입력은 규칙 기반 파서가 우선 처리한다. Gemini API는 복잡하거나 모호한 문장에만 선택적으로 사용한다. API 키는 사용자가 직접 설정한다.

### 데이터 구조

로컬 SQLite를 우선 저장소로 사용한다. 저장은 먼저 로컬에서 완료하고, 백그라운드에서 Firestore에 반영한다.

## 4. UX 방향

- Apple Calendar처럼 깔끔한 방향은 참고하되 점 표시 방식은 사용하지 않는다.
- 월간 달력에서 일정이 직접 보이는 것을 우선한다.
- 모바일은 날짜당 최대 3개 일정 표시 후 `+N` 처리한다.
- 큰 화면에서는 가능한 만큼 일정 표시량을 늘린다.
- 채팅 입력창은 항상 보이게 둔다.

## 5. 현재 구현상태

구현 완료:

- Flutter 앱 구조
- 월간 달력
- 일정 플래그 UI
- 날짜 상세 패널
- 채팅 입력
- 규칙 기반 일정 파서
- Gemini 파서 구조
- drift + SQLite 저장소
- 반복 일정 모델과 확장 로직
- 로컬 알림 서비스
- Firebase Auth/Firestore 서비스 구조
- 백업/복원
- 검색
- 설정

검증 완료:

- `flutter analyze` 통과
- `flutter test` 통과
- Android debug APK 빌드 통과
- Windows debug 빌드 통과

## 6. 남은 작업

- Firebase 실제 설정
- Firestore 보안 규칙 작성
- Firebase CLI 로그인
- `flutterfire configure`
- Android release 서명 준비
- Android release 빌드 검증
- Windows release 빌드 검증
- iOS/macOS 실제 환경 빌드 검증
- 실제 기기 알림 검증

## 7. 보류 항목

- 주간 뷰
- 일간 뷰
- 투두
- 기존 캘린더 연동
- 공유 캘린더
- 단축키
- 앱 잠금

## 8. 참고 문서

- `README.md`
- `DAILY_REQUIREMENTS.md`
- `docs/INITIAL_PLAN.md`
- `docs/PROGRESS_STATUS.md`
