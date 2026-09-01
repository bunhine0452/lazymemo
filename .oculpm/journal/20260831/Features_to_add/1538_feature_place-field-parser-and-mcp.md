---
schema_version: 1
type: feature
slug: "place-field-parser-and-mcp"
status: done
difficulty: medium
created_at: "2026-08-31T15:38:48+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Coordinate.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/PlaceParser.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoMCP/MemoTools.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/PlaceTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/PlaceParserTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/PlaceServiceTests.swift"
    op: create
  - path: "scripts/verify-mcp.sh"
    op: update
related:
  - ref: "20260831/Chores/1529_chore_plan-v2-surface-and-place.md"
    kind: "followup"
tags:
  - "place"
  - "mcp"
  - "parser"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 장소 축 — place/geo 필드, @낱말·주소 파서, MCP 연결

플랜 `lazymemo-v2-surface-place` 의 `{#place-field}`·`{#place-parser}`·`{#place-mcp}`. 「어디」를 적을 수 있게 됐고, Claude 가 그것을 읽고 쓸 수 있다. 종이 위 잉크(`{#place-ink}`)와 달력 줄(`{#place-in-calendar}`)은 아직 없어 **화면에는 보이지 않는다** — 다음 사이클.

## 추가 기능

**`place:` / `geo:` 프론트매터 두 줄.** `place` 는 사람이 읽는 이름 그대로(`강남역 3번 출구`), `geo` 는 선택이다 — 좌표가 없어도 이름을 지도에 검색어로 넘길 수 있으므로 파일이 사람이 읽는 것으로 남는다. `at` 뒤 `tags` 앞에 적는다: **줄 순서가 곧 우선순위이고, 시간이 먼저다.**

`Memo.isScheduled` 는 장소를 보지 않고 `hasPlace` 를 따로 뒀다. **장소는 자리를 정하지 않는다** — 날짜가 붙으면 종이가 물러나고 달력이 맡지만(§7.2), 장소가 붙어도 종이는 그 자리에 있다. 구조는 여전히 시간 하나다(§14.2).

**`PlaceParser` — 읽는 규칙 둘.**

1. 산문에서는 `@강남역` 만. `@` 앞이 글의 처음이거나 공백일 때만 장소로 본다 — 이 한 줄이 `foo@bar.com` 을 전부 걸러낸다.
2. 주소는 **문자열이 통째로 주소일 때만**(`address`). 한 줄·60자 이하이고 `시/군/구 → 로/길/동/읍/면 → 번지` 가 이 순서로 나와야 한다.

**계획서에서 두 가지를 바꿨다.** ① 산문 속 주소 인식을 뺐다 — 한국어에서 `…로`·`…구` 로 끝나는 낱말은 주소가 아닌 쪽이 훨씬 많아(`집으로 3분`, `인구 조사로 3일`) 오탐이 난다. ② 우편번호 5자리도 뺐다 — 맨 다섯 자리 숫자는 값·개수와 구별되지 않는다. 둘 다 `{#opt-g}`(규칙 기반 자동 묶기)를 보류한 것과 같은 판단이다: 틀린 장소를 붙이는 것은 장소를 안 붙이는 것보다 나쁘다.

**MCP** — `create_memo`/`update_memo` 에 `place`·`geo`, `list_memos` 에 `place` 부분일치 필터("강남에서 할 일 뭐 있어?"). 빈 문자열로 지우는 계약은 날짜와 같다(§9.2). 도구 설명에 "날짜와 달리 메모가 놓이는 자리를 바꾸지 않는다" 를 적어 모델이 착각하지 않게 했다.

## 동작 흐름

`place:` 를 읽을 때 `geo` 가 깨져 있으면 **지우지 않고 `preserved` 로 보낸다.** `Memo.knownKeys` 를 decode 안에서 조건부로 좁혀 처리했다 — 파일이 정본이므로(D4) 이해하지 못한 줄을 아는 척 날리면 안 된다. `due`/`at` 에는 아직 이 관용이 없다(기존 동작 유지).

`MemoIndex` 는 건드리지 않았다. 인덱스는 `MemoIndexEntry`(id·경로·날짜)만 돌려주고 본문·장소는 `MemoService` 가 파일에서 읽으므로 마이그레이션이 필요 없다. 장소로 **색인 검색**을 하려면 그때 컬럼을 더한다.

## 검증

`./scripts/test.sh` — **408개 통과** (기존 383 → 새 25개: Coordinate 4, 메모의 장소 6, PlaceParser 11, MemoService 4). `./scripts/verify-mcp.sh` — 20항목 전부 통과, 장소 관련 5항목을 새로 넣었다(place·geo 왕복, 부분일치 필터, 좌표 오류 isError, 그리고 **날짜 없는 장소 메모가 일정이 되지 않는지**). `swift build` 경고 없음.

## 메모

`Memo.init` 에 인자가 둘 늘어 심볼이 바뀌면서 SwiftPM 증분 빌드가 낡은 오브젝트로 링크에 실패했다. 테스트 파일 하나를 `touch` 해 재컴파일시키면 풀린다 — 코드 문제가 아니다.