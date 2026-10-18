# 출시 점검 — 2026-10-18

## 완료

- PR #3 병합: `162c9ecb4630f7982d997c6f89cb03d57b102e6b`. PR 내용은 iCloud 구현 지침 문서이며 실제 수정은 별도 로컬 작업입니다.
- CloudKit 모델 검증 실패를 재현하고 Book.entries 관계를 선택형으로 수정했습니다.
- 저장소 초기화 실패 시 기존 데이터를 삭제하지 않고 오류와 재시도를 표시합니다.
- 저장 실패 시 입력 화면을 닫지 않고 오류를 표시합니다.
- 원격 가져오기 완료/앱 활성화 시 목록을 갱신합니다.
- 최초 실행의 샘플 자동 생성 제거. 기존 기록은 유지합니다.
- 읽기 완료 체크 해제 시 회독 수 복원, 페이지 범위 유효성 검사.
- 앱 아이콘, PrivacyInfo.xcprivacy, 원격 알림 백그라운드 설정 추가.
- 시뮬레이터 Debug 빌드 성공. Xcode 임시 서명으로 iPhone 17 Pro / iOS 26.5 실행 및 달력 화면 유지 확인.
- 기존 시뮬레이터 저장소 책 5권·감상문 9개가 업데이트 후에도 유지됨을 확인했습니다. 모든 필드의 동일성 검증과 동일한 의미는 아닙니다.
- 실제 모델을 사용한 임시 디스크 저장소 테스트 통과: 빈 설치, 선택 날짜, 반점 별점, 대표 감상문, 휴지통/복원, 디스크 재읽기, 31일 후 만료 삭제, 책 삭제 관계 처리, 샘플 재생성 없음.

## 제출 전 남은 필수 확인

- 개발 팀에서 App ID와 `iCloud.com.dahli4.ggotgalpi` 컨테이너, Push Notifications 및 배포 프로파일을 구성하고 Archive/TestFlight 업로드해야 합니다.
- 같은 Apple 계정의 실기기 두 대로 신규/수정/삭제/오프라인 복귀 동기화를 확인해야 합니다. 시뮬레이터 로컬 저장 테스트는 이를 대신하지 않습니다.
- CloudKit 개발 스키마를 Production에 배포하고 TestFlight에서 확인해야 합니다.
- 개인정보처리방침·지원 문서를 공개 URL로 게시하고 실제 문의 접수가 가능한지 확인해야 합니다. `docs/privacy.md`, `docs/support.md`는 아직 로컬 초안입니다. 지원 창구는 공개 GitHub Issues를 제안했으므로 운영자가 채택 여부를 확인해야 합니다.
- App Store Connect의 개인정보 응답, 연령 등급, 설명·스크린샷·가격 등을 실제 출시 설정에 맞춰 작성해야 합니다.
- iOS 17 런타임 및 실제 최소 지원 기기 검증은 미완료입니다. 전체 UI 흐름/접근성/모든 기기의 무결점을 보증하지 않습니다.

## 저장 회귀 테스트

```sh
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 GgotgalpiDemo/Core/Models.swift Tests/PersistenceRegression.swift -o /private/tmp/ggotgalpi-persistence-regression
/private/tmp/ggotgalpi-persistence-regression
```

## 시뮬레이터 빌드 주의

CloudKit을 사용하는 앱을 `CODE_SIGNING_ALLOWED=NO`로 빌드하면 컴파일은 성공해도 CloudKit 권한이 누락되어 실행 시 종료될 수 있습니다. 기능 검증에는 Xcode의 시뮬레이터 임시 서명을 사용합니다.

```sh
xcodebuild -project GgotgalpiDemo.xcodeproj -scheme GgotgalpiDemo -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ggotgalpi-signed-simulator CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO build
```

이는 실제 기기 배포 서명이나 iCloud 계정 간 동기화 검증을 대신하지 않습니다.
