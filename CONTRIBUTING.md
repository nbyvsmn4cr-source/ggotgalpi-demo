# 꽃갈피에 기여하기

꽃갈피에 관심을 가져 주셔서 감사합니다. 이 문서는 처음 기여하는 사람도 같은 기준으로 변경을 제안할 수 있도록 만든 짧은 안내입니다.

## 작업 시작 전

1. 기존 이슈와 Pull Request에 같은 제안이 있는지 확인합니다.
2. 큰 기능이나 화면 방향 변경은 구현 전에 이슈로 먼저 논의합니다.
3. 하나의 브랜치에는 하나의 목적만 담습니다.

문서 오타, 접근성 레이블, 작은 버그처럼 범위가 분명한 변경은 바로 Pull Request를 열어도 됩니다.

## 로컬 실행

저장소를 클론한 뒤 `GgotgalpiDemo.xcodeproj`를 Xcode에서 엽니다. 외부 패키지는 없습니다.

실기기 실행은 [docs/COLLABORATION.md](docs/COLLABORATION.md)를 따릅니다. Signing Team과 Bundle Identifier는 커밋된 값을 유지합니다.

제출 전 최소 검증:

```bash
xcodebuild \
  -project GgotgalpiDemo.xcodeproj \
  -scheme GgotgalpiDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

화면 변경은 iPhone 시뮬레이터에서 직접 실행하고 다음을 확인해 주세요.

- 기본 글자 크기와 큰 글자 크기에서 내용이 잘리지 않는가
- 탭, 버튼, 날짜 선택이 VoiceOver에서 이해되는가
- 긴 책 제목과 빈 데이터 상태가 무너지지 않는가
- `DESIGN.md`의 색상, 간격, 공통 컴포넌트를 재사용했는가

## Pull Request

- 제목은 변경 결과를 짧게 설명합니다.
- 본문에 해결한 문제, 검증 방법, 관련 이슈를 적습니다.
- 화면 변경에는 전후 스크린샷 또는 짧은 영상을 첨부합니다.
- 관련 없는 포맷 변경이나 리팩터링을 함께 넣지 않습니다.
- CI 빌드가 통과해야 검토를 요청할 수 있습니다.

모든 기여자는 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)를 따라야 합니다.
