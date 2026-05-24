# Daily 1.1.0 릴리즈 노트

## 핵심 변경

- 주간/월간/일간 달력 보기 전환을 추가했고 기본 시작 보기를 주간 중심으로 개선했다.
- 월간 달력의 일정 표시 밀도와 제목 가독성을 개선했다.
- 달력 검색/필터, 공휴일 표시 필터, D-day 전용 보기 옵션을 추가했다.
- 날짜 범위 선택, 일정 상세, 일정 편집 흐름을 확장했다.
- 반복 일정 수정/삭제 시 이 일정만, 이후 일정, 전체 반복 일정 범위를 선택할 수 있게 했다.
- 일정별 URL, 날씨 메모, 민감 일정 표시를 추가했다.
- 앱 잠금 PIN, 민감 일정 숨김, 민감 일정 알림 숨김 설정을 추가했다.
- Google Drive AppData 자동 동기화 상태 표시와 즉시 동기화 흐름을 개선했다.
- Android 월간/오늘/D-day 위젯 진입점을 추가했다.
- Windows 트레이 유지와 미니 캘린더를 추가했다.
- macOS는 마지막 창을 닫아도 앱이 유지되도록 맞췄다.
- Android Google 로그인 취소/지연 상황에서 원시 예외 대신 한국어 안내가 표시되도록 정리했다.

## 배포 파일

- `daily-android-1.1.0.apk`: Android 직접 설치용 APK
- `daily-android-1.1.0.aab`: Google Play Console 제출용 App Bundle
- `daily-windows-1.1.0.zip`: Windows 권장 배포 패키지
- `daily-windows-1.1.0.exe`: Windows 단독 실행 파일

Windows에서는 `daily-windows-1.1.0.zip` 사용을 권장한다. Flutter Windows 앱은 실행 파일 외에 `data` 폴더와 DLL 파일이 함께 필요하다.

## SHA-256

- APK: `2D613A066840609832836C205645C9D88E6706DC7C31D9EC42AA5488BD9D73E9`
- AAB: `902C05034389A0F8EEA41F00145A9B69FD619371BE5312F7E27335DCBDAE0143`
- Windows EXE: `47332EA06B42272CDBD3515211B4252F41AA8ADEEE7E2A598D99BA48809352AC`
- Windows ZIP: `247AEC22C6DB458672FC8931626D00EF31AB173261B516B8D896A367B0B2A031`

## 검증

- `.\tool\flutter.ps1 analyze`
- `.\tool\flutter.ps1 test`
- `.\tool\flutter.ps1 build apk --release`
- `.\tool\flutter.ps1 build appbundle --release`
- `.\tool\flutter.ps1 build windows --release`
- Android 에뮬레이터 설치 및 로그인 UI 확인
- Windows 릴리즈 실행 확인

## 알려진 제한

- iOS/macOS 설치 파일은 Windows 개발 환경에서 생성할 수 없다. Apple 플랫폼 배포는 macOS, Xcode, Apple Developer 설정이 필요하다.
- Android 위젯은 현재 앱 진입점 중심이다. 실제 일정 데이터 표시 위젯은 후속 고도화 항목이다.
- Google Drive 동기화 스냅샷은 아직 종단 간 암호화되지 않는다. 앱 잠금 PIN은 로컬 보안 저장소에만 저장되고 동기화하지 않는다.
