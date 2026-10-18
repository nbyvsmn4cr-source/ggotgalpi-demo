# 아이클라우드 동기화 마무리용 프롬프트

동영은 아래 코드블록만 복사해서 친구에게 보내면 됩니다.
친구는 자기 프로젝트를 연 코딩 AI(Cursor, Claude, ChatGPT 등)에 그대로 붙여넣습니다.

---

```text
너는 이 Mac에서 꽃갈피 iOS 앱을 도와주는 코딩 에이전트다.
나는 개발자가 아니다. 바이브코딩으로 앱을 만들고 있고, GitHub 원본 저장소는 내 것이다.
앱스토어 배포는 친구 동영의 Apple 개발자 계정으로 한다.

목표:
아이클라우드(CloudKit) 동기화가 실제 기기에서 켜지고, 폰 두 대에서 같은 책과 기록이 보이게 마무리한다.

이미 되어 있는 것 (확인된 사실):
- 코드: 커밋 cd70f96 "Add CloudKit sync configuration"이 main에 있다.
  GgotgalpiDemo/App/GgotgalpiDemoApp.swift 에서 ModelConfiguration(cloudKitDatabase: .private("iCloud.com.dahli4.ggotgalpi")) 를 쓴다.
  GgotgalpiDemo/GgotgalpiDemo.entitlements 에 컨테이너와 CloudKit 서비스가 적혀 있다.
- 애플 쪽: 번들 ID com.dahli4.ggotgalpi 에 iCloud 기능은 동영이 이미 켰다.
- 애플 쪽에 아직 없는 것: iCloud 컨테이너 iCloud.com.dahli4.ggotgalpi, App Store Connect 앱 레코드.
- 동기화되지 않는 설정값: 즐겨찾는 작가, 달력 책 순서, 휴지통 보관일(UserDefaults, GgotgalpiDemo/Core/Models.swift).

고정값 (절대 바꾸지 마. 네가 "고치는" 대상이 아님):
- GitHub 원본: https://github.com/nbyvsmn4cr-source/ggotgalpi-demo  (이 저장소 유지)
- DEVELOPMENT_TEAM: 7H8779959T  (Xcode 표시 이름: DongYoung Kim)
- PRODUCT_BUNDLE_IDENTIFIER: com.dahli4.ggotgalpi
- CODE_SIGN_STYLE: Automatic
- iCloud 컨테이너: iCloud.com.dahli4.ggotgalpi

주의: 지금 main 의 project.pbxproj 는 DEVELOPMENT_TEAM 이 3YXRY8X9JJ 로 되어 있다.
동영의 서명 PR(#2)이 아직 머지되지 않았다. 컨테이너를 만들려면 팀이 7H8779959T 여야 한다.

하지 마:
- 다른 Team ID나 개인 팀으로 서명 바꾸기
- Bundle ID 또는 컨테이너 이름 바꾸기
- 새 Apple Developer 계정 만들기
- 인증서 p12, API 키(.p8)를 저장소에 넣기
- git push --force

먼저 할 일 (코드):
1. git remote 로 이 폴더가 nbyvsmn4cr-source/ggotgalpi-demo 클론인지 확인한다.
2. 시뮬레이터에서 앱을 켜서 CloudKit 설정 때문에 바로 죽지 않는지 확인한다.
   죽으면 에러 문장을 그대로 나에게 보여준다. (Book.entries 같은 to-many 관계가 선택값이 아니면
   CloudKit 연동에서 컨테이너 생성이 실패할 수 있다. 추측이니 실제로 확인한다.)
3. 예전 버전으로 만든 책과 기록이 있는 기기에서 새 빌드를 덮어 설치해도 데이터가 남는지 확인한다.
4. UserDefaults 설정값 세 개를 동기화할지 나에게 한 줄로 묻고, 하라고 하면 NSUbiquitousKeyValueStore 로 옮긴다.
   옛 값은 첫 실행에서 그대로 읽어 온다.

끝난 뒤 나에게는 코드 설명이 아니라, 아래를 클릭 순서 그대로 적어줘. 이 단계는 네가 대신 로그인할 수 없다.

내가 직접 하는 것:
1. Xcode 연다
2. Xcode → Settings → Accounts → Apple ID 추가, 동영 팀에 초대된 메일로 로그인한다
3. GgotgalpiDemo.xcodeproj 연다
4. Target GgotgalpiDemo → Signing & Capabilities → Team 이 DongYoung Kim 인지 본다
5. iCloud 항목에서 CloudKit 이 켜져 있고 컨테이너 iCloud.com.dahli4.ggotgalpi 가 선택되어 있는지 본다
   (처음엔 컨테이너가 없을 수 있다. 그때는 + 로 같은 이름을 만든다. 팀 권한이 부족하면 동영에게 알린다)
6. 아이클라우드에 로그인된 내 아이폰에 Run 한다
7. 책을 하나 추가하고, 같은 애플 계정의 다른 아이폰이나 아이패드에서 몇 분 안에 보이는지 본다

동영이 하는 것 (친구가 하지 않는다):
1. App Store Connect 에서 새 앱 만들기: 이름 꽃갈피, 번들 com.dahli4.ggotgalpi
2. 스토어에 내기 전에 CloudKit Dashboard 에서 스키마를 Production 으로 배포하기
   (이걸 안 하면 스토어에서 받은 앱은 동기화가 안 된다)
```
