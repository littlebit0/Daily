# Daily 현재 진행상태

## 요약

Daily는 Flutter 기반 앱 구조와 핵심 기능의 1차 구현이 완료된 상태다. 정적 분석, 테스트, Android debug APK, Windows debug 빌드, Android release App Bundle, Windows release 빌드가 통과했다.

Firebase 프로젝트와 Firestore 설정은 완료됐고, 이메일/비밀번호 로그인 제공자만 Firebase Console에서 수동 활성화가 필요하다. iOS/macOS 최종 빌드는 Windows 환경에서는 검증할 수 없어 macOS 개발 환경에서 별도 확인해야 한다.

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
- 배포용 앱 식별자 적용

## Firebase 상태

- Firebase 프로젝트: `daily-littlebit0`
- Firestore Database: `(default)`
- Firestore 위치: `asia-northeast3`
- Firestore 보안 규칙: 배포 완료
- Android Firebase 앱: 등록 완료
- iOS Firebase 앱: 등록 완료
- macOS Firebase 앱: 등록 완료
- Windows Firebase 웹 앱: 등록 완료
- Android 설정 파일: `android/app/google-services.json`
- iOS 설정 파일: `ios/Runner/GoogleService-Info.plist`
- macOS 설정 파일: `macos/Runner/GoogleService-Info.plist`
- Flutter Firebase options: `lib/firebase_options.dart`

보류 항목:

- Firebase Console에서 Authentication 이메일/비밀번호 제공자 활성화

## 검증 완료

마지막 확인 명령:

```powershell
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 build apk --debug
.\tool\flutter.ps1 build windows --debug
.\tool\flutter.ps1 build appbundle --release
.\tool\flutter.ps1 build windows --release
```

결과:

- 정적 분석 통과
- 테스트 통과
- Android debug APK 빌드 통과
- Windows debug 빌드 통과
- Android release App Bundle 빌드 통과
- Windows release 빌드 통과

배포 산출물:

- Android App Bundle: `D:\Daily\build\app\outputs\bundle\release\app-release.aab`
- Windows 실행 파일: `D:\Daily\build\windows\x64\runner\Release\daily.exe`

## Android

Android SDK와 JDK 17은 설치 완료했다. release 서명도 로컬 keystore 기반으로 구성했고 App Bundle 빌드가 통과했다.

서명 파일:

- `D:\Daily\android\app\upload-keystore.jks`
- `D:\Daily\android\key.properties`

두 파일은 `.gitignore`에 포함되어 GitHub에 올라가지 않는다. keystore는 Play Store 업데이트에 필요하므로 별도 백업이 필요하다.

## Windows

Windows release 빌드는 통과했다. 현재 산출물은 실행 파일과 관련 DLL 묶음이며, 사용자 배포용으로는 MSIX, Inno Setup, ZIP 배포 중 하나를 선택해야 한다.

## iOS/macOS

Windows 환경에서는 최종 iOS/macOS 빌드를 검증할 수 없다.

필요 작업:

- macOS 개발 환경
- Apple Developer 계정
- iOS Bundle ID: `com.littlebit0.daily`
- macOS Bundle ID: `com.littlebit0.daily.macos`
- 실제 기기 알림 검증

## 저장소 상태

- 프로젝트 위치: `D:\Daily`
- Flutter SDK 위치: `D:\flutter-sdk`
- Pub 캐시 위치: `D:\PubCache`
- Gradle 캐시 위치: `D:\GradleCache`
- Android SDK 위치: `D:\AndroidSdk`
- 임시 파일 위치: `D:\Temp`
- JDK 위치: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Firebase CLI: `15.17.0`
- FlutterFire CLI: `1.3.2`
- 배포용 앱 식별자: `com.littlebit0.daily`

## 다음 권장 순서

1. Firebase Console에서 이메일/비밀번호 로그인 제공자 활성화
2. 실제 기기에서 회원가입/로그인 검증
3. Firestore 동기화 왕복 검증
4. 실제 기기 알림 권한과 예약 알림 검증
5. Android Play Console에 AAB 업로드
6. Windows 배포 패키징 방식 결정
7. macOS 환경에서 iOS/macOS 빌드 검증
