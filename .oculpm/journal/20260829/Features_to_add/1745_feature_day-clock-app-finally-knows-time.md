---
schema_version: 1
type: feature
slug: "day-clock-app-finally-knows-time"
status: done
difficulty: high
created_at: "2026-08-29T17:45:17+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/DayClock.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/CalendarDate.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/AttachmentStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NextMidnightTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/AttachmentSweepTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/DayClockTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CalendarDayChangeTests.swift"
    op: create
related: []
tags:
  - "day-clock"
  - "calendar"
  - "memo-age"
  - "trash"
  - "attachments"
  - "mcp-tool"
---
[x] 앱에 시계를 달았다 — 자정이 지나도 오늘이 어제에 머물던 것과, 영영 안 오던 30일

## 추가 기능

`Sources` 전체에 타이머가 **하나도 없었다**(`grep -rn "Timer\|DispatchSource"` → 0건). 바탕화면에 상주하면서 시간에 따라 스스로 하는 일이 없다는 뜻이고, 며칠씩 안 꺼지는 앱에서 그것은 조용한 거짓말 다섯이 된다.

| 무엇 | 어떻게 틀렸나 |
|---|---|
| 달력의 오늘 | `CalendarModel.today` 가 `let` 이라 창을 만든 날에 멈춘다. 손그림 동그라미가 어제 칸에 남고 「오늘」 버튼도 어제로 간다 |
| **「미루기」** | `postponed(notBefore: today)` 가 어제를 기준으로 세어 **오늘로 미룬다.** 달력에서 가장 자주 쓰는 동사가 아무것도 안 하는 버튼이 된다 |
| 메모의 나이 | `MemoAge.of(memo)` 를 뷰에서 부르는데 메모가 안 바뀌면 다시 그려질 이유가 없다. 어제 것이 계속 `fresh` 로 또렷하다 — 철학 3 이 실사용에서 죽어 있었다 |
| 휴지통 30일 | `purgeExpiredTrash` 가 `start()` 에서만 불려 앱을 안 끄면 무한 보존 |
| 고아 첨부 | `AttachmentStore.orphans()` 는 구현만 되고 **아무도 안 불렀다** — §7.3 의 "부를 자리가 없는 기능은 없는 기능이다" 에 그대로 걸린다 |

## 동작 흐름

`DayClock` 하나가 다섯을 전부 맡는다.

- **깨우는 길이 둘이다.** 시스템의 `NSCalendarDayChanged`(잠자기·시각 변경·타임존 변경을 알아서 다룬다)와, 우리가 잰 다음 자정까지의 잠. 어느 한쪽이 안 와도 하루는 넘어간다. 둘 다 와도 해가 없다 — `tick()` 은 **날짜가 실제로 바뀌었을 때만** 일한다.
- 잠은 `Task.sleep` 이라 `ContinuousClock` 을 탄다. 기계가 자는 동안에도 흐르는 시계라 뚜껑을 열면 밀린 자정이 곧바로 온다. 밀린 날마다 알리지 않고 **지금이 며칠인지**를 한 번 알린다 — 받는 쪽은 전부 "지금 오늘이 며칠인가" 만 쓴다.
- 다음 자정은 `CalendarDate.nextMidnight(after:)` 가 센다. **24시간 더하기가 아니다** — 서머타임 지역의 하루는 23시간이거나 25시간이다.

깨면 셋에게 알린다 (`AppDelegate`):

1. `MenuBarController.dayChanged` → `CalendarModel.dayChanged`. 고른 날이 **어제의 오늘**이었으면 함께 넘어가고(창을 열어 둔 채 자정을 넘긴 사람에게 어제가 펼쳐져 있으면 그것부터가 거짓말), 일부러 다른 날을 골라 둔 사람은 건드리지 않는다. 창이 닫혀 있어도 모델에는 알린다 — 모델이 창보다 오래 산다.
2. `NoteWindowManager.dayChanged` → 종이마다 `NoteModel.asOf` 를 새로 찍는다. 뷰는 `MemoAge.of(memo, now: model.asOf)` 를 읽으므로 그때 다시 그려진다.
3. `MemoStore.tidy()` → 휴지통 정리 + 첨부 정리.

**첨부 정리는 틀리면 사진을 잃는다.** 그래서 안전장치가 셋이다.

- 휴지통에 있는 메모의 본문도 참조로 친다 — 안 그러면 지운 메모를 되돌렸을 때 글만 돌아오고 사진이 없다.
- 손댄 지 7일이 안 된 파일은 고아로 치지 않는다. 빠른 입력에 사진을 붙이면 **파일이 먼저 생기고** 본문은 아직 어느 메모에도 없다.
- 지우지 않고 `.trash/attachments/` 로 옮긴다 (D6). 옮길 때 수정 시각을 새로 찍는다 — 안 찍으면 2년 전에 붙인 사진이 치워지자마자 보존 기간이 지난 것으로 읽혀 그 자리에서 지워진다. 하드 삭제는 `purgeTrashed` 한 곳뿐이고 MCP 표면에 그리로 가는 길이 없다.

## 검증

- `./scripts/test.sh` — 295개 통과 (신규 19건).
- `NextMidnightTests` — 뉴욕의 3월 8일은 23시간, 11월 1일은 25시간. 24를 더하면 자정을 지나치거나 한 시간 일찍 깬다는 것을 못 박았다. 하루에 한 번, 그것도 1년에 두 번만 틀리므로 눈으로는 영영 못 잡는 종류다.
- `DayClockTests` — 같은 날 두 번 불러도 조용하고, 자정을 넘기면 두 번 불려도 한 번만 알리고, 나흘 자고 일어나도 지금 날짜로 한 번 알린다.
- `CalendarDayChangeTests` — **미루기가 새 오늘을 기준으로 센다**(8/29 에 재면 8/30, 자정 뒤에 재면 8/31) · 오늘을 보고 있었으면 따라가고 일부러 고른 날은 안 건드린다 · 달을 넘기면 격자도 넘어간다.
- `AttachmentSweepTests` — 오래된 고아만 휴지통으로 가고 · 참조된 것과 휴지통 메모의 사진은 남고 · 갓 붙인 것은 안 건드리고 · 옮긴 뒤 보존 기간이 지나야 사라진다.
- `./scripts/verify-performance.sh` — RSS 90.6~95.7MB / idle CPU 0.0%. 같은 스크립트를 HEAD 워크트리에서도 돌려 90.7~98.2MB 가 나왔다. **범위가 겹치므로 이 변경에서 온 회귀는 없다** — 잠자는 Task 하나와 알림 관찰자 하나가 전부다. 다만 설계문서 §11 의 88.8MB 는 이제 낡은 수치다.

## 메모

`#surface-at-time`(적힌 시각에 종이가 떠오르기)은 아직이다. 그것은 분 단위라 이 시계와 같은 부품이지만 다른 주기이므로 다음 단위로 뺐다. `NoteModel` 의 저장 재시도(3초·3회)도 그때 이 시계에 얹는 것이 맞다.