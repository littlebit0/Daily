# Daily

Daily는 개인용 독립 캘린더 앱입니다. 앱을 열면 바로 월간 달력이 표시되고, 각 날짜 칸 안에 일정이 플래그 바 형태로 보입니다.

## 핵심 방향

- 월간 달력을 첫 화면으로 사용한다.
- 일정이 있는 날을 점으로만 표시하지 않고, 날짜 칸 안에 짧은 플래그 바를 표시한다.
- 채팅 입력창은 항상 보이게 두고 자연어로 일정을 추가한다.
- 단순 문장은 규칙 기반 파서로 처리하고, 복잡한 문장만 Gemini API를 선택적으로 사용한다.
- 로컬 SQLite를 우선 저장소로 사용하고 Firebase Auth + Cloud Firestore로 여러 기기 실시간 동기화를 붙인다.
- 기본 알림은 일정 시작 1시간 전, 아침 브리핑은 오전 8시다.

## 현재 구현 범위

- iOS, iPadOS, macOS, Android, Windows Flutter 프로젝트 구조
- 월간 캘린더 첫 화면
- 날짜별 일정 플래그 표시
- 날짜 상세 패널과 모바일 하단 시트
- 항상 보이는 채팅형 자연어 일정 입력
- 규칙 기반 한국어 일정 파서
- Gemini API 선택 연동 구조
- AI 자동 카테고리 분류 구조
- drift + SQLite 로컬 저장소
- 반복 일정 데이터 모델과 확장 로직
- 로컬 알림 서비스
- Firebase Auth 로그인 구조
- Cloud Firestore 실시간 동기화 구조
- 로컬 SQLite 파일 백업/복원
- 검색 화면
- 설정 화면

## 문서

- [초기 기획안](docs/INITIAL_PLAN.md)
- [현재 진행상태](docs/PROGRESS_STATUS.md)
- [Notion 작성용 통합 문서](docs/NOTION_DAILY_PROJECT.md)
- [상세 요구사항](DAILY_REQUIREMENTS.md)

## 개발 명령

```powershell
cd D:\Daily
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 pub run build_runner build
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
```

`tool/flutter.ps1`은 기본 Flutter SDK로 `D:\flutter-sdk`를 사용하고, `PUB_CACHE=D:\PubCache`, `GRADLE_USER_HOME=D:\GradleCache`를 자동으로 설정한다. C 드라이브 용량 문제와 깨진 Pub 캐시를 피하기 위해 이 스크립트를 기본으로 사용한다.

Firebase 설정이 완료되기 전에는 앱이 로컬 SQLite 기반으로 동작하며, 동기화 로그인은 비활성 상태로 남는다.

## 검증 상태

- `.\tool\flutter.ps1 analyze`: 통과
- `.\tool\flutter.ps1 test`: 통과
- Windows 빌드: Visual Studio Build Tools의 ATL/MFC 구성요소가 없어 로컬 환경에서 보류
- Android 빌드: Android SDK가 없어 현재 PC에서 보류

## 남은 작업

- Firebase 프로젝트 생성
- `flutterfire configure` 실행 및 `lib/firebase_options.dart` 교체
- Firebase Auth 이메일/비밀번호 로그인 활성화
- Firestore Database 생성과 보안 규칙 작성
- Android SDK 설치와 앱 서명 준비
- Apple Developer 계정과 iOS/macOS 설정 파일 준비
- Windows ATL/MFC 구성요소 설치 후 Windows 빌드 재검증
- 실제 기기 알림 권한과 예약 알림 동작 검증
