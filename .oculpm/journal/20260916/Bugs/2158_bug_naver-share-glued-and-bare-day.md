---
schema_version: 1
type: bug
slug: "naver-share-glued-and-bare-day"
status: done
difficulty: medium
created_at: "2026-09-16T21:58:26+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/PlaceParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/DayParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MapLink.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NoteReaderTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NaturalDateParserTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MapLinkTests.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Chores/2138_chore_drop-odsay-redo-demo-0-6-1.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
tags:
  - "parser"
  - "places"
  - "date"
  - "naver"
  - "route"
  - "mcp-tool"
---
[x] 네이버 지도에서 복사한 글을 못 알아들었고, 「22일」을 날로 읽지 못했다

## 발생 원인

사용자: 「[네이버지도]센트럴시티터미널(호남선)서울 서초구 신반포로 176 센트럴시티https://naver.me/GFsUdKBr — 네이버 지도에서 바로 복사했는데 못 알아먹었어. 월 입력 없이 22일이래도 알아서 해당 월 22일로.」

1. `PlaceParser.share` 는 **딱 2~4줄, 마지막 줄이 링크뿐**일 때만 공유로 봤다. 줄바꿈이 사라져 한 줄로 붙은 것, 앞뒤에 「22일 오후 3시」를 이어 적은 것, 링크 줄 뒤에 말을 붙인 것은 전부 공유가 아니게 되어 자리를 못 읽었다 — 그러면 약속에 자리가 없어 가는 길도 안 묻는다.
2. `DayParser` 에 달 없는 「N일」이 없었다(비서의 `CommandResolver.bareDayOfMonth` 만 있었고 조사가 붙어야 했다).
3. 그 링크가 풀린 곳은 `map.naver.com/?menu=location&lat=…&lng=…&title=…&pinId=…` — `MapLink.naver` 가 `search`·`query` 만 읽어 좌표를 놓쳤다.

## 해결 방법

- `PlaceParser.shareBlock(in:)` — 긴 글 속의 공유 덩어리를 찾는다: 지도 링크가 든 줄을 잡고, 링크 앞에 글이 붙어 있으면(줄바꿈이 사라진 것) `splitGluedNameAndAddress` 로 이름과 주소를 가른다(주소 모양이 시작하는 낱말, 「(호남선)서울」처럼 광역 이름이 앞 낱말 꼬리에 붙은 것까지). 링크 위 세 줄에서 이름표·이름·주소를 찾고, 덩어리 밖의 줄과 링크 뒤의 말을 `rest` 로 준다. `NoteReader` 는 **rest 에서만** 날짜를 읽는다 — 주소의 176 이 날짜가 되면 안 된다.
- `DayParser.bareDayOfMonth` — 맨 뒤 규칙으로 「N일」: 오늘부터 가장 가까운 그 날(오늘 포함), 지난 날은 다음 달, 없는 날은 그다음 달. 「동안·째·차·마다·뒤·후·전·N회」가 뒤에 붙거나 「요일」이면 아니다. NSRegularExpression(뒤돌아보기). 「매달 22일」도 된다.
- `MapLink.naver` 가 `lat`·`lng`(핀) 과 `title`·`name` 을 읽는다.
- `NaturalDateParser.strip` 이 줄마다 빈칸을 하나로 — 덜어낸 자리의 빈칸이 줄 머리에 남던 것.

## 검증

- NoteReader 시험 4가지(한 줄로 붙은 것 · 뒤에 이어 적은 것 · 링크 줄 뒤 · 앞에 적은 것), NaturalDateParser 4가지(가까운 날·없는 날·세는 말 제외·매달), MapLink 1. 전체 Swift 시험 통과(Core 465).
- 실접속: `https://naver.me/GFsUdKBr` → 「센트럴시티터미널(호남선)」 37.5050,127.0032.

## 메모

- 사용자의 채팅에 줄바꿈이 사라져 왔을 뿐 앱에는 줄이 살아 왔을 수도 있다 — 그래서 두 모양 다 받는다.
- 「금주」는 「이번 주」라 「3일째 금주」 같은 시험 문장은 쓸 수 없었다(단식으로).