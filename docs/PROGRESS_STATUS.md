# Daily 현재 진행상태

## 요약

Daily는 현재 Flutter 기반 앱 구조와 핵심 기능의 1차 구현이 완료된 상태다. 정적 분석, 단위/위젯 테스트, Android debug APK 빌드, Windows debug 빌드는 통과했다. 실제 동기화와 배포를 위해서는 Firebase 프로젝트 설정, 앱 서명, iOS/macOS 개발 환경 검증이 남아 있다.

## 구현 완료

- Flutter 멀티 플랫폼 프로젝트 구조
- 월간 달력 첫 화면
- 날짜 칸 안 일정 플래그 표시
- 모바일 날짜 상세 하단 시트
- 태블릿/데스크톱 날짜 상세 패널
- 항상 보이는 채팅 입력창
- 규칙 기반 한국어 일정 파서
- Gemini API 선택 연동 구조
- AI 자동 카테고리 분류 구조
- drift + SQLite 로컬 저장소
- 반복 일정 도메인 모델
- 반복 일정 확장 로직
- 로컬 알림 서비스
- 기본 알림 1시간 전
- 오전 8시 아침 브리핑 알림 구조
- Firebase Auth 서비스 구조
- Cloud Firestore 동기화 서비스 구조
- 동기화 대기 이벤트 처리
- 삭제 이벤트 tombstone 처리
- 로컬 SQLite 파일 백업/복원
- 검색 화면
- 설정 화면
- D 드라이브 기반 Flutter 실행 스크립트

## 검증 완료

마지막 확인 명령:

```powershell
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 build apk --debug
.\tool\flutter.ps1 build windows --debug
```

결과:

- 정적 분석 통과
- 테스트 5개 통과
- Android debug APK 빌드 통과
- Windows debug 빌드 통과

## 현재 보류/차단

### Firebase

`lib/firebase_options.dart`는 placeholder 상태다. 실제 동기화를 사용하려면 `flutterfire configure`로 생성된 파일로 교체해야 한다.

필요 작업:

- Firebase 프로젝트 생성
- Firebase Auth 이메일/비밀번호 로그인 활성화
- Firestore Database 생성
- 플랫폼별 Firebase 앱 등록
- `flutterfire configure` 실행

### Android

Android SDK와 JDK 17은 설치했고 debug APK 빌드는 통과했다. `flutter doctor`에는 일부 Android SDK license 경고가 남지만 현재 빌드는 차단하지 않는다.

필요 작업:

- Android release 서명 설정
- release APK 또는 App Bundle 빌드 검증

### Windows

Windows debug 빌드는 통과했다. VS 2026 Build Tools의 ATL/MFC 추가가 Windows 10에서 차단되어, VS 2022 Build Tools의 ATL/MFC 경로를 CMake에서 조건부로 보강했다.

필요 작업:

- release 빌드 검증
- 배포 패키징 방식 결정

### iOS/macOS

Windows 환경에서는 최종 iOS/macOS 빌드를 검증할 수 없다.

필요 작업:

- macOS 개발 환경
- Apple Developer 계정
- Bundle ID 설정
- 실제 기기 알림 검증

## 저장소 상태

- 프로젝트 위치: `D:\Daily`
- Flutter SDK 위치: `D:\flutter-sdk`
- Pub 캐시 위치: `D:\PubCache`
- Gradle 캐시 위치: `D:\GradleCache`
- Android SDK 위치: `D:\AndroidSdk`
- JDK 위치: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Firebase CLI: `15.17.0`
- FlutterFire CLI: `1.3.2`

## 다음 권장 순서

1. Firebase 로그인
2. Firebase 프로젝트 생성
3. `flutterfire configure`
4. Firebase Auth 이메일/비밀번호 로그인 활성화
5. Firestore Database 생성
6. Firestore 보안 규칙 작성
7. Android release 서명 설정
8. Android/Windows release 빌드 검증
9. 실제 기기 알림 검증
