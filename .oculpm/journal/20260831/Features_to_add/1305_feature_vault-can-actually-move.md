---
schema_version: 1
type: feature
slug: "vault-can-actually-move"
status: done
difficulty: high
created_at: "2026-08-31T13:05:42+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/VaultRelocation.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Sources/LazyMemoUI/VaultMover.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/VaultRelocationTests.swift"
    op: create
related: []
tags:
  - "storage"
  - "settings"
  - "icloud"
  - "mcp-tool"
---
[x] 메모 폴더를 정말로 옮길 수 있다 — README 가 3일 동안 못 지킨 약속

## 추가 기능

설계문서 §5.1 은 「기본 `~/Documents/lazymemo` (설정으로 이동 가능)」이라 적었고 README 는 「이 폴더를 iCloud Drive 안으로 옮기면 동기화가 된다」고 적었는데, **앱에는 그 폴더를 따라갈 길이 없었다.** 문서가 시킨 대로 Finder 에서 옮긴 사용자가 다음에 앱을 켜면 기본 자리에 빈 폴더가 새로 생기고 화면에는 메모가 한 장도 없다 — 문서를 믿은 사람이 전부 잃은 것으로 본다. 계획은 「설정에 넣거나 문서에서 뺀다」였는데, 문서에서 빼면 그 구멍은 그대로 남는다.

메뉴 → 설정 → 「메모 폴더 옮기기…」. 지금 자리를 부제로 먼저 적는다 — 어디서 어디로 가는지 모른 채 누르는 조작이 되면 안 된다.

## 동작 흐름

- **문이 하나다.** 폴더를 고르면 앱이 상황을 보고 정한다 (`VaultRelocation.plan`) — 거기 `notes/` 가 있으면 파일을 건드리지 않고 **그 폴더를 쓰고**(이미 옮겨 둔 사람), 없으면 지금 것을 **그리로 옮긴다**(이제 옮기려는 사람). 「옮기기」와 「고르기」를 나눠 두면 사용자가 자기 상황을 먼저 판단해야 하는데, 그건 고른 자리를 보면 앱이 안다. 어느 쪽인지는 누르기 전에 글로 보여준다.
- 막는 자리 셋: 자기 안으로(옮기는 도중 원본이 사라진다), 남의 것이 든 자리로, 폴더가 아닌 것으로. 옮기기는 `moveItem` 한 번이라 실패하면 원본이 제자리에 남는다 — **반쯤 옮겨진 상태로 끝나지 않는 것**이 여기서 가장 중요하다.
- **옮기는 것은 정본뿐이다.** 파생물은 Application Support 에 남는다(D4). 덕분에 "폴더를 알아야 설정을 읽고 설정을 읽어야 폴더를 아는" 고리도 생기지 않는다 — `AppPaths.resolve` 가 고정된 support 자리에서 `vaultPath` 한 값만 먼저 읽는다.
- **옮긴 뒤 껐다 켠다.** 저장소·인덱스·감시자·떠 있는 창을 살아 있는 채로 갈아 끼우면 "반쯤 옛 자리를 보고 있는 상태" 가 생기고, 저장 버튼이 없는 앱에서 그것은 곧 글을 잃는 자리다. 옮기기 **전에** 적던 글을 전부 내리고, 인덱스는 버린다(새 자리를 훑어 다시 지어진다).
- **적어 둔 폴더가 없어졌으면** 기본 자리로 돌아가되 메뉴 첫머리에 ⚠︎ 로 적는다. 조용히 되돌아가면 사용자가 보는 것은 "메모가 전부 사라졌다" 이다. 설정도 지우지 않는다 — 외장 디스크를 도로 꽂으면 다시 그리로 간다.

## 검증

`VaultRelocationTests` 10건 신설 — 무엇을 할지 정하는 다섯 갈래(옮기기·이미 있는 것 쓰기·이미 그 자리·자기 안·남의 것), 정말 옮겼을 때 파일이 따라가고 옛 자리가 안 남는 것, 쓰기로 한 경우 양쪽 다 안 건드리는 것, 다시 켰을 때 설정을 읽는 것, 없어진 폴더, 검증용 환경변수가 설정보다 센 것. 전체 377개 통과.

`LAZYMEMO_MENU=1` 로 설정 하위 메뉴가 8개로 지어지는 것을 확인했고, `verify-restore.sh`·`verify-mcp.sh`·`verify-tidy.sh` 가 그대로 통과한다(경로 해석이 바뀌었으므로 기동 경로 전체를 다시 봤다).