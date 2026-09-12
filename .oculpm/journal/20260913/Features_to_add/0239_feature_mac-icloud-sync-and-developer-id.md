---
schema_version: 1
type: feature
slug: "mac-icloud-sync-and-developer-id"
status: done
difficulty: medium
created_at: "2026-09-13T02:39:31+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/VaultRelocation.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoTimeLabel.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MemoRow.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/VaultMover.swift"
    op: update
  - path: "Resources/LazyMemo.entitlements"
    op: create
  - path: "scripts/build-app.sh"
    op: update
  - path: "Tests/LazyMemoCoreTests/VaultRelocationTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoVaultTests.swift"
    op: update
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
  - path: "ios/LazyMemo/LazyMemoApp.swift"
    op: update
  - path: "ios/LazyMemo/Theme.swift"
    op: create
related:
  - ref: "20260913/Features_to_add/0226_feature_icloud-watcher-placeholders-conflicts.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1305_feature_vault-can-actually-move.md"
    kind: "followup"
tags:
  - "icloud"
  - "storage"
  - "settings"
  - "signing"
  - "macos"
  - "mcp-tool"
---
[x] 맥이 iCloud 를 같이 본다 — 「iCloud 로 동기화…」, 안 내려온 파일, Developer ID 서명 경로

## 추가 기능

- **설정 → 「iCloud 로 동기화…」** (`VaultMover.beginCloud`). 컨테이너는 두 길로 찾는다 — entitlement 있는 빌드는 `AppPaths.ubiquityContainer()`, 없는 빌드(소스·ad-hoc)는 `AppPaths.cloudContainerOnDisk()` 가 `~/Library/Mobile Documents/iCloud~io~github~bunhine0452~lazymemo/` 를 본다 (**폴더가 있을 때만** — 없는 자리에 빈 폴더를 만들면 iCloud 는 그것을 컨테이너로 치지 않는다). 둘 다 없으면 왜 안 되는지를 적는다. 이미 그 안이면 메뉴가 「iCloud 로 동기화 중」으로 눌리지 않는다.
- **`VaultRelocation.planCloud` → `.merge(into:existing:)`.** 컨테이너의 `Documents/` 는 iCloud 의 것이라 통째로 갈아 끼울 수 없고(지우면 컨테이너가 아니다), 폰이 먼저 적은 메모가 들어 있을 수 있다. 그래서 `.move` 가 아니라 **하나씩 들여놓는** 새 계획이다 — 같은 이름의 폴더는 안으로 들어가 다시 합치고, 같은 이름의 파일은 건너뛰어 어느 쪽도 지우지 않는다(ULID 라 실제로 겹치지 않는다). 옛 껍데기는 비었을 때만 치운다. 확인 창이 「거기 이미 있는 N장과 합쳐집니다」를 말한다.
- **`MemoVault.requestMissingDownloads`** — 숨은 `.<ulid>.md.icloud` 를 찾아 진짜 파일 이름으로 `startDownloadingUbiquitousItem`. `MemoService.reconcile` 이 `adopt` 다음에 부른다. 맥의 「Mac 저장 공간 최적화」가 치운 메모, 폰이 먼저 적어 맥에 처음 오는 메모가 이것으로 나타난다. 내려오면 FSEvents 가 발화해 다시 대조한다. 사진(`attachments/`)은 청하지 않는다 — 메모가 아니다.
- **`build-app.sh` 의 서명 셋.** `LAZYMEMO_SIGN_IDENTITY` 가 있으면 Developer ID + 강화된 런타임 + 타임스탬프로 안의 `lazymemo-mcp` 부터 서명한다(`--deep` 은 순서를 보장하지 않아 공증에서 걸린다). `LAZYMEMO_PROFILE` 이 있을 때만 `Resources/LazyMemo.entitlements`(iCloud 셋)를 붙이고 `embedded.provisionprofile` 을 넣는다 — 프로필 없이 제한된 entitlement 를 달면 macOS 가 앱을 열어 주지 않는다. `LAZYMEMO_NOTARY_PROFILE` 이 있으면 `notarytool submit --wait` + `stapler`. 없으면 지금처럼 ad-hoc.
- `MemoTimeLabel` 을 `LazyMemoUI/MenuBar/MemoRow.swift` 에서 **Core 로 올렸다** — 폰 목록도 「오늘 15:00」·「내일」·「3일 뒤」를 같은 낱말로 적어야 한다.
- 폰 셸: `AppModel.Session`(store·settings·draft·usingCloud), 뒤로 갈 때 초안 내리기·앞으로 올 때 대조, `Theme.swift`(맥 토큰의 UIColor 판). 화면은 디자인 세션이 끝난 뒤 그린다.

## 동작 흐름

- bash 3.2 에서 `set -u` 와 빈 배열 전개가 부딪혔다 — `${ARR[@]+"${ARR[@]}"}` 꼴로.
- Developer ID 로 실제 서명해 봤다: 두 바이너리 모두 `flags=0x10000(runtime)`, `Authority=Developer ID Application`, 타임스탬프 있음. `spctl` 은 「Unnotarized Developer ID」 — 공증 자격(`notarytool store-credentials`)과 iCloud 가 든 Developer ID 프로비저닝 프로필은 **사용자가 개발자 포털에서 만들어야** 하는 것이라 여기서 끝난다. 프로필 없이도 Mobile Documents 폴더로는 동기화된다.

## 검증

- `VaultRelocationTests` +5 (컨테이너 계획은 merge 이고 기존 수를 든다, 이미 안이면 alreadyThere, 합치면 양쪽이 모이고 껍데기가 없어진다, 같은 이름은 어느 쪽도 안 지운다, Mobile Documents 폴더가 있을 때만 컨테이너). `MemoVaultTests` +2 (플레이스홀더 이름 되읽기, 보통 폴더는 0). 맥 전체 **693개 통과**, iOS 스모크 통과.
- `LAZYMEMO_SIGN_IDENTITY=… ./scripts/build-app.sh release` 성공, `codesign --verify` 통과.
- 「iCloud 로 동기화…」를 진짜 컨테이너로 눌러 보는 것은 `release-device` 에서 — 이 맥에는 아직 폰이 만든 폴더가 없다.