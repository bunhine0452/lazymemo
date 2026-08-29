---
schema_version: 1
type: feature
slug: "calendar-adaptive-shapes"
status: done
difficulty: medium
created_at: "2026-08-29T03:55:58+09:00"
session_id: "20260829-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Calendar/CalendarLayout.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/PenMarks.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CalendarLayoutTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "calendar"
  - "layout"
  - "design"
  - "mcp-tool"
---
[x] 달력 판형을 둘로 — 세로로 선 창과 가로로 누운 창, 창을 따라 자라는 눈금

## 추가 기능

배치가 하나뿐이라 **창 크기가 장식이었다.** 세로로 늘리면 주 높이가 36pt 에 못 박혀 있어 달은 창 위쪽의 작은 표로 남고 아래만 텅 비었고, 가로로 넓히면 칸만 옆으로 늘어나면서 정작 조작하는 면(그 날의 일)은 창 아래 눌린 띠였다.

- **판형 둘** (`CalendarLayout`): 가로가 세로의 1.15배를 넘고 폭이 430pt 이상이면 `wide` — 왼쪽은 달, 오른쪽은 그 날. 아니면 `tall` — 위는 달, 아래는 그 날. 문턱을 비율과 폭 둘 다로 잡은 것은 정사각형에 가까운 창에서 두 면을 나란히 놓으면 격자는 겨냥이 어려워지고 목록은 제목이 잘려 둘 다 못 쓰게 되기 때문이다.
- **접힌 자리가 방향을 갖는다** (`PaperCrease.Axis`): 가로로 누운 창에서는 세로로 서고, 가리키는 것도 고른 날의 열이 아니라 **행**이 된다.
- **눈금이 창을 따라 자란다**: 주 높이·펜 자국의 지름·숫자 크기, 동그라미의 획 굵기까지. 5주 달과 6주 달은 같은 창에서 격자 높이가 같다(주 수로 나눈다) — 달을 넘길 때 아래 면이 출렁이면 목록이 매달 다른 자리에서 시작한다.
- **가로 판형의 머리**: 오른쪽 면이 제 폭을 가진 하나의 면이 되므로 큰 날짜 + 요일이 그 면의 제목이 된다. 격자에서 눈이 건너와 처음 닿는 것이 "며칠" 이어야 한다.
- **「이번 주」 형광펜 자국**: 게으른 사람이 보는 단위는 하루가 아니라 이번 주인데 주를 말하는 표시가 없었다. 얼룩과 **같은 `Canvas` 한 장**에 그려 레이어는 그대로다.
- 창 최소 높이 340 → 300 (짧고 넓은 창이 제 모양인 판형이 생겼다).

## 동작 흐름

`GeometryReader` 가 창 크기를 주면 → `CalendarLayout.resolve(size:rows:)` 가 판형과 눈금을 정하고 → `standing`/`lying` 이 배치를, 각 칸이 눈금을 받는다. 착지 판정(`MonthGridGeometry`)은 그대로 화면을 재서 하므로 판형이 바뀌어도 끌어다 놓기는 같은 코드다.

**창을 자기 자신으로 재면 안 된다.** 처음엔 `onGeometryChange` 로 뷰 스스로를 쟀는데 돌아오는 것은 창이 아니라 **내용의 크기**다. 격자가 창보다 커지는 순간 그 값이 다시 판형에 들어가 격자가 한 번 더 자랐고, 주 높이 상한(64pt)에 닿아서야 멎었다 — 620×360 창에서 머리가 통째로 잘려 나갔다. 리더는 언제나 제안된 크기를 주므로 고리가 끊긴다. 더해서 자리를 먹는 것들(머리 36 · 요일 줄 15 · 접힌 자리 19)의 높이를 어림이 아니라 화면과 같은 **약속**으로 못 박았다.

## 검증

- `scripts/test.sh` — 235개 통과. 새 `CalendarLayoutTests` 가 창 표본 8개 × 주 수 3개를 훑어 "격자는 창을 넘지 않는다 · 펜 자국은 칸 안에 머문다 · 두 면이 폭을 나눠 갖는다 · 좁은 창은 눕지 않는다" 를 못 박는다.
- `scripts/render-ui.sh` — `calendar-wide.png`(620×360)·`calendar-large.png`(340×620) 을 새로 내고 눈으로 확인. 잘림을 처음 잡아낸 것도 이 렌더였다 (기본 창 그림은 멀쩡했다).
- `layout.json` 에 620×360 을 심고 실제 기동 — 바탕화면 레벨 창이 그 크기로 올라오는 것을 `verify-window.swift` 로 확인.