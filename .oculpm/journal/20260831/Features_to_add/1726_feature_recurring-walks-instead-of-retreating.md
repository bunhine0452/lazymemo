---
schema_version: 1
type: feature
slug: "recurring-walks-instead-of-retreating"
status: done
difficulty: medium
created_at: "2026-08-31T17:26:15+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Recurrence.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Tidy.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/InboundDoor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoMCP/MemoTools.swift"
    op: update
  - path: "Sources/LazyMemoMCP/main.swift"
    op: update
  - path: "scripts/verify-mcp.sh"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecurrenceTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/RecurringMemoTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1725_feature_eventkit-read-only-agenda.md"
    kind: "followup"
tags:
  - "recurrence"
  - "tidy"
  - "parser"
  - "mcp"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 되풀이하는 일은 물러나지 않고 다음 회차로 걸어간다

플랜 `{#recurring-vs-tidy}`·`{#recurring-field}`. 분리수거·약·정기결제·주간 보고 — 게으른 사람에게 가장 자주 필요한 것이 지금까지 **적을 수가 없었다.**

## 추가 기능

**규칙은 주기만 말한다.** `every: 매주` 네 낱말(매일·매주·매월·매년)이 전부다. 「언제」는 `due`/`at` 이 들고 있고, 「매주」이면 그 날짜의 요일이 그 요일이다.

규칙이 스스로 «화요일» 을 들고 있게 하지 않은 것이 이 설계의 핵심이다 — 날짜와 규칙이 **서로 다른 말을 하는 날**이 오고, 그때 어느 쪽이 옳은지 정할 방법이 없다. 요일도 일(日)도 이미 날짜 안에 있다.

그 덕에 나머지가 거의 공짜다. `due`/`at` 은 **늘 다음 한 번**을 가리키므로 달력·종이·시계·MCP 어디도 «반복» 을 따로 알 필요가 없다.

## 동작 흐름

**`Tidy` 와의 충돌이 이 항목의 본론이었다.** 「지난 일정은 다음 날이 끝나면 물러난다」(철학 3)를 그대로 두면 분리수거는 **딱 한 번 하고 영영 사라진다.** 풀이:

1. `Tidy.reason` 은 `every` 가 있는 메모에 `nil` 을 돌려준다 — 되풀이하는 일은 지나가지 않는다.
2. 대신 `Tidy.rolled` 가 **다음 회차로 걸어 보낸다.** 물러남의 짝이고 방향만 반대다.
3. `rollRecurring` 은 `tidyFinished` **보다 먼저** 돈다. 순서가 바뀌면 지난 회차가 치워진 뒤에 걸어가고, 그 사이 메뉴를 열면 분리수거가 「치워 둔 N장」에 잠깐 들어가 있다.

**밀린 만큼 한 번에 걸어간다** (`Recurrence.walk`). 한 회차만 옮기면 앱을 세 주 안 켠 사람은 여전히 지난 일정을 보고, 다음 날 또 한 걸음 — 밀린 만큼 날이 걸린다.

**나올 때(`surface`)도 함께 걸어간다.** 안 그러면 「30분 전」이 지난 회차의 30분 전에 그대로 남아 다음 회차에는 종이가 안 나온다.

**날짜만 있는 것은 그 날이 끝나야 걸어간다** — 오늘 것을 오늘 낮에 옮기면 오늘 할 일이 눈앞에서 사라진다 (`pastGrace` 와 같은 셈).

**파서**는 되풀이 낱말을 먼저 떼어 낸다. 그러면 나머지(「화요일 8시」)는 이미 읽을 줄 아는 글이고 요일·시각은 그 나머지가 정한다. 주기만 적고 날짜를 안 적었으면(「매일 물 마시기」) 오늘부터로 친다 — 날짜를 되묻지 않는다(철학 1).

종이의 꼬리는 한 조각으로 붙는다: `9월 1일 화 · 30분 전 · 매주`. 셋 다 같은 시각을 가리키는 말이고, 되풀이는 날짜를 **한정하는 말**이지 별개의 값이 아니다.

## 검증

`./scripts/test.sh` — **519개 통과** (앞 501 → 새 18개: Recurrence 6, 되풀이하는 일 8, 되풀이를 글에서 읽기 4). 그중 두 개가 이 항목의 본론을 못 박는다 — 「같은 메모라도 주기가 없으면 물러나고, 주기가 있으면 물러나지 않는다」와 「대신 다음 회차로 걸어간다」. `./scripts/verify-mcp.sh` — **35항목** 통과, 새로 2개(주기를 낱말로 돌려주는지, 모르는 주기가 `isError` 인지).

## 메모

`Memo.init` 인자가 또 늘어 SwiftPM 증분 링크가 낡은 오브젝트를 물었다. 이번 세션에서 세 번째다 — 테스트 파일을 `touch` 하면 풀린다.