---
schema_version: 1
type: feature
slug: "appointment-transit-route"
status: done
difficulty: high
created_at: "2026-09-16T19:12:40+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/TransitRoute.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/RouteNote.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: update
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/PlaceLocator.swift"
    op: create
  - path: "Sources/LazyMemoPlaces/TransitRouter.swift"
    op: create
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: create
  - path: "Sources/LazyMemoPlaces/RouteCard.swift"
    op: create
  - path: "Sources/LazyMemoReminders/ReminderCenter.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/RouteSettingsView.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/RouteNoteTests.swift"
    op: create
  - path: "Tests/LazyMemoPlacesTests/ODsayRouterTests.swift"
    op: create
  - path: "Tests/LazyMemoPlacesTests/RoutePlannerTests.swift"
    op: create
  - path: "Tests/LazyMemoPlacesTests/LiveRouteTests.swift"
    op: create
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "Package.swift"
    op: update
related:
  - ref: "20260915/Features_to_add/2158_feature_assistant-conversational-schedule.md"
    kind: "followup"
tags:
  - "assistant"
  - "route"
  - "transit"
  - "places"
  - "ux"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] 약속을 적으면 가는 길을 묻는다 — 출발지 되묻기·경로 탐색·경로 카드·출발 알림

## 추가 기능

사용자가 바란 UX: 「https://naver.me/GFB1MHiW 수요일 오후 6시반에 밥약속」 → 비서가 「어디서 출발하시나요?」 → 「석촌고분역」(또는 지도 링크) → 「경로 N개를 찾았어요 — 버스 21분 · 지하철 19분 (환승) · 택시 12분 (약 9,800원). 무엇으로 갈까요?」 → 「버스」 → 메모에 길이 적히고 네이버 지도 길찾기 모양의 카드가 종이에 서며, 당일 출발 10분 전에 알림.

- **Core** `TransitRoute`(길·구간·종류·환승 낱말·탈것 색표) · `RouteNote`(본문 끝 `## 가는 길` 절을 사람이 읽는 마크다운으로 적고 도로 읽는다 — 정본은 마크다운, JSON·frontmatter 아님) · `Settings.asksRoutes`/`transitKey` · `Recall.departureLine`(알림 둘째 줄이 「18:09 출발 — 잠실여고후문에서 3314 버스 · 21분」) · `MarkdownScanner.Span.Kind.route`(절 통째로 한 구간).
- **Places** `PlaceLocator`(이름→MKLocalSearch, 긴 지도 링크→`MapLink`, 짧은 링크→`ShortMapLink`: naver.me 는 폰 UA 로 `m.map.naver.com/appLink.naver?pinId=…` 로 가고 `m.place.naver.com/place/<id>/home` 의 og:title·`"x","y"` 에 이름·좌표가 있다) · `TransitRouter`(프로토콜) + `ODsayRouter`(searchPubTransPathT, 버스 번호·종류·역·환승·요금·출구) + `AppleRouter`(택시 = 자동차 길 + 서울 요금표 어림) + `RouteFinder`(키 있으면 ODsay, 늘 택시) · `RoutePlanner`(@Observable 대화 상태기계 — 맥 상자와 폰 펜이 같은 것을 돈다; 「됐어」면 물러남, 세션 표로 늦은 접속 차단, 적을 때 `surface = 출발 − 10분`) · `RouteCard`(공용 SwiftUI 카드 — 종류·출발, 큰 소요 시간·도착·요금, 시간 비례 구간 띠, 탈것 줄들과 하차, 환승 알림, 지도에서 보기·떼기) · `RouteLinks`(카카오맵 웹 이름 길찾기·네이버/카카오 앱).
- **맥** 빠른 입력 상자: `.compose` 뒤 약속에 자리가 있으면 닫지 않고 되물음을 세운다(`routeBlock`·선택지·자리표), ⌘⏎ 답, esc/닫기 = 됐어; 종이는 편집기에서 절을 감추고(`MarkdownStyler`, 커서가 들어가면 보임) 글 아래 카드를 세우며 창이 자란다(`growForRoute`); 설정 메뉴에 「약속을 적으면 가는 길 묻기」·「대중교통 길찾기 키 (ODsay)…」.
- **폰** 펜이 같은 되물음(`routeBlock`·「지금 여기」= `HereFix`), 편집 화면 머리에 카드, More → 「가는 길」 시트(`RouteSettingsView`). 비서(`ActionExecutor`)가 만든 약속 메모도 같은 되물음.
- 키 없이는 **택시만** 잰다 — 애플 지도는 한국에서 대중교통 길찾기를 못 한다(실측 `MKErrorDomain 4 FAILED_NO_RESULT`, ETA 도). 버스·지하철은 ODsay 무료 키를 설정에 넣어야 하고 문구가 그 길을 말한다. 키 검증은 사용자 키로 실제 호출을 한 번 해 봐야 한다 — 응답 모양은 레퍼런스(v1.8) 기준 fixture 로만 시험했다.

