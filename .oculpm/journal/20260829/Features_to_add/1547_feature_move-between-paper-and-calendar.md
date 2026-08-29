---
schema_version: 1
type: feature
slug: "move-between-paper-and-calendar"
status: done
difficulty: high
created_at: "2026-08-29T15:47:30+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarInk.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/HoverSensor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DesktopLandingTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CalendarInkTests.swift"
    op: update
  - path: "scripts/verify-handover.sh"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "calendar"
  - "window"
  - "design-philosophy"
  - "mcp-tool"
  - "ux"
---
[x] 종이와 달력 사이를 오가는 두 동사 — 「달력에 놓기」와 「종이로」

## 추가 기능

§7.2 에서 메모와 일정을 타입이 아니라 **자리**로 나눴는데, 그 갈림길이 메모가 **태어나는 순간에만** 발화하고 있었다. 그 뒤로 날짜를 붙이거나 떼는 길이 앱 어디에도 없었고(날짜를 지우는 함수는 아무도 부르지 않은 채 남아 있었다), 있었더라도 「사람이 정한 것이 이긴다」는 예외에 걸려 한 번 종이가 된 메모는 일정이 되어도 종이로 남았다. **자리를 나눠 놓고 옮길 수 없게 해 둔 셈이다.**

게으른 사람이 실제로 하는 생각 둘 — "이거 언제 할지 정했다", "언제 할지 모르겠다" — 이 통째로 화면 밖에 있었다.

- **달력에 놓기** (종이의 조작 줄, ＋ 가 붙은 달력): 달력이 열려 앞에 서고 그 메모를 **들고** 놓을 날을 기다린다. 칸을 누르면 그 날의 마감이 되고 종이는 물러난다. 날짜를 묻는 상자는 없다 — 달력 위에서 날짜를 가리키는 방법은 이미 하나 있고(끌어다 놓기) 그것과 같은 낱말을 쓴다. 들고 있는 동안 손끝을 따라다니는 조각도 끌 때와 **같은 조각**이다.
- **종이로** (달력 줄의 「미루기」 옆): 날짜를 뗀다. 미루기가 *언제*를 고친다면 이것은 *어디*를 고친다.
- **종이의 날짜가 눌린다**: 그 일정이 달력의 어느 칸에 서 있는지 한 번에 간다.
- 되돌릴 것이 셋이 되었으므로 낱말도 셋이다 (`MoveNote`) — 「8월 31일로 옮겼습니다」·「9월 1일에 놓았습니다」·「종이로 보냈습니다」.

## 동작 흐름

1. 종이를 실제로 옮기는 규칙은 **한 곳**이다 — `NoteWindowManager.handover(was:now:)`. 자리가 바뀌는 그 순간에만 `layout.json` 의 `hidden` 을 다시 쓴다: 날짜를 얻으면 `true`(달력이 맡는다), 떼면 `false`(다시 눈에 밟혀야 한다), 그대로면 건드리지 않는다(사람이 꺼내 둔 일정이 남는다). **처음 본 메모는 바뀐 것이 아니다** — 기동 직후 전부 숨김으로 적으면 꺼내 둔 일정이 껐다 켜는 것만으로 사라진다.
2. 한 곳을 지나므로 **MCP 도 같다.** Claude 가 날짜를 붙이면 그 종이가 물러나고, 지우면 돌아온다.
3. **돌아온 종이는 나왔다는 것을 스스로 말한다** — 바탕화면 레벨 창은 브라우저 뒤에 나므로 그냥 두면 「종이로」를 누른 사람에게 아무 일도 안 일어난 것으로 보인다. 새 메모와 같은 몸짓(`riseBriefly`)을 쓴다.
4. 겨누는 동안 달력은 `rise()` 로 서 있는다. `riseBriefly` 로는 안 된다 — 겨누는 시간은 사람마다 다르고, 정해 둔 시간이 지나면 조준하던 판이 브라우저 뒤로 사라진다. 놓거나 그만두면(`holding` 관찰) 내려앉고, 창을 치우면 손도 비운다.
5. 겨냥 좌표는 `HoverSensor` 에 움직임 보고를 붙여 받는다. SwiftUI 의 hover 는 키 윈도에서만 반응하는데(§7.1) 이 창은 종이의 버튼을 누르고 건너온 참이라 키를 잡고 있지 않다. 이벤트가 계속 오므로 **들고 있는 동안에만** 단다.

## 검증

- `./scripts/test.sh` — 252건 통과 (자리 옮기기 규칙 4건 + 되돌리기 낱말 3건 신규).
- `./scripts/verify-handover.sh` 신규 — 실제 앱을 띄워 놓고 **파일을 밖에서 고쳐**(MCP 와 같은 길) `due:` 를 붙였다 뗀다. 바탕화면 레벨 창이 2 → 1 → 2 로 오가는 것을 확인. `verify-landing.sh`·`verify-notes.sh` 그대로 통과.
- `./scripts/render-ui.sh` — `calendar-placing.png`(놓을 날을 기다리는 달력)·`note-undated.png`(날짜 없는 종이의 조작 줄) 신규. 「미루기」 옆에 선 「종이로」는 `calendar-in-use.png` 에서 확인.