# Daily 현재 진행상태

## 요약

Daily는 Flutter 기반 개인 캘린더 앱이며 1.1.0 기준으로 Android/Windows 배포 산출물 생성이 가능한 상태다. 정적 분석, 테스트, Android release APK/App Bundle, Windows release 빌드가 통과했다.

현재 동기화는 자체 서버 없이 Google Drive AppData를 사용한다. iOS/macOS 최종 빌드는 Windows 환경에서는 검증할 수 없어 macOS 개발 환경에서 별도 확인해야 한다.

## 구현 완료

- Flutter 멀티 플랫폼 프로젝트 구조
- 주간/월간/일간 달력 보기
- 기본 주간 보기와 월간 보기 토글
- 날짜 칸 안 일정 플래그 표시
- 월간 달력 표시 밀도 조절
- 모바일 날짜 상세 하단 시트
- 태블릿/데스크톱 날짜 상세 패널
- 항상 보이는 채팅 입력창
- 규칙 기반 한국어 일정 파서
- Gemini API 선택 연동 구조
- AI 자동 카테고리 분류 구조
- drift + SQLite 로컬 저장소
- 반복 일정 도메인 모델
- 반복 일정 확장 로직
- 반복 일정 수정/삭제 범위 선택
- 로컬 알림 서비스
- 기본 알림 1시간 전
- 오전 8시 아침 브리핑 알림 구조
- Google 계정 로그인 필수 흐름
- Google Drive AppData 동기화 서비스
- 자동 동기화 상태 표시
- 삭제 이벤트 tombstone 처리
- 로컬 SQLite 파일 백업/복원
- 검색 화면
- 달력 필터
- 설정 화면
- 일정별 URL, 날씨 메모, 민감 일정
- 앱 잠금 PIN
- Android 위젯 진입점
- Windows 트레이 유지와 미니 캘린더
- macOS 마지막 창 닫기 후 앱 유지
- D 드라이브 기반 Flutter 실행 스크립트
- 배포용 앱 식별자 적용

## Google Drive 동기화 상태

- Google Cloud 프로젝트 번호: `234127810480`
- Android 패키지명: `com.littlebit0.dailycalendar`
- 동기화 파일: `daily-sync-v1.json`
- 저장 위치: Google Drive `appDataFolder`
- OAuth scope: `https://www.googleapis.com/auth/drive.appdata`
- Android Google 로그인 확인 완료
- Windows Desktop OAuth 흐름 구현
- 설정 화면에서 로그인, 즉시 동기화, 로그아웃, 회원탈퇴 제공

## 검증 완료

마지막 확인 명령:

```powershell
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 build apk --release
.\tool\flutter.ps1 build appbundle --release
.\tool\flutter.ps1 build windows --release
```

결과:

- 정적 분석 통과
- 테스트 통과
- Android release APK 빌드 통과
- Android release App Bundle 빌드 통과
- Windows release 빌드 통과
- Android 에뮬레이터 설치 및 로그인 UI 확인
- Windows 릴리즈 실행 확인

배포 산출물:

- Android APK: `build\app\outputs\flutter-apk\app-release.apk`
- Android App Bundle: `build\app\outputs\bundle\release\app-release.aab`
- Windows 실행 파일: `build\windows\x64\runner\Release\daily.exe`

## Android

Android SDK와 JDK 17은 설치 완료했다. release 서명도 로컬 keystore 기반으로 구성했고 App Bundle 빌드가 통과했다.

서명 파일:

- `android\app\upload-keystore.jks`
- `android\key.properties`

두 파일은 `.gitignore`에 포함되어 GitHub에 올라가지 않는다. keystore는 Play Store 업데이트에 필요하므로 별도 백업이 필요하다.

## Windows

Windows release 빌드는 통과했다. 현재 산출물은 실행 파일과 관련 DLL 묶음이며, 일반 배포에는 `build\windows\x64\runner\Release` 전체를 ZIP으로 묶은 파일을 사용한다.

## iOS/macOS

Windows 환경에서는 최종 iOS/macOS 빌드를 검증할 수 없다.

필요 작업:

- macOS 개발 환경
- Apple Developer 계정
- iOS Bundle ID: `com.littlebit0.daily`
- macOS Bundle ID: `com.littlebit0.daily.macos`
- 실제 기기 알림 검증

## 저장소 상태

- 프로젝트 위치: `E:\From_D_Drive\Daily`
- Flutter SDK 위치: `E:\From_D_Drive\flutter-sdk`
- Pub 캐시 위치: `E:\From_D_Drive\PubCache`
- Gradle 캐시 위치: `E:\From_D_Drive\GradleCache`
- Android SDK 위치: `E:\From_D_Drive\AndroidSdk`
- 임시 파일 위치: `E:\From_D_Drive\Temp`
- JDK 위치: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Firebase CLI: `15.17.0`
- FlutterFire CLI: `1.3.2`
- Android 배포용 앱 식별자: `com.littlebit0.dailycalendar`

## 다음 권장 순서

1. 실제 Android 기기에서 Google 로그인과 Drive 동기화 왕복 검증
2. Android Play Console에 1.1.0 AAB 업로드
3. Play App signing SHA-1을 OAuth Android client에 추가
4. 실제 기기 알림 권한과 예약 알림 검증
5. Windows 설치 패키징 방식 고도화
6. macOS 환경에서 iOS/macOS 빌드 검증
