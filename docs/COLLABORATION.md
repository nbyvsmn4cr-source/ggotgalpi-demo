# 꽃갈피 — 누가 무엇을

앱 코드는 친구가 만들고 GitHub도 친구 저장소가 원본입니다.  
동영은 그 저장소를 클론해서, **자기 Apple Developer 계정으로만** 실기기 서명과 스토어 배포를 합니다.

| | 동영 | 친구 |
| --- | --- | --- |
| GitHub | 클론해서 받아옴 | 원본 저장소 주인 |
| Apple | 계정 주인 (Team `7H8779959T`) | 그 팀에 App Manager로 들어가 있음 |
| 하는 일 | TestFlight / 앱스토어 업로드 | 코드, 시뮬레이터, 실기기 실행 |

원본: https://github.com/nbyvsmn4cr-source/ggotgalpi-demo

Xcode에서 **바꾸지 말 값**

- Team: **DongYoung Kim** (`7H8779959T`)
- Bundle ID: `com.dahli4.ggotgalpi`
- Signing: Automatically manage signing

---

## 동영 (이미 된 것 / 남은 것)

된 것

- Apple 팀에 친구(`writer161@live.co.kr`) App Manager로 들어가 있음
- Bundle ID `com.dahli4.ggotgalpi` 등록됨
- 이 클론에 Automatic Signing, 팀, Bundle ID가 박혀 있음
- 로컬 업로드 스크립트: `./scripts/upload-testflight.sh` / `bundle exec fastlane ios beta`

동영이 콘솔에서 한 번만

1. Xcode → Settings → Accounts에 `hellrot99@nate.com` 로그인 (이 맥에 인증서가 내려옴)
2. [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+**
   - iOS
   - 이름: 꽃갈피
   - 언어: Korean
   - Bundle ID: `com.dahli4.ggotgalpi`
   - SKU: `ggotgalpi`
3. 이후 배포는 이 맥에서:

```bash
cd ~/Documents/ggotgalpi-demo
./scripts/upload-testflight.sh
```

Git은 친구 원본을 `origin`으로 두고 풀 받으면 됩니다. Apple 키(`.p8`)는 git에 넣지 않습니다.

---

## 친구에게 시키면 되는 것

동영 Apple 멤버십은 **Individual(개인)** 이라, 친구를 App Store Connect에 초대해도 Xcode Team 목록에 **DongYoung Kim이 안 뜹니다.** Apple 제한입니다. Certificates 권한도 개인 계정에선 줄 수 없습니다.

친구가 하면 되는 것:

1. GitHub는 자기 저장소 그대로.
2. 시뮬레이터로 개발/확인.
3. 실기기 확인은 동영이 TestFlight로 올린 빌드를 설치.
4. Signing에서 자기 Personal Team으로 바꿔도 됨 — 그건 친구 폰에만 임시 설치되는 경로고, 스토어 배포랑은 별개.

동영이 하면 되는 것:

- 코드 받아서 `./scripts/upload-testflight.sh` 로 TestFlight 업로드
- 친구를 TestFlight 테스터로 추가

친구가 자기 Xcode에서 DongYoung Kim 팀으로 실기기 Run 하려면, 동영 계정을 Individual → Organization(회사/D-U-N-S)으로 바꿔야 합니다. 그 전엔 Xcode에 팀이 안 뜨는 게 정상입니다.