## 동작 흐름

약속 메모 생김(compose/complete/비서) → `RoutePlanner.applies`(앞으로 올 `at` + 자리·좌표·지도 링크) → 「어디서 출발하시나요?」(그동안 도착지 좌표를 미리 풀어 파일에 `place`/`geo` 적음 → 자리 카드가 선다) → 답 → 출발지 좌표 → `RouteFinder` → 「무엇으로 갈까요?」(있는 종류만 선택지) → 답 → `RouteNote.append` + `surface` → 「가는 길을 적었어요 — 버스 21분, 18:09 출발 · 환승 1회 (버스 → 버스) · 출발 10분 전에 알려요」 → 맥은 상자 닫고 달력, 폰은 목록이 그 줄로.

## 검증

- Swift: RouteNote 7 · ODsayRouter/PlaceLocator 6 · RoutePlanner 7(가짜 서비스로 전체 대화·지하철→환승 대체·됐어·묻지 않는 조건·출발지 못 찾음·키 없음·탈것 낱말) — 전체 859 통과. `LAZYMEMO_LIVE_ROUTES=1` 실접속: 두 naver.me 링크가 「투파인드피터 잠실점」·「스타벅스 송파사거리점」과 좌표로, 석촌고분역 → 택시 3분·2.2km.
- 렌더 `build/ui/note-route.png`·`capture-route-origin/mode.png` 로 카드·되물음 눈으로 확인 (사용자가 가져온 네이버 화면과 같은 짜임). 구간 띠는 바닥 폭을 먼저 주고 남은 폭을 시간 비례로 나눠 잘리지 않게.
- 폰 시뮬레이터 XCUITest: `testAppointmentWithMapLinkAsksWhereToLeaveFrom`(접속 없음 — 질문·답하기 단추·됐어) 통과, `testAnsweringTheOriginWritesARouteCard`(TEST_RUNNER_LAZYMEMO_LIVE_ROUTES=1, 실접속 — 링크 풀기·석촌고분역·택시 선택·절+surface 파일·카드) 통과, 스크린샷으로 지도 카드 + 길 카드 확인.

## 메모

- 애플 지도 `MKDirections` 대중교통은 한국에서 `calculateETA` 조차 `FAILED_NO_RESULT`. 자동차는 된다(택시 어림의 바탕).
- naver.me 는 UA 에 따라 다른 곳으로 보낸다(데스크톱 → `map.naver.com/p/entry/place/<id>` JS 껍데기, 폰 → `m.map.naver.com/appLink.naver?pinId=`) — id 만 잡고 `m.place.naver.com/place/<id>/home` 을 읽는 것이 안전. og:title 끝에 U+001C 제어 문자가 붙어 온다.
- 지도가 돌려주는 이름은 로케일을 따라 「Seokchon Gobun Station」이 되기도 한다 — 사람이 친 이름은 그대로 쓰고 좌표만 받는다.
- 맥 편집기에서 절을 감추는 것은 사진 참조와 같은 방식(0.01pt) 이되 절 전체를 한 구간으로 — 줄마다 감추면 커서가 든 줄만 보인다. 감춘 구간 안의 제목·붙임표에는 줄머리 표시를 입히지 않는다.
- 제목이 「https://naver.me/… 밥약속」으로 남는 것은 기존 동작(본문 첫 줄) — 이번 범위 밖.