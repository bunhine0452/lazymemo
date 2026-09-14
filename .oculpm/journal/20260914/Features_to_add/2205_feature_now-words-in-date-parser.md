---
schema_version: 1
type: feature
slug: "now-words-in-date-parser"
status: done
difficulty: low
created_at: "2026-09-14T22:05:20+09:00"
session_id: "20260914-005"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "176355c0-cdd8-46c9-b761-50bec054636d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/TimeWords.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/TimeParser.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NaturalDateParserTests.swift"
    op: update
related: []
tags:
  - "parser"
  - "core"
  - "time-words"
  - "mcp-tool"
---
[x] 「지금」·「당장」·「right now」를 읽는다 — 날이 아니라 이 순간, 시각까지 붙는다

## 추가 기능

- `TimeWords.nowWords` — 지금·당장·지금 당장·지금 바로 · right now·right away·asap·immediately·now · 今すぐ · 现在·马上·立刻. 시각을 따로 적지 않았으면 **지금 이 분**이 `at` 이 된다(「지금 치과 전화」→ 오늘 21:50). 「지금 3시」처럼 시각이 함께 있으면 낱말은 오늘을 뜻하고 그 시각이 약속이다.
- 「지금부터 2시간 뒤」·「지금 30분 뒤」는 `momentFromNow` 의 정규식이 앞말까지 통째로 덜어낸다 — 본문에 「지금부터」가 남지 않는다.
- 한글 낱말 경계를 이 표만은 묻는다(`TimeWords.nowWord(in:)`): 「지금은 바쁨」·「식당장」은 지금이 아니다. `relativeDays` 에는 넣지 않았다 — 거기 넣으면 경계 없는 `first(of:)` 가 「지금은」을 오늘로 읽어 버린다.

## 동작 흐름

`NaturalDateParser.once` — `momentFromNow`(N시간 뒤) → **nowWord** → DayParser 차례. nowWord 가 걸리면 `TimeParser.parse` 로 시각을 묻고, 있으면 오늘의 그 시각, 없으면 `calendar.dateInterval(of: .minute)` 의 시작.

## 검증

NaturalDateParserTests 에 네 시험(이 순간·시각과 함께·지금부터 덜어내기·경계) 추가, 전체 741 통과. 빠른 입력·폰의 펜·공유 확장이 같은 파서를 쓰므로 세 자리 모두 칩이 선다.