---
schema_version: 1
type: feature
slug: "ios-place-cards-map-app-handoff"
status: done
difficulty: medium
created_at: "2026-09-14T21:15:40+09:00"
session_id: "20260914-004"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MemoPlaces.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/PlaceParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MapLink.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoPlacesTests.swift"
    op: create
  - path: "ios/LazyMemo/PlaceResolver.swift"
    op: create
  - path: "ios/LazyMemo/PlaceCards.swift"
    op: create
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/Config/Info.plist"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "ios"
  - "place"
  - "map"
  - "privacy"
  - "mcp-tool"
---
[x] 폰의 메모에 자리 카드가 앉는다

## 추가 기능
- 장소가 붙은 메모를 폰에서 열면 종이 머리에 **자리 카드** — 만질 수 없는 작은 지도(핀 하나), 이름, 가는 길을 열 지도 앱 단추(카카오맵·네이버 지도·애플 지도 중 **깔린 것만**).
- 자리가 여럿(`place:` + 본문의 `@낱말`들)이면 카드가 여럿, 옆으로 쓸어 넘긴다. `PlaceParser.parseAll` 과 `MemoPlaces.of` 가 차례를 정한다 — 칸의 자리가 첫 장.
- 이름은 `MKLocalSearch` 로 좌표를 얻고, 첫 자리의 좌표는 파일 `geo:` 에 적어 둔다(다음엔 안 묻는다, 맥·「가면 떠오르기」도 본다).

## 동작 흐름
처음 안은 「지금 자리에서 걸리는 시간과 나설 시각을 카드에 적는다」였고 `MKDirections.calculateETA` + 위치 한 번 재기까지 만들었다. 사용자가 중간에 「사용자가 쓰는 지도 앱이 있으면 그 앱이 최적 경로를 찾게 하면 되지 않나, 우리가 꼭 재야 하나」라고 해서 **뒤집었다** — ETA·위치 읽기를 전부 걷어내고 지도 앱 URL 스킴으로 넘긴다 (`kakaomap://route?ep=…&by=PUBLICTRANSIT`, `nmap://route/public?dlat=…`, `MKMapItem.openInMaps(transit)`). 출발지는 비워 세 앱 다 지금 위치에서 찾는다. `LSApplicationQueriesSchemes` 에 kakaomap·nmap.

두 번 넘어진 자리: (1) 머리의 `LazyHStack` 이 세로를 다 채워 카드가 화면을 먹고 글이 숨었다 → `HStack`. (2) `.task(id: places)` 의 열쇠에 좌표가 들어 있어, 좌표를 파일에 적는 순간 자기 자신을 다시 시작했다 → 열쇠는 이름만.

맥 종이에는 안 들어갔다 — 맥의 설계는 「지도를 그리지 않는다」(DESIGN §14.5)라 별도 결정이 필요하다. 프라이버시 표(README·PRIVACY)에 「장소 이름 하나가 애플 지도로」 두 줄을 더했다.

## 검증
- `swift test` 728/728 (MemoPlaces·parseAll 테스트 추가), iOS 스모크 11/11 — 새 `testTwoPlacesMakeTwoCards` 가 카드 두 장·차례·쓸어 넘기기·종이가 가려지지 않음을 본다.
- 스크린샷으로 편집 화면 확인: 카드 위, 본문 아래, 애플 지도 단추(시뮬레이터엔 카카오·네이버가 없다). 카카오맵·네이버 지도 단추가 실제로 그 앱을 여는지는 **실기기 손검증** 남음.