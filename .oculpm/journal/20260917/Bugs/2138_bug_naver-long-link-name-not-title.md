---
schema_version: 1
type: bug
slug: "naver-long-link-name-not-title"
status: done
difficulty: medium
created_at: "2026-09-17T21:38:54+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoPlaces/PlaceLocator.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/RoutePlannerTests.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoTitleTests.swift"
    op: update
related:
  - ref: "20260916/Bugs/2158_bug_naver-share-glued-and-bare-day.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
tags:
  - "places"
  - "route"
  - "naver"
  - "parser"
  - "title"
  - "mcp-tool"
---
[x] 맥에서 붙인 네이버 지도 주소가 자리 이름이 됐다 — 좌표만 있는 링크는 장소 페이지에서 이름을 가져온다

## 발생 원인

사용자의 폰 화면(2026-09-17): 지도 핀과 길 카드의 요약에 「[map.naver.com/2040338336](https://map.naver.com/p/entry/place/2040338336?lng=127.1025624&lat=37.5125701&…)」가 자리 이름으로 찍혔다. 맥에서 주소를 복사해 붙인 것이라 `LinkLabel.markdown` 이 `[호스트/마지막조각](주소)` 로 적었고, 그 줄이 곧 제목이었다.

1. `MapLink.naver` 는 이 모양의 주소에서 `lat`·`lng` 만 읽는다 — 이름이 없다. 그래서 `NoteReader` 가 파일에 `geo:` 만 적고 `place:` 는 비운다.
2. `RoutePlanner.resolveDestination` 이 **좌표가 있으면 링크를 풀지 않고** `memo.place ?? memo.title` 을 이름으로 삼았다. 이름 없는 좌표 = 제목이 이름. 되물음에 답하면 그 이름으로 길을 적고(`## 가는 길` 요약의 도착지) 파일의 `place:` 에도 그대로 썼다.
3. `Memo.title` 이 링크 마크다운을 걷어내지 않아 제목 자체가 40자 넘는 주소였다.

## 해결 방법

- `PlaceLocator.locate` / `ShortMapLink.resolve` — 링크에 좌표는 있고 이름이 없으면 네이버 장소 번호(`/p/entry/place/<id>`)로 `m.place.naver.com` 의 og:title 을 한 번 더 읽는다(짧은 링크가 이미 가던 길). 긴 주소에 번호가 있으면 HEAD 리다이렉트는 건너뛴다. 좌표는 페이지 것이 없으면 링크 것.
- `RoutePlanner.resolveDestination` — 파일에 이름과 좌표가 **다** 있을 때만 그대로, 아니면 지도 링크를 먼저 푼다. 링크를 못 풀면 `guessedName`(제목에서 링크를 뺀 말, 없으면 좌표)으로 길 요약만 적고 **`place:` 에는 적지 않는다**(`isGuessed`) — 틀린 자리 이름은 없는 것보다 나쁘다. `begin` 이 이름을 새로 알게 된 경우(좌표는 있고 이름만 없던 것)도 파일에 적는다.
- `Memo.title` 이 `[이름](주소)` 를 이름만 남기고, 새 `titleWithoutLinks` 는 링크를 통째로 뺀다(「https://naver.me/… 밥약속」→「밥약속」). 「## 가는 길」 절은 `textLines` 에서 빠진다 — 목록 둘째 줄에 「가는 길」이 서지 않는다.

## 검증

- `RoutePlannerTests` 2건 신규: 좌표만 든 링크가 가짜 서비스의 이름으로 `place:`·요약·길에 서는 것, 링크를 못 풀면 「점심」으로 요약하되 `isGuessed` 라 `place:` 는 안 쓰는 것. `MemoTitleTests` 2건 신규. 전체 Swift 시험 통과(Core 477·UI 344·Places 64 등).
- `LAZYMEMO_LIVE_ROUTES=1` 실접속: 사용자의 그 주소 → 「마루가메 우동 잠실롯데월드몰」 37.51257,127.102562 (`LiveRouteTests.naverLongLinkWithoutName`).

## 메모

- 이미 그렇게 적힌 메모는 `place:` 에 주소가 박혀 있다 — 꼬리의 「장소 떼기」로 지우면 다음 되물음에서 다시 풀린다.
- 길 요약(`describe`)의 첫 조각은 여전히 제목이다 — 「map.naver.com/2040338336 점심 · 9월 17일 (수) 13:56 · 마루가메 우동 …」.