---
schema_version: 1
type: feature
slug: "desktop-drawer-widget"
status: done
difficulty: high
created_at: "2026-08-31T18:34:21+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Drawer/DrawerContents.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerGeometry.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerText.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerPaper.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: create
  - path: "scripts/verify-drawer.sh"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "ui"
  - "drawer"
  - "desktop"
  - "animation"
  - "window"
  - "mcp-tool"
---
[x] 「서랍」 — 밀어 둔 종이가 가는 자리를 바탕화면에 만든다

## 추가 기능

사용자 요청: **바탕화면에 상주하는 폴더 위젯**. 여기에 메모를 넣어 관리하고, 폴더를 누르면 펼쳐지는 모션으로 메모들이 작아진 채 보이고, 한 장을 누르면 원래 크기로 돌아왔다가 다시 누르면 작아지고, 손을 얹으면 잠깐 커진다.

### 폴더인데 분류가 아니다 — 새 데이터를 만들지 않았다

「폴더도 태그도 만들지 않는다」(§14.2)와 부딪히지 않게 자리를 잡았다. **서랍은 분류가 아니라 자리다** — 이름도 없고 여러 개도 없다. 그리고 이 앱에는 종이를 밀어 두는 길이 **이미 둘** 있었다: 종이의 ×(`layout.json` 의 `hidden`)와 스스로 물러나기(`Memo.tidied`). 없던 것은 «밀어 둔 다음에 눈이 갈 곳» 뿐이었고, §14.3 이 스스로 걱정하던 그대로였다 — *"목록에서 빠지기만 하면 사람은 그것을 「없어졌다」로 읽는다."*

그래서 서랍이 든 것은 한 문장으로 끝난다 (`DrawerContents`).

> 서랍에는 **지금 바탕화면에 없는, 날짜 없는 종이**가 들어 있다.

날짜 있는 것은 달력이 맡고(§7.2), 지운 것은 휴지통이 맡는다(D6). **새 frontmatter 필드가 0개다** — 이미 있던 두 값을 읽기만 하므로 저장 형식이 그대로이고, 서랍을 걷어내도 파일에 흔적이 남지 않는다.

### 동작 흐름

| 무엇 | 어떻게 |
|---|---|
| 닫힌 폴더 | 128×108. 탭 사이로 종이 세 장이 삐죽 나오고 앞판에 「N장」 |
| 누르면 | 창 프레임이 자란다. 종이가 한 장씩 22ms 씩 밀려 놓인다 (stagger) |
| 종이를 누르면 | `matchedGeometryEffect` 로 **그 종이가 원래 크기까지 자란다** (뒤는 옅게 덮인다) |
| 한 번 더 / 덮개를 누르면 | 제 칸으로 도로 작아진다 |
| 손을 얹으면 | 1.06배로 들리고 그림자가 깊어진다 (`HoverSensor` — 앱이 비활성이어도 온다) |
| 넣기 | 종이의 ×, 또는 **끌어다 놓기** — 서랍 위에 오면 종이가 반투명해지고, 놓으면 서랍 쪽으로 줄어들며 사라진다 |
| 꺼내기 | 펼친 종이의 「꺼내기」, 또는 바닥 한 줄의 되돌리기 |

**펼치는 것은 뷰 상태가 아니라 창 프레임의 변화다.** SwiftUI 의 움직임과 `NSWindow` 애니메이션이 같은 시간·같은 곡선이어야 한다 (`DrawerView.opening` ↔ `DrawerWindowController.duration`). 움직임을 줄이라고 한 사람에게는(`accessibilityReduceMotion`) 스태거도 스프링도 없다.

**손을 놓았는지는 시간으로 가르지 않는다.** 끌다 멈춘 사람과 놓은 사람을 시간으로 구별하면 반드시 한쪽이 틀리고, 그 값은 «종이가 저 혼자 들어가는 것» 이다. `NSEvent.pressedMouseButtons` 로 실제 떼어짐을 본다. 끌고 있지 않을 때(창이 열리거나 자리가 복원될 때)의 좌표 변화는 아예 보지 않는다.

### 그림으로는 잡히지 않은 고장 하나

처음엔 펼칠 때 **왼쪽 위만** 붙박아 뒀다. 그런데 서랍의 기본 자리가 화면 왼쪽 아래라(메모는 오른쪽 위, 달력은 왼쪽 위 — 셋이 비켜간다) 아래로 자랄 자리가 없었다. 창이 화면 밖으로 내려갔고, 안쪽으로 끌려 들어오면서 **폴더가 있던 자리를 통째로 떠났다.**

렌더는 뷰만 그리지 창을 세우지 않아 이 고장이 그림에 남지 않았다. `verify-drawer.sh` 로 실제 `NSWindow` 를 띄워 닫힘·펼침·되돌아옴 좌표를 찍고 나서야 드러났다 (§14.9). 지금은 자랄 데가 있는 쪽으로 자라고, 어느 쪽이든 **모서리 하나는 그대로 남는다.** 붙박이(`anchor`)를 펼친 창에서 되짚어 셈하지 않고 정본으로 들고, 사람이 창을 옮기면 **옮긴 만큼만** 민다.

### 덤

- 종이가 서랍으로 날아가는 동안의 좌표는 `layout.json` 에 적지 않는다 (`isFlying`) — 적으면 꺼냈을 때 종이가 서랍 자리에 손톱만 하게 돌아온다.
- 종이의 × 도움말을 「치우기 — 서랍에 들어갑니다」로 고쳤다. 넣는 곳과 가는 곳이 화면에서 이어져야 한다.
- 서랍 안은 **읽기만** 한다. 체크상자는 기호로 바꿔 적는다 (`DrawerText`) — 편집기는 그것을 그려 주므로(§15.1) 서랍에서만 `- [x]` 로 보이면 같은 메모가 두 곳에서 다른 물건이 된다 (§14.10).

## 검증

- `./scripts/test.sh` — 560개 통과. 새로 22개: 서랍에 무엇이 드는가(날짜·치움·물러남·지움), 판형(열·줄·창 크기·되돌린 종이가 안을 넘지 않음·비율 유지), 자라는 방향 넷(아래·위·왼쪽·언제나 화면 안), 날아 드는 자리, 체크상자 변환.
- `./scripts/verify-drawer.sh` (새로 만듦) — 실제 창을 세워 `닫힘 40,40 128×108 → 펼침 40,40 288×280 → 되돌아옴 40,40 128×108`, 모서리고정·제자리복귀·계획크기 모두 true.
- `./scripts/render-ui.sh` — `drawer`(닫힘)·`drawer-landing`(종이가 위에 떠 있음)·`drawer-open`(펼침, 한 장에 손 얹힘)·`drawer-zoomed`(한 장이 원래 크기 + 꺼내기/지우기)를 빛·어두움 두 벌로 눈으로 확인.

## 남은 것

`DrawerPaper.plain` 을 SwiftUI `View` 타입의 static 으로 두었더니 시험이 SIGTRAP 으로 죽었다 — 메인 격리 밖에서 부른 것이 원인. 순수 규칙은 뷰 타입에 얹지 말 것 (`DrawerText` 로 옮겨 해결).