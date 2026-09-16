---
schema_version: 1
type: bug
slug: "place-search-gangnam-station"
status: done
difficulty: low
created_at: "2026-09-16T19:47:58+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoPlaces/PlaceLocator.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/ODsayRouterTests.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/1941_feature_naver-web-transit-no-key.md"
    kind: "followup"
tags:
  - "route"
  - "places"
  - "naver"
  - "geocoding"
  - "mcp-tool"
---
[x] 「강남역」이 강남구 한가운데로 잡혔다 — 이름은 네이버 지도 검색이 먼저, 애플은 예비

## 발생 원인

사용자가 「지하철도 되지?」라 묻길래 석촌고분역 → 강남역으로 실접속을 돌렸더니 지하철 길이 「9호선 → 삼성중앙역 + 걷기 6분」이었다. `MKLocalSearch("강남역")` 이 역이 아니라 **강남구의 중심**(37.516, 127.052)을 돌려준 것 — 애플 지도 검색은 한국의 역 이름에 약하다(「석촌고분역」·「잠실새내역」은 역으로 잡는데 「강남역」은 구로).

## 해결 방법

`PlaceLocator.search` 가 네이버 지도 웹의 자동완성 검색(`map.naver.com/p/api/search/instant-search?query=…&coords=위도,경도`)을 먼저 묻는다 — 「강남역 2호선」의 자리(127.0276, 37.4980)를 준다. `place[]` 가 먼저, 없으면 `address[]`(주소도 좌표로). 답이 없거나 끊기면(전체 검색 `allSearch` 는 캡차를 물었다) 애플로 물러난다. 메모에 서는 이름은 그대로 사람이 친 말이다.

## 검증

- `NaverPlaceSearch.parse` 시험 4가지(장소·주소·빈 답·JSON 아님). Places 22개 통과.
- 실접속: 석촌고분역 → 강남역 지하철 길이 「9호선 석촌고분역 → 종합운동장역 · 걷기 7분 · 2호선 종합운동장역 → 강남역 · 환승 1회」, 18:30 약속에 되재어 「18:04 출발 · 18:27 도착」.

## 메모

- `instant-search` 의 `coords` 는 「위도,경도」, 답의 `x`/`y` 는 「경도/위도」— 서로 거꾸로다.
- 「집」처럼 자리가 아닌 말은 네이버도 엉뚱한 가게를 준다 — 그건 사람이 자리 이름을 말해야 할 일.