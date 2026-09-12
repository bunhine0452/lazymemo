---
schema_version: 1
type: feature
slug: "ios-app-project-and-icloud-container"
status: done
difficulty: medium
created_at: "2026-09-13T02:21:06+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: create
  - path: "ios/LazyMemo.xcodeproj/xcshareddata/xcschemes/LazyMemo-iOS.xcscheme"
    op: create
  - path: "ios/Config/Info.plist"
    op: create
  - path: "ios/Config/LazyMemo.entitlements"
    op: create
  - path: "ios/LazyMemo/LazyMemoApp.swift"
    op: create
  - path: "ios/LazyMemo/AppModel.swift"
    op: create
  - path: "ios/LazyMemo/RootView.swift"
    op: create
  - path: "ios/LazyMemo/Assets.xcassets/Contents.json"
    op: create
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/AppPathsTests.swift"
    op: update
  - path: ".gitignore"
    op: update
related:
  - ref: "20260913/Features_to_add/0206_feature_core-compiles-for-ios.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1305_feature_vault-can-actually-move.md"
    kind: "followup"
tags:
  - "ios"
  - "icloud"
  - "xcode"
  - "storage"
  - "uitest"
  - "mcp-tool"
---
[x] iOS 앱이 섰다 — Xcode 프로젝트, iCloud 컨테이너 entitlement, 적으면 파일이 되는 스모크

## 추가 기능

`ios/` 에 iOS 앱 셸. 패키지 밖에 두고 `LazyMemoCore` 만 로컬 패키지(`..`)로 끌어 쓴다 — `swift build`·`swift test` 가 iOS 전용 타깃을 맥에서 지으려 드는 일이 없다. 프로젝트 파일은 손으로 썼다(objectVersion 77, 파일 시스템 동기화 그룹) — XcodeGen 같은 도구 하나를 더 들이지 않으려고. `xcodebuild -list` 와 빌드·시험으로 확인했으니 Xcode 가 열면 그대로 읽는다.

- **타깃 이름은 `LazyMemo-iOS`, 산출물은 `LazyMemo.app`.** 패키지의 실행 타깃도 `LazyMemo` 라 스킴 이름이 겹쳤다.
- **iCloud 컨테이너 `iCloud.io.github.bunhine0452.lazymemo`.** entitlement 셋(container-identifiers·icloud-services CloudDocuments·ubiquity-container-identifiers) + `Info.plist` 의 `NSUbiquitousContainers` 로 파일 앱·Finder 에 「LazyMemo」 폴더로 공개. `INFOPLIST_KEY_*` 로는 사전형을 못 적어 이 키만 `ios/Config/Info.plist` 에 두고 나머지는 생성한다. `Config/` 는 동기화 그룹이 아니라 보통 그룹 — 동기화 그룹에 plist 를 두면 리소스 복사 단계에 끌려 들어간다.
- **`AppPaths.resolveCloud(container:)`** — 컨테이너가 있으면 그 `Documents/` 가 vault, 파생물은 그대로 Application Support. **어느 쪽이었는지(`usingCloud`)를 들고 나온다** — 조용히 로컬로 떨어지면 사용자는 「맥에 안 나타난다」만 본다. `LAZYMEMO_VAULT` 가 컨테이너보다 세다(시험이 진짜 iCloud 를 건드리면 안 된다). 맥의 「iCloud 로 동기화」도 이 함수를 쓸 것이라 울타리 없이 Core 에 뒀다.
- **`AppModel`** 이 컨테이너 찾기를 `Task.detached` 로 메인 밖에서 하고(첫 호출이 iCloud 데몬과 이야기하는 막히는 호출), `MemoStore` 를 연다. 화면 바닥 한 줄이 「iCloud 의 LazyMemo 폴더를 맥과 함께 봅니다 / 이 기기에만 남습니다 — iCloud 가 꺼져 있습니다」를 말한다.
- **스모크 화면** — 적는 칸 + 「메모 남기기」 단추 + 목록. ⏎ 는 다음 줄이다(맥과 같다). 날짜가 읽히면 단추가 「달력에 남기기」로 바뀐다. `NoteReader.read` 를 그대로 쓰므로 `dentist tomorrow at 3pm` 이 맥의 빠른 입력과 **같은 규칙**으로 `at:` 이 된다.

## 동작 흐름

- 시뮬레이터에는 iCloud 가 없어 로컬로 떨어진다: `<샌드박스>/Documents/lazymemo/notes`·`.trash`, `Library/Application Support/lazymemo/index.sqlite` — 맥과 **같은 레이아웃**이다.
- 맥 형식 그대로의 `.md` 를 notes 에 떨어뜨리고 켜면 제목과 날짜가 목록에 보인다 (읽기 경로). 적어서 남기면 frontmatter + `at:` + 본문이 파일로 떨어지고 목록에 뜬다 (쓰기 경로).
- **XCUITest 가 손을 대신한다** (`LazyMemoUITests/SmokeTests`) — 맥의 `scripts/verify-*.sh` 자리. `launchEnvironment["LAZYMEMO_VAULT"]` 로 버리는 폴더를 주고, 칸을 누르고 치고 단추를 누르고, 목록과 파일을 함께 확인한다. AppleScript 로 시뮬레이터에 키를 넣는 길은 두 번 시도하고 접었다 — 손이 닿지 않는다.
- 시험 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` — 앱 타깃의 MainActor 기본이 `XCTestCase` 의 `setUp` 재정의와 부딪힌다.
- `-allowProvisioningUpdates` 로 기기 대상 빌드를 한 번 돌려 **개발자 계정에 명시적 App ID 와 iCloud 컨테이너가 등록됐다.** 기기 빌드의 서명에 세 entitlement 가 박혀 있고 프로필도 그 컨테이너를 담고 있다. 시뮬레이터 빌드의 서명은 빈 entitlement 인데 이건 정상이다.

## 검증

- `xcodebuild test -scheme LazyMemo-iOS -destination 'platform=iOS Simulator,name=iPhone 17'` → 1 test, 0 failures (파일 한 장, `---` 로 시작, `at:` 있음, 본문 `dentist`).
- `xcodebuild build -destination generic/platform=iOS -allowProvisioningUpdates` → BUILD SUCCEEDED, `codesign -d --entitlements` 에 icloud-container-identifiers·CloudDocuments·ubiquity-container-identifiers.
- `AppPathsTests` 7개(신설 3) 통과, 맥 `swift build` 그대로.