---
schema_version: 1
type: feature
slug: "mac-place-cards"
status: done
difficulty: medium
created_at: "2026-09-14T22:05:52+09:00"
session_id: "20260914-005"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "176355c0-cdd8-46c9-b761-50bec054636d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/PlaceResolver.swift"
    op: create
  - path: "ios/LazyMemo/PlaceResolver.swift"
    op: delete
  - path: "ios/LazyMemo/MapApp.swift"
    op: create
  - path: "ios/LazyMemo/PlaceCards.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "Sources/LazyMemoUI/Views/PlaceCards.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoPlaces.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MapLink.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoPlacesTests.swift"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260914/Features_to_add/2144_feature_english-full-localization.md"
    kind: "followup"
tags:
  - "mac"
  - "map"
  - "place-cards"
  - "package"
  - "mcp-tool"
---
[x] 맥의 종이 머리에도 자리 카드 — 폰과 같은 지도, 리졸버는 LazyMemoPlaces 로 공유, 종이가 한 번 자란다

## 추가 기능

- `PlaceCardsView`(맥) — 종이 머리에 만질 수 없는 지도 한 장 + 이름 + 「가는 길」(애플 지도, 대중교통). 여러 자리는 폰처럼 옆으로 넘기고 점이 몇째 장인지 말한다. 카카오맵은 우클릭 메뉴의 웹 주소(`map.kakao.com/link/to/…`) — 맥에는 앱이 없다.
- `LazyMemoPlaces` 타깃 — 폰의 `PlaceResolver`(MKLocalSearch + 실행 중 캐시 + 첫 자리 `geo:` 되쓰기)를 패키지로 올려 맥·폰이 같은 답을 본다. Core 에 두지 않은 이유는 MCP 서버까지 MapKit 을 들지 않게. 폰에는 `MapApp`(UIKit)만 남았고 pbxproj 에 제품 의존을 달았다.
- **종이가 한 번 자란다** (`NoteWindowController.paperWithMap` = 320). 기본 종이 200pt 에 카드(~110pt)가 서면 글이 두 줄만 남는다 — 사진처럼 몫을 줄일 수 없어(작으면 지도가 아니다) 카드가 처음 설 때 윗변은 두고 아래로 늘린다. 그 뒤 줄이는 것은 사람의 몫. 지도 키는 종이 키의 34%(56~120pt).
- `MemoPlaces.of` 고침: 칸이 비고 `geo:` 만 있을 때 좌표 카드를 따로 세우던 것을 본문 첫 자리에 붙인다 — 리졸버가 첫 자리를 적어 두면 다음 열기에 이름 없는 카드가 하나 더 서고 첫 자리는 도로 묻던 것 (폰에도 있던 결함).

## 동작 흐름

`NoteView.task(id: placeList.names)` → `onPlacesAppear`(창이 자란다) → `PlaceResolver.load` → 첫 자리 좌표 `NoteModel.adoptGeo` → 파일 `geo:`. 화면 밖 렌더는 스크롤 뷰·Metal 지도를 못 그려 첫 장만 자리표로 세운다(`rendersStatically`).

## 검증

- 임시 Vault 로 앱을 띄워 「@망원역 에서 보고 @홍대입구역 으로」 메모: layout.json 이 260×320, 12초 안에 파일에 `geo: 37.556005,126.910388` 이 적혔다. 붙여 쓴 「@망원역에서」는 파서가 「망원역에서」로 읽어 못 찾는다 — 기존 규칙, 그대로.
- render-ui 의 note.png(320pt)로 배치 확인. `swift test` 741, iOS `testTwoPlacesMakeTwoCards` 통과, iOS·맥 xcodebuild 성공.

## 메모

- 실제 지도 타일은 화면 밖 렌더에 안 잡힌다 — 눈으로 보려면 앱을 띄워야 한다. 스크린샷은 Chrome 이 바탕화면을 덮고 있어 못 찍었다.
- 자리 카드는 메모를 열 때 이름 하나를 애플 지도에 묻는다(§9.3 의 약속 밖 — 폰과 같은 결정). 설정 스위치는 두지 않았다: 지도가 보이는 것 자체가 「켜져 있다」는 표시다.