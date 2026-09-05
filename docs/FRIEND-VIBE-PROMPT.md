# 친구 바이브코딩용 프롬프트

동영은 아래 코드블록만 복사해서 친구에게 보내면 됩니다.  
친구는 자기 프로젝트 연 코딩 AI(Cursor, Claude, ChatGPT, Grok 등)에 그대로 붙여넣습니다.

---

```text
너는 이 Mac에서 꽃갈피 iOS 앱을 도와주는 코딩 에이전트다.
나는 개발자가 아니다. 바이브코딩으로 앱을 만들고 있고, GitHub 원본 저장소는 내 것이다.
앱스토어 배포는 친구 동영의 Apple 개발자 계정으로 한다. 나는 코드 작성 + 시뮬레이터 + 내 아이폰에서 실행만 한다.

목표:
코드는 내 GitHub에서 계속 만들고, 시뮬레이터로 실행되게 유지해라.
실기기/앱스토어 서명은 동영 개인 개발자 계정이라 내 Xcode Team에 안 뜬다. 그걸 “고치려고” 팀을 바꾸거나 새 개발자 계정을 만들지 마.

고정값 (절대 바꾸지 마. 네가 “고치는” 대상이 아님):
- GitHub 원본: https://github.com/nbyvsmn4cr-source/ggotgalpi-demo  (이 저장소 유지. 포크로 옮기지 마)
- Xcode Team 표시 이름: DongYoung Kim
- DEVELOPMENT_TEAM: 7H8779959T
- PRODUCT_BUNDLE_IDENTIFIER: com.dahli4.ggotgalpi
- CODE_SIGN_STYLE: Automatic
- 내 Apple ID (Xcode 로그인용): writer161@live.co.kr

하지 마:
- 내 개인팀 / 다른 Team ID로 서명 바꾸기
- Bundle ID를 com.ggotgalpi.demo 나 내 이름으로 바꾸기
- 새 Apple Developer 계정 만들기
- App Store Connect, TestFlight, 인증서 p12, API 키(.p8) 세팅
- Fastlane/GitHub Actions으로 배포 파이프라인 만들기
- 저장소를 동영 포크(dahli4)로 원본 바꾸기
- git push --force
- 동영에게 내 비밀번호/인증서 파일을 달라고 하기

먼저 할 일:
1. 지금 폴더가 nbyvsmn4cr-source/ggotgalpi-demo 클론인지 git remote로 확인
2. GgotgalpiDemo.xcodeproj/project.pbxproj 에서 DEVELOPMENT_TEAM, PRODUCT_BUNDLE_IDENTIFIER, CODE_SIGN_STYLE 값을 확인
3. 위 고정값과 다르면 Debug/Release 둘 다 고정값으로 맞추고, Automatically manage signing 유지
4. 동영이 올린 서명 PR이 있으면 머지하는 쪽이 더 좋다:
   https://github.com/nbyvsmn4cr-source/ggotgalpi-demo/pull/2
   내가 이 저장소 주인이면 gh로 머지하거나, 내가 GitHub에서 머지하라고 한 줄로 안내
5. 시뮬레이터 빌드가 되면 이걸로 확인:
   xcodebuild -project GgotgalpiDemo.xcodeproj -scheme GgotgalpiDemo -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

끝난 뒤 나에게 짧게 안내해라.

내가 직접 하는 것:
1. Xcode에서 시뮬레이터로 Run
2. Signing & Capabilities에 DongYoung Kim 팀이 없어도 정상이다. 동영 계정이 Individual(개인)이라 내 Apple ID로는 그 팀이 안 뜬다.
3. 내 아이폰에서 보려면 동영이 TestFlight로 올린 빌드를 설치한다.
4. 내 Personal Team으로 내 폰에 직접 깔아보는 건 선택. 그건 스토어 배포가 아니다.

Done-when:
- pbxproj에 Team 7H8779959T, Bundle com.dahli4.ggotgalpi, Automatic 이 들어있다 (동영이 배포할 때 쓰는 값)
- 시뮬레이터 빌드가 통과한다
- 내가 팀을 못 고르는 이유를 한 줄로 설명해 줬다
- 배포/인증서/스토어 파이프라인을 새로 만들지 않았다
```
