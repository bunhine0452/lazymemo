---
schema_version: 1
type: bug
slug: "calendar-read-click-moved-the-place"
status: done
difficulty: medium
created_at: "2026-08-29T17:53:47+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/SurfacedPlaceTests.swift"
    op: create
related: []
tags:
  - "calendar"
  - "layout"
  - "window"
  - "handover"
  - "mcp-tool"
---
[x] 달력에서 일정을 읽으려고 누르면 그 종이가 영영 바탕화면에 남던 것

## 발생 원인

§7.2 는 "날짜가 붙은 것은 달력이 맡는다" 고 정하고 예외를 하나 두었다 — **사람이 정한 것은 이긴다.** `layout.json` 에 기록이 있으면 그 뜻을 따른다.

문제는 그 기록을 남기는 길이 **하나뿐**이었다는 것이다. 달력의 줄을 누르면 `onSelectMemo` → `NoteWindowManager.reveal` 로 가고, `reveal` 은 언제나 `layouts.setHidden(false, ...)` 를 적었다. 그리고 `handover(was:now:)` 는 `isScheduled` 가 **바뀔 때만** 다시 쓰므로, 한 번 적힌 그 값은 아무도 되돌리지 않는다.

즉 **「본다」가 「꺼내 둔다」로 기록됐다.** 일정 하나를 읽으려고 누른 클릭 한 번이 그 메모를 날짜를 가진 채로 영구히 바탕화면의 종이로 만든다. 화면으로는 구별되지 않고 — 잠깐 꺼내 준 종이와 영영 꺼내 둔 종이가 똑같이 생겼다 — 틀린 것은 다음 날에야 드러난다.

## 해결 방법

`#surface-at-time` 에서 만든 `surfaced` 통로를 그대로 쓴다. 규칙과 무관하게 지금 나와 있어야 할 종이를 들고 있되 `layout.json` 에는 적지 않는 자리다.

- `reveal(_:activating:keepingPlace:)` 에 `keepingPlace` 를 더했다. 켜면 기록 대신 `surfaced` 에 넣는다.
- 달력의 `onSelectMemo` 만 `keepingPlace: true` 로 부른다.
- **메뉴 목록과 빠른 입력은 그대로 기록한다.** 그 두 목록은 찬 점·빈 점으로 "바탕화면에 있음/치워 둠" 을 말하고 있으므로(§14.10), 거기서 줄을 누르는 것은 그 낱말대로 **꺼내는** 일이 맞다. 달력의 줄에는 그런 낱말이 없다 — 거기서 줄은 일정이지 종이가 아니다.

꺼낸 종이는 하루가 끝나면 스스로 물러나고(`clearSurfaced`), 사람이 × 로 치우면 그것으로 끝난다.

## 검증

- `./scripts/test.sh` — 308개 통과 (`SurfacedPlaceTests` 5건 신규).
- 시각이 되어 꺼내 준 것과 달력에서 읽으려고 누른 것은 `layout.json` 에 `hidden == false` 를 적지 않는다 · 메뉴 목록에서 여는 것은 적는다 · 하루가 끝나면 꺼내 준 일정만 물러나고 날짜 없는 종이는 남는다 · × 로 치우면 다음 `sync` 가 도로 띄우지 않는다.
- `./scripts/verify-due-surface.sh` — 실제 앱에서 `layout.json` 의 꺼내 준 일정이 `hidden=true` 로 남는 것까지 확인된다.