---
schema_version: 1
type: feature
slug: "calendar-redesign-operable-month"
status: done
difficulty: high
created_at: "2026-08-29T01:37:36+09:00"
session_id: "mcp-20260829-013736"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Schedule.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/CalendarDate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/MonthGridGeometry.swift"
    op: create
  - path: "Sources/LazyMemoUI/Stream/StreamModel.swift"
    op: delete
  - path: "Sources/LazyMemoUI/Stream/StreamView.swift"
    op: delete
  - path: "Sources/LazyMemoUI/Stream/StreamWindowController.swift"
    op: delete
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/ScheduleTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/MonthGridGeometryTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "calendar"
  - "design"
  - "interaction"
  - "drag-and-drop"
  - "philosophy"
  - "mcp-tool"
---
[x] 캘린더를 「흐름」에서 조작하는 달 격자로 전면 교체 — 집어 옮기고, 한 번 눌러 미룬다

## 추가 기능

「흐름」(오늘부터 아래로 흐르는 목록 + 점 스트립)을 버리고 **조작하는 달력**으로 통째로 다시 지었다.

앞선 판을 버린 이유는 조망이 부족해서가 아니라 **조작이 하나도 없어서**다. 게으른 사람이 달력에 하는 일은 셋인데(미룬다 / 본다 / 넣는다·옮긴다), 「흐름」에서 되는 것은 "본다" 하나뿐이었다. 가장 자주 하는 일(미루기)이 가장 멀리 있었다 — 메모를 열어 날짜를 손으로 고쳐야 했다. 그래서 화면을 고친 것이 아니라 **동사를 기준으로 다시 지었다.**

| 동사 | 조작 |
|---|---|
| 옮기기 | 아래 줄을 집어 위 격자 칸에 놓는다 (날짜를 글자가 아니라 **자리**로 가리킨다) |
| 미루기 | 포인터가 올라온 줄에 겹쳐 뜨는 「미루기」 한 번 |
| 적기 | 날을 고르고 그 자리에서 한 줄 (상자를 따로 띄우지 않는다) |
| 되돌리기 | 옮긴 뒤 바닥에 8초간 남는 줄 |
| 열기 | 줄을 그냥 누른다 |

## 동작 흐름

- 한 창에 두 층 — 위는 달 격자(조망 + **놓는 자리**), 아래는 고른 날의 목록(**집는 자리**). 두 층이 한 창에 있어야 "31일로 옮기기"가 한 동작이 된다.
- **누르기와 끌기가 한 제스처다.** 손이 3pt 넘게 움직였으면 끌기, 아니면 누르기. 목록 위에서 무엇을 하려는지 앱이 먼저 묻지 않는다.
- 밀도는 숫자가 아니라 **메모 색 그대로의 점** 최대 셋. 넷을 넘으면 셋째 점이 막대로 늘어난다 — 세는 대신 "많다"를 말한다.
- 「미루기」는 `+1일`이 아니라 `max(그 일정의 다음 날, 내일)`. 이미 지난 일정을 하루 미루면 여전히 과거라 아무것도 달라지지 않는다.
- 옮기기는 `due`/`at` 을 **통째로** 다시 쓴다 (`Schedule`). 한쪽만 건드리면 한 메모가 달력 두 칸에 서거나 시각이 사라진다. 되돌리기가 한 줄로 끝나는 것도 이 덩어리 덕분 — 옮기기 전 `Schedule` 을 그대로 되쓴다.
- 고른 날에 적은 한 줄은 `QuickSchedule` 이 해석한다. **날짜를 안 적으면 고른 날, 적으면 적은 쪽이 이긴다.**

## 되짚은 결정 두 개

1. **「빈 칸을 보여주는 것은 채우라는 말이다」(철학 1)** — 이 문장으로 달력에서 빈 날을 지웠었다. 격자로 돌아오며 되짚었다. **격자의 빈칸은 빈칸이 아니라 바탕이다** — 15일이 무슨 요일인지는 그 사이 아무것도 없는 칸들이 말해 준다. 채우라고 말하는 것은 "일정 없음" 같은 글자와 칸마다 붙은 ＋ 표시이고, 그런 것은 하나도 두지 않았다.
2. **「월 격자는 조망용이라 게으른 사람에게 쓸모없다」** — 읽는 것에 대해서는 맞았다. 틀린 것은 그 다음이었다. 격자로 돌아온 것은 조망 때문이 아니라 **놓을 자리가 필요해서**다.

## 함정 두 개

- **좌표를 칸마다 묻지 않는다.** 칸마다 `GeometryReader` 를 심으면 뷰가 42개 더 생긴다(§14.8 — 레이어 수가 곧 메모리 예산). 격자는 균일하므로 격자 하나만 재고 나머지는 나눗셈으로 푼다(`MonthGridGeometry`). 그리고 그 산수는 **눈으로 확인할 수 없다** — 한 칸 밀린 것과 맞는 것이 화면에서 똑같아 보이고 다음 날에야 드러난다(§8.1 의 세 번 틀린 이야기와 같은 함정). 뷰 밖 순수 값으로 빼서 테스트로 못 박았다.
- **버튼과 끌기를 한 뷰에 겹치지 않는다.** 「미루기」를 끌기 영역 안에 두면 누르기 하나를 놓고 둘이 다투고, 어느 쪽이 이기는지가 상황마다 달라진다. 끌기 영역을 줄의 왼쪽 덩어리로 한정하고 버튼을 그 밖에 뒀다.

## 검증

- `./scripts/test.sh` — **167개 전부 통과.** 새 스위트 셋: `Schedule`(옮기기·미루기 규칙 7건), `QuickSchedule`(고른 날 해석 4건), `MonthGridGeometry`(칸 좌표·경계·격자 밖 6건).
- `./scripts/render-ui.sh` — `calendar.png`(평상시)와 **`calendar-in-use.png`(조작하는 중)** 두 장을 라이트/다크로 확인. 집어 든 조각·놓을 자리 고리·겹쳐 뜬 「미루기」·되돌리기 줄은 포인터가 있어야만 나타나므로 렌더에서 연출했고, 옮기기는 흉내가 아니라 **실제로 시켜서** 그린다 — 되돌리기 줄의 날짜가 진짜 계산 결과다.
- 렌더로 잡아 고친 것 셋: ① 놓을 자리 고리가 칸 높이에 잘림 → 자리 확장, ② 지난 날이 목표일 때 숫자가 흐린 채라 겨냥이 안 됨 → 목표는 바래지 않게, ③ 적기 줄이 판 바닥에 못 박혀 마지막 일정과 떨어져 보임 → 목록의 마지막 줄로 붙임.