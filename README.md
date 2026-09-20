# 꽃갈피

읽은 책과 그날의 감상을 달력으로 돌아보는 미니멀 SwiftUI 앱입니다. 현재 저장소는 제품 방향과 화면 흐름을 검증하는 초기 버전이며, 데이터는 앱을 다시 실행하면 초기화됩니다.

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

코드 원본은 위 저장소입니다. 실기기 서명과 TestFlight/앱스토어 배포만 DongYoung Kim 팀(`com.dahli4.ggotgalpi`)을 씁니다. 팀과 Bundle ID는 바꾸지 마세요. 동영/친구 각각 할 일은 [docs/COLLABORATION.md](docs/COLLABORATION.md)에 있습니다.

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

- SwiftData 기반 로컬 저장
- 책 검색 API와 메타데이터 연결
- 테스트 타깃과 핵심 모델 테스트
- VoiceOver 및 큰 글자 크기 점검

## 라이선스

[MIT License](LICENSE)로 배포됩니다.
