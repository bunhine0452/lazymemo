---
schema_version: 1
type: bug
slug: "drawer-drag-collapse-dismiss"
status: done
difficulty: medium
created_at: "2026-09-17T20:01:21+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/WindowDragSurface.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260917/Features_to_add/1635_feature_drawer-one-gesture-summon-bigger.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1626_feature_note-escape-puts-away.md"
    kind: "followup"
tags:
  - "mac"
  - "drawer"
  - "ux"
  - "window"
  - "mcp-tool"
---
[x] 맥 서랍 — 탭이 끌리지 않고, 펼친 판이 사라지지 않는다: 손잡이·떠나면 접힘·치우는 길

## 발생 원인

사용자(0.8.0 설치판): 「mac 에서 서랍이 사라지지도 않고 드래그도 안돼」. 셋이 겹쳐 있었다.

1. **끌리지 않음** — 닫힌 탭은 SwiftUI `Button` 하나가 232×60 판 전체를 덮고, 펼친 판도 조작으로 차 있어 창을 잡을 데가 없었다. 창의 `isMovableByWindowBackground = true` 는 호스팅 뷰 안에서 실제로 끌리지 않는다 — 같은 날 낮에 종이의 손잡이(`PaperGrip`, 1626 일지)가 배운 사실인데 서랍은 그 길을 타지 않았다.
2. **사라지지 않음 ①** — 16:35 판(§16.12)이 메뉴바 「서랍」을 «펼친 채 앞으로»로 바꾸면서 펼친 판이 `focusedLevel` 로 올라선다. 그 채로 다른 앱을 누르면 `resignKey` 로 바탕화면 레벨에 내려앉되 **펼쳐진 채** 남았다 — 바탕화면을 다시 본 사람에게는 440×344 판이 눕혀져 있었다.
3. **사라지지 않음 ②** — 바탕화면에서 아예 치우는 항목이 ⌥ 뒤에 숨었다(Progressive Disclosure). 「서랍」이 상주 스위치이던 앞선 판의 손버릇으로 같은 항목을 눌러도 판이 앞으로 나올 뿐 사라지지 않았다.

## 해결 방법

- `WindowDragSurface`(새 파일): `mouseDown` → `performDrag`, 끝난 뒤 창이 3pt 안에서 멈췄으면 누른 것(`isClick(moved:)`) — `MemoNSTextView.dragPaper` 와 같은 길. 오른쪽 버튼은 `menu(for:)` 로 메뉴. 닫힌 탭에 overlay(누르면 `toggle`, 우클릭 「펼치기 · 바탕화면에서 치우기」), 펼친 판의 머리 줄(「서랍 · N」)에 background 로 붙였다. 화면 밖 렌더에서는 뺀다(§14.9).
- `DrawerWindowController.appDidResignActive` — `didResignActiveNotification` 에 `model.setOpen(false)`. 종이가 판 위에 떠 있는 동안(`landing`)과 무대(`stageLevel`) 위에서는 접지 않는다. 같은 앱 안의 종이 클릭은 알림이 안 오므로 열린 판에 끌어다 넣는 길은 그대로.
- 메뉴바: 「서랍 치우기 — 바탕화면에서 / 서랍 내놓기」를 ⌥ 대체 항목에서 **보이는 한 줄**(들여쓰기 1)로. 툴팁의 ⌥ 문구 삭제. `DrawerModel.onDismiss` 로 탭의 우클릭이 창을 걷는다.
- DESIGN §16.13, README 서랍 표 두 줄.

## 검증

- `swift build` ✓ · `./scripts/test.sh` 전체 초록(939, 새 시험 `DrawerTests.tabClickVersusDrag`) · `./scripts/verify-drawer.sh` ✓ (`앞으로=true 내려앉음=true`, 232×60 ↔ 440×344).
- `scripts/render-ui.sh` 로 서랍 장면 렌더 확인 뒤 `build/ui` 삭제.
- **사람 눈 확인 필요**: 탭을 잡아 끌면 옮겨지고 그냥 놓으면 펼쳐지는가 · 펼친 채 브라우저를 누르면 탭으로 접히는가 · 탭 우클릭 「바탕화면에서 치우기」와 메뉴의 「서랍 치우기」.

## 메모

- 「사라지지 않는다」는 두 뜻 다 고쳤다 — 어느 쪽이었는지 사용자에게 확인받지 않고 둘 다 덮었다.
- `NSApp.deactivate()` 뒤 `resignKey` 가 레벨을 내리는 기존 규칙은 그대로다. 이번 판은 «펼침 상태»만 더 접는다.