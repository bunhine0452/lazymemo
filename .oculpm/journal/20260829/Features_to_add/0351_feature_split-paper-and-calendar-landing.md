---
schema_version: 1
type: feature
slug: "split-paper-and-calendar-landing"
status: done
difficulty: medium
created_at: "2026-08-29T03:51:22+09:00"
session_id: "20260829-001"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: correct
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DesktopLandingTests.swift"
    op: create
  - path: "scripts/verify-landing.sh"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "calendar"
  - "quick-capture"
  - "window"
  - "design-philosophy"
  - "mcp-tool"
---
[x] 날짜가 붙은 메모는 종이가 되지 않는다 — 타입 대신 자리를 나눴다

## 발생 원인

달력의 「이 날에 적기」로 일정을 넣을 때마다 바탕화면에 종이가 한 장씩 생겼다. **원인은 달력이 아니라 `NoteWindowManager` 의 기본값**이었다 — `plannedVisibleMemos` 가 `layout.json` 에 숨김 기록이 없는 모든 메모를 창으로 띄웠고, 새 메모에는 기록이 없으므로 무조건 종이가 됐다. 그래서 빠른 입력도, MCP 로 Claude 가 만든 메모도 결과가 같았다. 일정이 쌓이면 창 24개 상한(§7)이 일정으로 채워져 정작 눈에 밟혀야 할 메모가 밀려난다.

## 추가 기능

메모와 일정을 **타입으로 나누지 않는다**(§5.2 의 핵심 단순화). 나눈 것은 **자리**다.

- 날짜 없음 → 바탕화면의 종이 (언제 볼지 안 정해진 것은 눈에 밟혀야 한다)
- 날짜 있음 → 달력 (그 날이 오면 달력이 꺼내 준다 — 철학 2)

사용자가 고를 것은 없다. 치고 있는 글자가 결정한다 — 모드도 버튼 두 개도 두지 않았다.

## 동작 흐름

1. 규칙은 `NoteWindowManager.staysOnDesktop(isScheduled:layout:)` **한 곳**. 태어나는 길이 셋(달력·빠른 입력·MCP)이라 만드는 자리마다 적으면 하나가 반드시 어긋난다. `layout.json` 에 기록이 있으면 사람이 정한 것이므로 그 뜻이 이긴다.
2. 확인은 달력이 대신 한다. 빠른 입력에서 확정한 것이 일정이면 종이 대신 `CalendarWindowController.announce(_:)` 가 그 날을 고르고 `riseBriefly` 로 잠깐 앞으로 나왔다 내려앉는다. 닫혀 있으면 연다 — 받을 달력이 없으면 그 일정은 어디에도 안 보인다.
3. 달력의 **열림 여부도 복원 대상**이 됐다 (`layout.json` 의 `calendar` 키에 `hidden`). 일정이 보이는 자리가 달력뿐인 이상 껐다 켤 때마다 사라지면 안 된다.
4. 어디로 가는지는 누르기 전에 보인다 — 날짜 칩이 「9월 1일 (월) 15:00 · 달력으로」. 달력 아이콘은 낱말로 바꿨다(§10.5 와 같은 이유).
5. 달력에서 적은 줄이 고른 날이 아닌 곳에 떨어지면(`내일 3시`) 그 날로 넘어가 보여준다. 종이가 안 나는 이상 확인할 자리가 거기뿐이다.

곁다리로, 작업 트리에 남아 있던 `CalendarView` 의 미완 리팩토링(`dayPanel` 은 프로퍼티인데 호출부는 `dayPanel(plan)`)이 빌드를 막고 있어 인자를 떼어 컴파일만 통과시켰다.

## 검증

- `./scripts/test.sh` — 224건 통과 (`DesktopLandingTests` 5건 신규).
- `./scripts/verify-landing.sh` 신규 — 날짜 있는 메모 2장 + 없는 1장을 넣고 띄워 바탕화면 레벨 창이 **1개**임을 확인.
- `verify-notes.sh`(3개)·`verify-restore.sh` 그대로 통과. 달력을 켠 채 종료 → 환경변수 없이 재기동에서 달력 창이 되돌아오는 것을 실측.