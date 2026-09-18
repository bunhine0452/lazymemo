---
schema_version: 1
type: bug
slug: "drawer-performdrag-returns-immediately"
status: done
difficulty: high
created_at: "2026-09-18T16:49:49+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/WindowDragSurface.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "scripts/verify-drawer-mouse.sh"
    op: create
  - path: "scripts/verify-drawer-mouse.swift"
    op: create
  - path: "scripts/verify-drawer.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260917/Bugs/2001_bug_drawer-drag-collapse-dismiss.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1635_feature_drawer-one-gesture-summon-bigger.md"
    kind: "followup"
tags:
  - "mac"
  - "drawer"
  - "appkit"
  - "window"
  - "verification"
  - "mouse"
  - "mcp-tool"
---
[x] 맥 서랍 — 잡기만 해도 펼쳐지고 끌리지 않았다: performDrag 는 곧바로 돌아온다, 손이 움직인 거리로 가른다

## 발생 원인

사용자(0.8.3): 「서랍은 아직도 이동도 안 되고 닫히지도 않아」. 어제 저녁의 손잡이(`WindowDragSurface`, 2001 일지)는 산수 검증(`verify-drawer.sh`)과 정적 렌더를 다 통과했는데 실제로는 안 끌렸다 — 사람 눈 확인이 없던 판이다.

이번에는 **진짜 마우스**로 재현했다. 이 셸에 손쉬운 사용 권한이 있어 합성 HID 이벤트를 창 서버에 넣을 수 있고(`CGEvent.post`), 결과는 `CGWindowListCopyWindowInfo` 로 읽는다. 합성 이벤트는 그 자리의 **맨 앞 창**에 닿으므로 바탕화면 높이의 서랍에는 닿지 않는다 → `LAZYMEMO_STAGE=1`(무대 높이) · `LAZYMEMO_DRAWER=summon`(메뉴바처럼 앞으로) 두 통로를 새로 뚫었다. 탭을 120pt 끌었더니 **24pt 가고 펼쳐졌다**.

원인은 하나. `NSWindow.performDrag(with:)` 는 마우스를 놓을 때까지 붙잡고 있지 않는다 — **곧바로 돌아오고**(계측: 0ms) 창 서버가 비동기로 끈다. 그래서 「돌아온 뒤 창이 3pt 안에서 멈췄으면 누른 것」은 언제나 참(0pt)이었다: 잡기만 해도 누른 것 → 서랍이 펼쳐지고, 펼치는 애니메이션의 `setFrame` 이 창 서버의 끌기를 잘랐다(24pt 는 그 사이 두 걸음). 「닫히지 않는다」도 같은 뿌리 — 옮기려고 잡을 때마다 펼쳐진다. 처음 의심한 `mouseDownCanMoveWindow` 는 원인이 아니었다(끄고도 같았다).

둘째, 펼친 판의 손잡이는 머리 줄의 `.background` 에 깔려 있어 「서랍」 글자와 장수 알약이 누르기를 가로챘다 — 글자 아닌 틈에서만 끌렸다.

## 해결 방법

- `WindowDragSurface.Press`(새 구조체): `mouseDown` 에 잡은 자리, `mouseDragged` 가 3pt 문턱을 **처음** 넘는 순간에 한 번만 `performDrag` — 넘기는 이벤트는 **잡은 순간의 것**(넘어선 dragged 이벤트를 넘기면 창이 그 자리부터 따라와 첫 걸음이 빠진다: 120pt 에 108pt). 넘긴 적 없이 `mouseUp` 이 오면 누른 것. 넘긴 뒤의 `mouseUp` 은 기다리지 않는다(창 서버가 끄는 동안 안 올 수 있다). `mouseDownCanMoveWindow` 는 `false` — 언제 끌기가 되는지를 이 뷰가 정한다.
- 펼친 판의 머리 줄 손잡이를 `.overlay` 로 — 글자 위에서도 끌린다. × 는 그 HStack 밖이라 그대로.
- `verify-drawer.sh` 에 `탭클릭=Surface`(탭 한가운데 hitTest 가 끌기 자리에 닿는가) 한 줄 추가.
- **`scripts/verify-drawer-mouse.sh` + `.swift`**(새): 무대 판에서 탭 끌기(Δ120,80 정확)·누르기→펼침·머리 줄 글자 위 끌기(Δ-100,-60)·×→접힘, 앞으로 부른 판에서 머리 줄 끌기·**다른 앱 클릭→접힘**. 전부 ✓.
- `MemoNSTextView.dragPaper` 의 잘못된 주석(「performDrag 가 놓을 때까지 붙잡는다」)을 사실대로 — 거기서는 「누르면 커서, 끌면 창도」가 맞는 동작이라 코드는 그대로.
- DESIGN §16.14.

## 검증

- `./scripts/verify-drawer-mouse.sh` ✓ (위 여섯 항목) · `./scripts/verify-drawer.sh` ✓ (`탭클릭=Surface`) · `./scripts/test.sh` 956 전부 초록 (새 시험 `DrawerTests.pressBecomesDragOnce`).
- 사람 눈: 실제 트랙패드로 탭을 잡아 끌기 · 그냥 누르기 · 펼친 판 「서랍」 글자를 잡아 끌기 · 브라우저 클릭에 접힘. 합성 마우스와 같은 길이지만 손 떨림·트랙패드 관성은 사람만 낸다.

## 메모

- 교훈: `performDrag` 뒤의 «창이 움직였나» 는 언제나 거짓 — 그 셈에 기대는 코드는 이 저장소에 더 없다(`PaperGrip` 은 셈이 없고, 텍스트 뷰는 커서만 세운다).
- 합성 마우스 검증은 이 셸(터미널)의 손쉬운 사용 권한에 기댄다. CI 에는 못 올린다.
- 창을 앞으로 세우는 두 통로(`LAZYMEMO_STAGE`·`LAZYMEMO_DRAWER=summon`)는 검증 전용 — 무대 판에서는 `appDidResignActive` 가 접지 않으므로(무대 규칙) «접힘» 은 summon 판에서 본다.