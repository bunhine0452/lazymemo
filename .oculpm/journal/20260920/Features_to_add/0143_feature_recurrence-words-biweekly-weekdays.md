---
schema_version: 1
type: feature
slug: "recurrence-words-biweekly-weekdays"
status: done
difficulty: medium
created_at: "2026-09-20T01:43:53+09:00"
session_id: "20260920-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Recurrence.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecurrenceTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecurringMemoTests.swift"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "recurrence"
  - "parser"
  - "core"
  - "planner-upgrades-2026-09"
  - "mcp-tool"
---
[x] 되풀이 낱말 「격주」「평일」 — 두 주에 한 번, 월~금 매일. 주말에 적은 「평일」은 월요일부터

## 추가 기능

- `Recurrence` 가 넷에서 여섯으로 — `.weekdays`(파일 낱말 `평일`)·`.biweekly`(`격주`). 둘 다 **요일을 들지 않으므로** 「주기만 말한다」는 설계 원칙 안이다(플래너 `lazymemo-upgrades-2026-09` #recurrence-words 의 조건). 읽는 낱말: 평일·weekdays·every weekday / 격주·2주마다·biweekly·fortnightly·every other week·every two weeks. 영어 표에 `Weekdays`·`Every other week`.
- 「평일」의 걸음은 고르지 않아(금→월) `step(count)` 로 n 걸음을 한 번에 재는 길을 못 탄다 — `walk` 가 하루씩 가며 주말을 건너뛴다(`nextWeekday`). 잘릴 일이 없으니 `clips` 는 false, `explains` 는 true.
- `Recurrence.aligned(_:)` — 「평일 아침 8시 약」을 **토요일에 적으면 첫 회차가 월요일**. `NaturalDateParser` 는 사람이 날을 직접 말하지 않았을 때(`namesDay == false`)만 이것을 부른다 — 「평일 토요일」은 모순이지만 그 사람이 쓴 날을 앱이 고쳐 쓰지는 않는다.
- MCP `create_memo.every` 의 enum 은 `allCases.map(\.label)` 이라 저절로 여섯이 됐다. 맥·폰의 칩은 `.text()` 만 부르므로 손댈 것이 없었다.

## 동작 흐름

1. 「격주 화요일 8시 회의」 → `Recurrence.find` 가 «격주» 를 떼고 나머지 「화요일 8시 회의」가 요일·시각을 정한다. 회차가 지나면 `Tidy.rolled` 가 앵커에서 14일 걸음으로 다음 화요일 8시.
2. 「평일 아침 8시 약」(토요일에) → `once` 가 시각만 읽어 오늘 8시(지났으면 내일) → `namesDay` 가 false 이므로 `aligned` 가 월요일 8시로. 금요일 회차가 지나면 `walk` 가 토·일을 건너 월요일.
3. 긴 낱말이 짧은 낱말을 가리게 검색 순서를 둔다 — «every weekday» 안의 «every week», «biweekly» 안의 «weekly».

## 검증

- `./scripts/test.sh` 전체 초록(1077). 새 시험: `RecurrenceTests` 격주 14일 걸음·평일 금→월·`aligned` 토/일→월·긴 낱말 우선, `RecurringMemoTests` 「격주 화요일 8시」 파싱·「평일 아침 8시 약」 토요일→월요일·날짜 없는 「평일 물 마시기」·사람이 말한 날은 그대로·`Tidy.rolled` 금요일→월요일(anchor 없음).
- 파일 왕복은 기존 `roundTrips` 와 같은 길(`label` ↔ `init`).

## 메모

- 「평일」은 「평일 저녁에 한번 보자」처럼 되풀이가 아닌 뜻으로도 쓰이는 말이다 — 그때는 칩을 끄면 된다(폰 「누르면 되풀이로 읽지 않습니다」, 맥 칩). 사용자가 헛읽음을 겪으면 그때 낱말 앞뒤 조건을 좁힌다.