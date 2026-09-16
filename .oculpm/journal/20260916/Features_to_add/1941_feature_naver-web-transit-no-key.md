---
schema_version: 1
type: feature
slug: "naver-web-transit-no-key"
status: done
difficulty: medium
created_at: "2026-09-16T19:41:39+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoPlaces/NaverWebRouter.swift"
    op: create
  - path: "Sources/LazyMemoPlaces/TransitRouter.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/RouteCard.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/TransitRoute.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/RouteNote.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemo/RouteSettingsView.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/NaverWebRouterTests.swift"
    op: create
  - path: "Tests/LazyMemoPlacesTests/Fixtures/naver-pubtrans.json"
    op: create
  - path: "Tests/LazyMemoPlacesTests/RoutePlannerTests.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "Package.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
tags:
  - "route"
  - "transit"
  - "naver"
  - "places"
  - "no-key"
  - "mcp-tool"
---
[x] 가는 길을 키 없이 — 네이버 지도 웹 길찾기를 기본으로, ODsay 는 예비로

## 추가 기능

사용자: 「ODsay 안 쓰고 하는 방법 없어?」 — 네이버 지도 **웹**이 브라우저에서 부르는 `map.naver.com/p/api/directions/pubtrans` 를 두드려 보니 키 없이 답한다. 가져온 화면의 데이터 그대로다(최적·최소도보 라벨, 버스 번호·종류·색, 정류장 목록, 지하철 노선·방면·빠른하차 문, 요금, 환승 수, 출발·도착 시각, 기후동행). `departureTime` 을 주면 미래도 시간표대로 답한다.

- `NaverWebRouter` — `start=경도,위도,이름&goal=…&crs=EPSG:4326&mode=TIME&departureTime=…`, 브라우저 UA·Referer. `paths[].legs[].steps[]` 의 WALKING/BUS/SUBWAY 를 구간으로(모르는 탈것이 낀 길은 버림). 시각은 오프셋 없는 한국 시간 → `Asia/Seoul` 로 읽는다.
- 도착 시각을 받는 API 가 아니라 **두 단계**: 고를 때는 도착 40분 전 출발로 한 번 묻고, 고른 뒤 `refine` 이 「도착 − 소요 − 3분」 출발로 되잰다. 그 출발로 늦으면(그 시각의 차가 없어서) 늦는 만큼 앞당겨 두 번까지 더 묻고, 약속 전에 닿는 가장 늦은 출발을 고른다. 실측: 18:30 약속 → 「18:08 출발 · 18:27 도착 · 340 간선 18:12 승차」.
- `TransitRoute.Leg.boardAt`(승차 시각) · `TransitRoute.provider`(파일에는 안 적음, 되잴 때만) · 절에 「· 18:17 승차」 · 카드의 줄에도.
- `RouteFinder`: 네이버 → (비면·끊기면) ODsay 키 → 늘 택시(애플). `RoutePlanner.Services.refine` 추가, 적기 전에 되잰다. 문구: 대중교통을 못 쟀으면 「대중교통 길은 지금 못 찾았어요 — 택시 12분 …」.
- 설정 문구를 「예비 길찾기 키 (ODsay)」로 — 없어도 되고, 네이버가 답하지 않을 때만. PRIVACY 표에 네이버 지도 웹 길찾기 추가.

## 동작 흐름

출발지 답 → `RouteFinder.find`(네이버 40분 전 출발 + 애플 택시) → 「경로 14개를 찾았어요 — 버스 16분 · 지하철 17분 · 택시 3분 …」 → 고름 → `refine`(네이버 되재기 1~3회) → 절·카드·`surface`.

## 검증

- `NaverWebRouterTests` 4개 — 실제 응답(2026-09-16 석촌고분역 → 투파인드피터)을 필요한 필드만 남긴 fixture 로: 구간·시각·요금·승차 시각·방면, 절 왕복, 모르는 탈것·빈 답 거절, 요청 자리 꼴. `RoutePlannerTests` 에 되재기·택시만 문구 추가. 전체 통과(Places 20).
- `LAZYMEMO_LIVE_ROUTES=1` 실접속: 내일 18:30 약속에 버스·지하철·택시 길, 되잰 버스가 18:27 도착.
- 폰 시뮬레이터 실접속 XCUITest: 「버스」를 고르면 절에 버스 번호·「승차」와 `surface` 가 적히고 카드가 선다(스크린샷: 3322 지선 18:17 승차 · 18:27 도착).

## 메모

- **문서화된 API 가 아니다.** 네이버가 모양을 바꾸거나 브라우저 아닌 요청을 막으면 끊긴다 — 그때는 ODsay 예비로, 둘 다 없으면 택시만. 사용자에게 이 위험을 말했다.
- 버스 구간의 `headsign`(「여의도환승센터 방면」)은 시끄러워 적지 않고, 지하철의 것(「내선순환」)만 방면으로.
- 정류장 수는 `stations.count − 1`(타는 곳과 내리는 곳이 다 들어 있다).