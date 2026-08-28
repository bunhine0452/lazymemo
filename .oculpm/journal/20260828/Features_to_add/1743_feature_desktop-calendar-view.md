---
schema_version: 1
type: feature
slug: "desktop-calendar-view"
status: done
difficulty: medium
created_at: "2026-08-28T17:43:17+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MonthGrid.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/LayoutStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MonthGridTests.swift"
    op: create
  - path: "scripts/verify-notes.sh"
    op: update
related: []
tags:
  - "calendar"
  - "month-grid"
  - "swiftui"
  - "sqlite-range-query"
  - "layout-json"
  - "mcp-tool"
---
[x] 바탕화면 캘린더 — 달력 격자를 AppKit 밖 순수 값으로

플래너 `{#calendar}` 의 `{#calendar-view}` `{#calendar-query}` 를 끝냈다. `{#eventkit-readonly}` 는 D5 대로 후순위로 남긴다.

## 추가 기능

`MonthGrid`(Core, 순수 값) · `CalendarModel` · `CalendarView` · `CalendarWindowController`.

메뉴바에 "캘린더" 토글을 붙였다. 창은 메모 창과 같은 `DesktopLevelWindow` 를 쓰므로 레벨·Space 동작이 자동으로 같다.

## 동작 흐름

메뉴바 → 캘린더 → 좌상단에 300×300 창 (메모는 우상단부터 쌓이므로 서로 비켜간다). 날짜 칸에는 그 날 메모의 색 점이 최대 3개, 날짜를 누르면 아래에 목록이 펼쳐지고, 항목을 누르면 그 메모 창이 열린다. ◀▶ 로 달을 옮기고, 이번 달이 아닐 때만 "오늘" 버튼이 나타난다.

## 설계 결정

**달력 격자를 `LazyMemoCore` 의 순수 값 타입으로 뺐다.** 주 시작 요일, 앞뒤 달 넘침, 2월, 윤년 — 틀리기 쉬운데 눈으로는 잘 안 보이는 계산이다. `MonthGrid` 를 AppKit 밖에 두어 테스트 8개로 못 박았다 (2026년 8월이 토요일 시작인지, 12월 다음이 다음 해 1월인지, 2028년 2월이 29일인지).

**격자가 덮는 전체 범위로 조회한다.** 이번 달 범위만 물으면 앞뒤 달에서 넘어온 칸의 일정이 빠져 달력에 구멍이 생긴다. `MonthGrid.range` 가 첫 칸부터 마지막 칸까지를 돌려주고 그대로 `MemoService.scheduled` 에 넘어간다 — 인덱스의 날짜 범위 쿼리가 이 경로다 (`{#calendar-query}`).

**캘린더 창 좌표도 `layout.json` 에 둔다.** 다만 키가 ULID 가 아니라 `calendar` 라, `prune(keeping:)` 이 ULID 형식이 아닌 키를 남기도록 고쳤다. 안 그러면 메모 목록 정리 때마다 캘린더 좌표가 지워진다.

**메모가 바뀌면 달력도 다시 그린다.** 일정은 별도 타입이 아니라 메모의 필드일 뿐이므로(§10), `withObservationTracking` 으로 `store.memos` 를 좇는다.

## 검증

- 테스트 76개 통과 (`MonthGrid` 8개 추가).
- `./scripts/verify-notes.sh` — 메모 2장 + 캘린더까지 바탕화면 레벨 창 **3개**가 뜨는 것을 확인. 캘린더는 `(40, 73) 300×300`, 메모는 우상단 계단 배치로 겹치지 않는다.
- **육안 확인 대기** — 날짜 점·오늘 표시·선택 강조의 실제 모습.