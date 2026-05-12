# Daily 현재 진행상태

## 요약

Daily는 현재 Flutter 기반 앱 구조와 핵심 기능의 1차 구현이 완료된 상태다. 로컬 실행, 정적 분석, 단위/위젯 테스트는 통과했다. 실제 배포를 위해서는 Firebase 설정 파일과 플랫폼별 개발 환경 구성이 남아 있다.

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
```

결과:

- 정적 분석 통과
- 테스트 5개 통과

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

현재 PC에 Android SDK가 없어 Android 빌드를 검증하지 못했다.

필요 작업:

- Android Studio 또는 Android SDK 설치
- `flutter doctor`에서 Android toolchain 통과 확인
- debug/release APK 또는 App Bundle 빌드 검증

### Windows

Windows 빌드 도중 Visual Studio Build Tools의 ATL/MFC 헤더가 없어 실패했다.

필요 구성요소:

- `Microsoft.VisualStudio.Component.VC.14.50.18.0.ATL`
- `Microsoft.VisualStudio.Component.VC.14.50.18.0.MFC`

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

## 다음 권장 순서

1. GitHub 저장소 생성 및 push
2. Firebase 프로젝트 생성
3. `flutterfire configure`
4. Android SDK 설치
5. Windows ATL/MFC 구성요소 설치
6. Android/Windows 빌드 재검증
7. 실제 기기 알림 검증
8. Firestore 보안 규칙 작성
