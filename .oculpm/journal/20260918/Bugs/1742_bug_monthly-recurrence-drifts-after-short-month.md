---
schema_version: 1
type: bug
slug: "monthly-recurrence-drifts-after-short-month"
status: done
difficulty: medium
created_at: "2026-09-18T17:42:03+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Recurrence.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Tidy.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecurrenceTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecurringMemoTests.swift"
    op: update
related:
  - ref: "20260831/Features_to_add/1726_feature_recurring-walks-instead-of-retreating.md"
    kind: "followup"
tags:
  - "recurrence"
  - "tidy"
  - "frontmatter"
  - "bug-hunt"
  - "mcp-tool"
---
[x] 「매월 31일」이 2월을 지나면 영영 28일이 되던 것 — 되풀이의 처음 날(anchor)을 파일에 적고 거기서 잰다

## 발생 원인

`Recurrence.walk` 가 **지금 적힌 날에서 한 걸음씩** 쌓았다. 달 걸음은 짧은 달에서 잘린다 — 1월 31일 + 1달 = 2월 28일(`Calendar` 가 자른다). `Tidy.rolled` 는 매일 돌며 그 잘린 날을 파일에 되쓰고, 다음 달에는 2월 28일에서 한 걸음을 재니 3월 28일. 「매월 31일 월세」·「매월 30일 카드값」이 한 번 2월을 지나면 사흘 앞당겨진 채 영영 돌아오지 않았다. 매년 2월 29일도 같다. 처음 날이 어디에도 안 적혀 있어서, 잘린 뒤에는 28일이 원래 28일인지 잘린 31일인지 알 길이 없었다.

## 해결 방법

- `Memo.anchor: CalendarDate?` — frontmatter `anchor: 2026-01-31`. 걸어간 메모만 적고, 매일·매주(`Recurrence.clips == false`)는 잘릴 일이 없어 안 적는다. 옛 판은 모르는 키라 `preserved` 로 그대로 되쓴다.
- `Recurrence.walk(_:past:anchor:)` — 처음 날에서 **n 걸음**을 한 번에 잰다(`step(count)`). 시각은 지금 것(사람이 시각만 고쳤을 수 있다). 밀린 몇 달도 잘린 날에서 쌓지 않는다: 1월 31일 → 곧장 4월 30일.
- `Recurrence.explains(anchor, day)` — 처음 날이 지금 날을 설명하는가(31일은 2월 28일·4월 30일을 설명, 3월 28일은 아님). `Tidy.rolled` 는 설명 못 하는 anchor 를 버리고 지금 날을 새 처음으로 — 옛 판이 잘린 채 걸어간 파일도 스스로 낫는다.
- `MemoService.update`/`modify` — 사람이 `due`/`at` 을 옮기면 anchor 를 지운다. 안 그러면 1월 31일 메모를 손으로 2월 28일로 옮긴 사람(28일을 뜻한 것)이 3월 31일로 끌려간다.

## 검증

- `RecurrenceTests.monthlyKeepsTheAnchorDay`·`anchorExplainsClippedDays`, `RecurringMemoTests.monthlyReturnsToTheAnchorDay`(2월 28 → 3월 31 → 4월 30, 파일 왕복 포함)·`movedDayBecomesTheNewAnchor`·`weeklyNeedsNoAnchor` 추가 — 고치기 전 로직으로는 3월 28일이 나오는 경우.
- `swift test` 965개 전부 통과.

## 메모

앱 화면·MCP 출력에는 anchor 를 내지 않는다 — 내부 값이다. 사람이 처음 날을 손으로 고칠 일도 없다.