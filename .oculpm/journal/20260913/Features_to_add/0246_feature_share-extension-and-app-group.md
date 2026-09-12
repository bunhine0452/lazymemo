---
schema_version: 1
type: feature
slug: "share-extension-and-app-group"
status: done
difficulty: medium
created_at: "2026-09-13T02:46:01+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Inbound/InboxDrop.swift"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/InboxDropTests.swift"
    op: create
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemoShare/ShareViewController.swift"
    op: create
  - path: "ios/Config/Share-Info.plist"
    op: create
  - path: "ios/Config/LazyMemoShare.entitlements"
    op: create
  - path: "ios/Config/LazyMemo.entitlements"
    op: update
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
related:
  - ref: "20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md"
    kind: "followup"
tags:
  - "ios"
  - "share-extension"
  - "icloud"
  - "inbound"
  - "mcp-tool"
---
[x] 공유 시트의 「lazymemo 에 적기」 — 확장 타깃, App Group 폴백, 인덱스 없는 떨구기

## 추가 기능

맥의 서비스 메뉴 「lazymemo 에 적기」의 폰 판. 다른 앱에서 글이나 주소를 공유하면 시트 하나가 뜨고(받은 글을 고칠 수 있다) 「메모 남기기 / 달력에 남기기」로 끝난다 — 단추 이름은 앱의 빠른 입력과 같은 규칙(`NoteReader`).

- **`InboxDrop.drop`** (Core) — `MemoService` 를 띄우지 않고 `MemoVault.save` 로 정본 한 장만 쓴다. 인덱스는 파생물이라 앱이 짓는 것이고(§5.3), 확장은 메모리 한도가 빡빡하다. 앱이 다음에 켜지거나 감시가 발화하면 `reconcile` 이 올린다 — 단축어가 떨군 파일이 지나는 길과 같다.
- **App Group `group.io.github.bunhine0452.lazymemo`** — iCloud 가 꺼져 있을 때의 폰 Vault 자리. 확장은 앱의 샌드박스를 못 보므로, 그냥 Documents 에 두면 「lazymemo 에 적기」가 iCloud 를 끈 사람에게는 아무 데도 적지 못하는 문이 된다. `AppPaths.resolveCloud(container:shared:)` 의 차례: `LAZYMEMO_VAULT` > 컨테이너 > App Group > 로컬.
- **Xcode 타깃 `LazyMemoShare`** (app-extension) — 동기화 그룹 `ios/LazyMemoShare/`, `Config/Share-Info.plist`(NSExtension: 글·주소 하나), `Config/LazyMemoShare.entitlements`(iCloud 셋 + App Group), 앱 타깃에 「Embed Foundation Extensions」 복사 단계와 의존. 앱 entitlement 에도 App Group 을 더했다.
- `SharedInput.text(from:)` — `plainText` 면 글, `url` 이면 주소, 둘 다 없으면 `attributedContentText`. `loadItem` 이 `Data` 로 주는 경우도 받는다.

## 동작 흐름

- `-allowProvisioningUpdates` 기기 빌드로 확장의 App ID(`….lazymemo.share`)와 App Group 이 개발자 계정에 등록됐다. 앱·확장 두 바이너리 모두 서명에 iCloud 컨테이너 + App Group 이 박혀 있다.
- 시트의 생김새는 스모크 수준이다 — 디자인 세션(`docs/MOBILE_DESIGN.md`)이 정하는 대로 다시 그린다. 문과 쓰기 경로는 그대로다.
- 사진 공유는 아직 받지 않는다(`AttachmentStore` 경유가 필요) — 활성화 규칙에 이미지를 안 넣었으니 시트에 나타나지도 않는다.

## 검증

- `InboxDropTests` 4건 — 다른 문과 같은 규칙으로 파일이 됨(`at`·`place`·본문), 인덱스를 안 만듦, App Group 이 로컬 Vault 가 됨, 컨테이너가 App Group 보다 먼저. Core 382개 통과.
- 시뮬레이터 빌드에 `PlugIns/LazyMemoShare.appex` 가 들어 있고 `NSExtensionPrincipalClass = LazyMemoShare.ShareViewController`. UI 스모크 통과.
- 시트를 실제로 눌러 보는 것은 실기기(`release-device`)에서 — 시뮬레이터의 공유 시트는 손이 필요하다.