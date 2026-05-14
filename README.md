# Daily

Daily는 개인용 독립 캘린더 앱입니다. 앱을 열면 바로 월간 달력이 표시되고, 각 날짜 칸 안에 일정이 플래그 바 형태로 보입니다.

## 핵심 방향

- 월간 달력을 첫 화면으로 사용한다.
- 일정이 있는 날을 점으로만 표시하지 않고, 날짜 칸 안에 짧은 플래그 바를 표시한다.
- 채팅 입력창은 항상 보이게 두고 자연어로 일정을 추가한다.
- 단순 문장은 규칙 기반 파서로 처리하고, 복잡한 문장만 Gemini API를 선택적으로 사용한다.
- 로컬 SQLite를 우선 저장소로 사용하고 Firebase Auth + Cloud Firestore로 여러 기기 실시간 동기화를 붙인다.
- 기본 알림은 일정 시작 1시간 전, 아침 브리핑은 오전 8시다.
- 배포용 앱 식별자는 `com.littlebit0.daily`를 사용한다.

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

## Firebase 상태

- Firebase 프로젝트: `daily-littlebit0`
- Firestore Database: `(default)`, `asia-northeast3`
- Firestore 보안 규칙: 배포 완료
- Android/iOS/macOS/Windows Firebase 앱 등록 완료
- 플랫폼 설정 파일 반영 완료

Firebase Authentication의 이메일/비밀번호 로그인 제공자는 Firebase Console에서 수동 활성화가 필요하다.

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

`tool/flutter.ps1`은 기본 Flutter SDK로 `D:\flutter-sdk`를 사용하고, `PUB_CACHE=D:\PubCache`, `GRADLE_USER_HOME=D:\GradleCache`, `TEMP=D:\Temp`, `TMP=D:\Temp`, Java 임시 경로를 자동으로 설정한다. C 드라이브 용량 문제와 깨진 Pub 캐시를 피하기 위해 이 스크립트를 기본으로 사용한다.

## 검증 상태

- `.\tool\flutter.ps1 analyze`: 통과
- `.\tool\flutter.ps1 test`: 통과
- `.\tool\flutter.ps1 build apk --debug`: 통과
- `.\tool\flutter.ps1 build windows --debug`: 통과
- `.\tool\flutter.ps1 build appbundle --release`: 통과
- `.\tool\flutter.ps1 build windows --release`: 통과

배포 산출물:

- Android App Bundle: `D:\Daily\build\app\outputs\bundle\release\app-release.aab`
- Windows 실행 파일: `D:\Daily\build\windows\x64\runner\Release\daily.exe`

현재 로컬 개발 환경에는 다음 도구가 구성되어 있다.

- Android SDK: `D:\AndroidSdk`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Firebase CLI: `15.17.0`
- FlutterFire CLI: `1.3.2`
- Visual Studio Build Tools 2022: Windows ATL/MFC 빌드 보강용

## 서명 파일

Android release 서명 파일은 로컬에만 보관하고 Git에는 올리지 않는다.

- Keystore: `D:\Daily\android\app\upload-keystore.jks`
- 설정 파일: `D:\Daily\android\key.properties`

이 keystore는 향후 Play Store 업데이트에 필요하므로 별도 안전한 위치에 백업해야 한다.

## 남은 작업

- Firebase Console에서 이메일/비밀번호 로그인 제공자 활성화
- 실제 기기에서 로그인, 동기화, 알림 동작 검증
- Android Play Console에 AAB 업로드
- Windows 배포 패키징 방식 결정
- macOS 환경에서 iOS/macOS 빌드와 Apple Developer 설정 검증
