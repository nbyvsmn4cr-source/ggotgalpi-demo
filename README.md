# 꽃갈피

읽은 책과 그날의 감상을 달력으로 돌아보는 미니멀 SwiftUI 앱입니다. 책과 감상문은 SwiftData로 기기에 저장되며 앱을 다시 실행해도 유지됩니다. CloudKit 비공개 데이터베이스 동기화를 구성했으며, 실제 배포 전 서명된 기기 두 대에서 동기화 검증이 필요합니다.

## 주요 화면

- **감상 달력**: iOS 기본 그래픽 캘린더에서 날짜를 고르고 그날의 감상을 확인합니다.
- **책장**: 분야별 책을 살펴보고 새 책을 추가합니다.
- **나의 감상**: 최근 감상과 간단한 독서 통계를 확인합니다.
- **책 상세**: 회독, 페이지 범위, 감상 기록을 관리합니다.

## 개발 환경

- Xcode 16 이상
- iOS 17 이상
- Swift 5, SwiftUI

외부 패키지나 별도 API 키는 필요하지 않습니다.

## 시작하기

```bash
git clone https://github.com/nbyvsmn4cr-source/ggotgalpi-demo.git
cd ggotgalpi-demo
open GgotgalpiDemo.xcodeproj
```

Xcode에서 `GgotgalpiDemo` 스킴과 iPhone 시뮬레이터를 선택한 뒤 실행합니다.

실기기에서 실행하거나 배포하려면 Target의 Signing & Capabilities에서 개발 팀과 고유 Bundle Identifier를 먼저 지정하세요.

서명 없이 명령줄 빌드를 확인하려면 다음 명령을 사용할 수 있습니다.

```bash
xcodebuild \
  -project GgotgalpiDemo.xcodeproj \
  -scheme GgotgalpiDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 프로젝트 구조

```text
GgotgalpiDemo/
├── App/                    # 앱 진입점과 기본 탭
│   ├── GgotgalpiDemoApp.swift
│   └── ContentView.swift
├── Core/                   # 모델, 저장소, 디자인 토큰
│   ├── Models.swift
│   └── Theme.swift
└── Features/               # 기능별 화면
    ├── Calendar/
    ├── Library/
    └── Journal/
```

화면을 바꾸기 전에 [DESIGN.md](DESIGN.md)의 토큰과 컴포넌트 규칙을 확인해 주세요.

## 기여하기

작은 버그 수정부터 환영합니다. 작업 전 이슈를 확인하고, 변경 목적이 하나인 브랜치와 Pull Request를 만들어 주세요. 상세 절차와 품질 기준은 [CONTRIBUTING.md](CONTRIBUTING.md)에 있습니다.

현재 우선순위는 다음과 같습니다.

- iCloud 실제 기기 동기화 및 배포 환경 검증
- 책 검색 API와 메타데이터 연결
- 테스트 타깃과 핵심 모델 테스트
- VoiceOver 및 큰 글자 크기 점검

## 라이선스

[MIT License](LICENSE)로 배포됩니다.
