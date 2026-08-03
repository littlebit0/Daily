# Daily Google Play 제출 준비

현재 공유 소스 기준은 `3.0.1`이다. Android 실기기 및 최종 AAB 검증은 아직
완료되지 않았으므로, 아래 항목은 제출 전 점검 문서로 사용한다.

## 앱 정보

- 앱 이름: `Daily`
- 패키지명: `com.littlebit0.dailycalendar`
- 카테고리: 생산성
- 버전: `3.0.1`
- versionCode: `301`
- 제출 형식: Android App Bundle

## 스토어 문구 초안

### 짧은 설명

일정, 알림, D-day와 선택적 Google Drive 동기화를 지원하는 개인 캘린더

### 자세한 설명

Daily는 개인 일정을 빠르게 기록하고 여러 기기에서 이어서 사용할 수
있는 캘린더 앱입니다.

- 주간, 월간, 일간 달력 보기
- 일정 알림과 아침 브리핑
- 반복 일정과 D-day
- 음력과 대한민국 공휴일 표시
- PIN, 생체 인증, 시스템 인증을 지원하는 앱 잠금
- 로그인 없이 사용하는 로컬 모드
- 선택적 Google Drive AppData 백업 및 기기 간 동기화

Google Drive 연결은 선택 사항입니다. 연결하면 사용자의 Google Drive
AppData 영역에 Daily 전용 데이터만 저장합니다. 일반 Google Drive 파일은
읽거나 변경하지 않습니다.

## Play Console 필수 입력

- 개인정보처리방침 URL
- 지원 이메일
- 앱 또는 지원 웹사이트 URL
- 데이터 삭제 안내 URL
- 앱 액세스: 로그인 없이 로컬 모드로 심사 가능
- 광고 포함 여부: 광고 없음
- 콘텐츠 등급 설문
- 대상 연령과 아동 대상 여부
- 데이터 보안 양식

## 데이터 보안 작성 기준

- 수집/처리 데이터: 일정, 설정, 선택한 Google Drive 연결 인증 정보
- 사용 목적: 앱 기능, 백업, 기기 간 동기화
- Google Drive 범위: `drive.appdata`
- 일반 Drive 파일 접근: 없음
- 앱 잠금 PIN: 기기 보안 저장소에만 저장, 동기화하지 않음
- Gemini API 키: 보안 저장소에만 저장, 현재 AI 기능은 비활성 상태
- 데이터 삭제: 앱 설정의 로컬 데이터 초기화 또는 Drive 백업 삭제에서
  로컬 데이터와 Drive AppData 백업 삭제

## 출시 전 실제 기기 확인

1. 앱을 완전히 삭제하고 Play 서명 빌드를 설치한다.
2. 로컬 모드가 정상적으로 시작되는지 확인한다.
3. Google Drive 연결과 Drive 권한 승인을 완료한다.
4. 기존 v2 일정과 설정이 복원되는지 확인한다.
5. 일정 생성, 수정, 삭제가 다른 기기에 반영되는지 확인한다.
6. 알림 권한과 예약 알림을 확인한다.
7. Google Drive 연결 해제와 Drive 백업 삭제 흐름을 확인한다.
8. 재설치 후 Google Drive 백업 복원을 확인한다.

## 제출 파일 검증

- AAB 파일명: `daily-android-3.0.1.aab`
- applicationId: `com.littlebit0.dailycalendar`
- versionName: `3.0.1`
- versionCode: `301`
- upload keystore 서명 확인
- SHA-256 체크섬 기록
