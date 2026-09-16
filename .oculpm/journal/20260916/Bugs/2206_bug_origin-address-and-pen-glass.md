---
schema_version: 1
type: bug
slug: "origin-address-and-pen-glass"
status: done
difficulty: low
created_at: "2026-09-16T22:06:45+09:00"
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
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/PlaceLocatorTests.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Bugs/2158_bug_naver-share-glued-and-bare-day.md"
    kind: "followup"
  - ref: "20260916/Bugs/1947_bug_place-search-gangnam-station.md"
    kind: "followup"
tags:
  - "route"
  - "places"
  - "ios"
  - "ux"
  - "naver"
  - "mcp-tool"
---
[x] 출발지를 주소로 답하면 못 찾았고, 폰의 되물음이 목록 위에 겹쳐 읽기 어려웠다

## 발생 원인

사용자: 「"어디서 출발하나요?"에 지번주소와 도로명주소도 알아먹게 해줘. 그리고 물어보는 쪽 UI 가 겹쳐서 잘 안 보여.」

1. 네이버 자동완성 검색(`instant-search`)은 **`coords` 가 없으면 오류**로 답한다(실측) — `PlaceLocator.locate` 가 도착지 좌표를 아직 모를 때 `near: nil` 로 부르면 주소든 이름이든 아무것도 못 찾고 애플로 떨어졌고, 애플은 한국 지번에 약하다. 또 답이 있을 때도 장소(`place[]`)를 주소(`address[]`)보다 먼저 믿어 「신반포로 176」에 그 앞 백화점을 줬다.
2. 폰의 `PenBar` 되물음 블록(출발지·탈것·시각·결과 한 줄)이 유리 없이 맨 글로 서서 `safeAreaInset` 뒤의 목록 줄과 겹쳤다.

## 해결 방법

- `NaverPlaceSearch.search` 가 `coords` 를 늘 보낸다 — 가까운 곳을 모르면 서울시청. 질문이 주소로 보이면(`looksLikeAddress`: 동·로·길·가·리 뒤에 숫자, 또는 `N-N` 으로 끝) 주소 답을 먼저 믿는다. 「신천동29」·「세종대로 110」·「백제고분로7길 57」 실접속 확인.
- 되물음 블록 셋을 `glassEffect(.regular, in: RoundedRectangle(18))` 위에 앉혔다 — 펜 줄과 같은 유리. 스크린샷으로 확인.
- 자리표·못 찾았을 때의 문구에 「주소」를 넣었다. 예시 주소는 공개된 곳(롯데월드타워 지번)으로 — 사용자가 「데모에선 다른 주소로」라 해서 처음 넣었던 것을 전부 바꿨다(커밋 전).

## 검증

- PlaceLocatorTests(주소 우선·`looksLikeAddress`), 실접속 `LiveRouteTests/addresses`. 전체 Swift 시험 통과.
- 폰 스모크 `testAppointmentWithMapLinkAsksWhereToLeaveFrom` 통과 + 스크린샷의 유리 카드.

## 메모

- `LazyMemoSpotlightTests` 의 지문 시험이 셋 중 하나꼴로 빨갛다(내 변경과 무관, 997a693 뒤에도) — 릴리스 워크플로가 이것으로 멈추면 `workflow_dispatch` 로 같은 태그를 다시 낸다.