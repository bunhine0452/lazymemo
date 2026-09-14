---
schema_version: 1
type: feature
slug: "map-share-and-map-url-place-reading"
status: done
difficulty: medium
created_at: "2026-09-13T09:54:46+09:00"
session_id: "20260913-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "d4773124-ec67-485c-809c-895a2c106128"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MapLink.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/PlaceParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/InboxDrop.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/InboundDoor.swift"
    op: update
  - path: "Sources/LazyMemoMCP/main.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MapLinkTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/PlaceParserTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NoteReaderTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/InboxDropTests.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260831/Features_to_add/1538_feature_place-field-parser-and-mcp.md"
    kind: "followup"
tags:
  - "place"
  - "parser"
  - "map"
  - "share-sheet"
  - "inbound"
  - "mcp-tool"
---
[x] 지도 앱의 공유 텍스트와 지도 주소에서 장소·좌표를 읽는다 — 접속 없이

「네이버 지도·카카오맵·구글 지도 링크를 넣으면 장소를 알아서 보여 주나」에서 시작했다. 답은 **반만** 이었다: 링크 카드는 뜨지만 `place:`·`geo:` 는 비었고, 앱이 실제로 쓰는 `LPMetadataProvider` 로 재 보니 지도 서비스 셋 다 카드 제목이 「네이버지도」·「카카오맵」·「Google Maps」였다 (장소 페이지가 JS 렌더라 og 태그에 서비스 이름뿐). iOS 공유 시트가 받는 `이름\n주소\n링크` 세 줄도 `PlaceParser.address` 가 한 줄만 받아 그냥 본문이 됐다.

## 추가 기능

**`PlaceParser.share` — 읽는 규칙 셋째.** 지도 앱의 「공유」가 내놓는 `[이름표]` · 이름 · 주소 · 링크 두~네 줄. 첫 줄이 장소가 되고, 믿는 근거는 둘 중 하나여야 한다 — 주소 줄이 기존 `address` 규칙을 통과하거나, 링크가 지도 서비스의 것(`MapLink.isMap`). `이름\nhttps://youtu.be/…` 는 링크 메모지 장소가 아니다. `[네이버 지도]`(한 줄)·`[카카오맵] 이름`(접두) 이름표만 떼고 본문은 그대로 둔다 — 이름이 곧 제목이고 링크가 있어야 카드가 붙는다. 이름은 글자로 시작해야 한다(`[ ] 우유`·`- 우유` 는 마크다운). 공유 시트가 글과 URL 을 따로 건네 같은 링크가 두 줄이어도 읽는다.

**`MapLink.read` — 지도 주소의 역방향.** 주소 안에 적힌 것만 읽는다: 애플 `?ll=&q=`·`/place?coordinate=&name=`, 구글 `/maps/place/<이름>/@중심` 과 `data=…!3d!4d`(핀이 중심을 이긴다)·`?q=위도,경도`·`/search/`, 카카오 `link/map|to/<이름>,<위도>,<경도>`·`link/search`·풀린 주소의 `?name=`, 네이버 `/p/search/<검색어>`. **네이버 `c=` 는 읽지 않는다** — 핀이 아니라 화면 중심이라 밀었으면 엉뚱한 자리다. 짧은 공유 링크(`naver.me`·`kko.to`·`maps.app.goo.gl`)는 `isMap` 으로 지도인 줄만 알고 읽을 것은 없다 — 풀려면 접속해야 하고 여기는 접속하지 않는다 (§9.3). 카드의 `metadata.url` 을 다시 넣는 3단계는 아직 안 했다.

**`ParsedNote.geo`.** 장소의 출처 넷을 사람이 가까운 순서로 믿는다 — 밖에서 준 것 → `@낱말` → 공유 이름 → 지도 주소의 검색어. 좌표는 지도 주소에서만 나오고, 밖에서 장소를 준 경우엔 읽지 않는다(그 이름과 이 좌표가 다른 곳일 수 있다). `InboxDrop`·`InboundDoor`·CLI `add`·폰 펜(`here?.geo ?? note.geo`)이 `geo` 를 넘긴다.

**`hasAddressShape` 에 「지하」 하나.** 지하철역 주소 `강남대로 지하 396` 이 번지 규칙에 걸렸다. 이 한 낱말만 번지 앞에 끼어들 수 있게 했다 — 오탐 방어(순서 요구)는 그대로다.

## 동작 흐름

폰에서 네이버 지도 → 공유 → 「lazymemo 에 적기」: `SharedInput.text` 가 세 줄을 잇고 → `NoteReader.read` → `share` 가 첫 줄을 `place` 로 → `InboxDrop` 이 `place:` 를 실은 파일을 떨군다 → 맥의 종이에 이름·주소·링크 카드·장소 잉크가 서고, 잉크를 누르면 애플 지도가 그 이름으로 검색한다. 구글 긴 주소면 `geo:` 까지 실려 「가면 떠오르기」에 걸린다. 맥의 `⌥⌘V`·서비스 메뉴·URL 스킴·CLI 도 같은 `NoteReader` 를 지나므로 같다. (맥 빠른 입력 `⌥⌘N` 은 원래 장소를 읽지 않는다 — `@` 가 거르기 기호라서. 손대지 않았다.)

## 검증

`swift test` 720개 통과(새 테스트: MapLink 읽기 12, share 8, NoteReader 4, InboxDrop 파일 왕복 1). `xcodebuild build -scheme LazyMemo-iOS` 시뮬레이터 성공. 빌드한 `lazymemo-mcp add` 를 `LAZYMEMO_VAULT` 스크래치 vault 에 네 번 돌려 파일을 눈으로 확인 — 네이버 4줄은 `place: 스타벅스 강남R점` 에 이름표가 떨어진 본문, 구글 긴 주소는 `place: 강남역` + `geo: 37.4979,127.0276`, 카카오 `지하 396` 은 `place: 강남역 2호선`, 유튜브 두 줄은 장소 없음.

## 메모

- 실제 앱을 띄워 종이의 잉크 자국까지는 보지 않았다 — 잉크 렌더는 이번에 안 건드렸고, 사용자 vault 를 더럽히지 않으려고 CLI 를 스크래치 vault 에만 돌렸다.
- 다음 수: `LinkPreviewStore.fetch` 가 돌려주는 풀린 주소(`metadata.url`)를 `MapLink.read` 에 다시 넣어, 카드가 켜진 사람에겐 짧은 링크도 접속 한 번(이미 하는 그것)으로 이름·좌표가 붙게 하기. 네이버·카카오 장소 페이지(`…/place/<id>`)는 그래도 URL 에 좌표가 없어 페이지를 긁어야 하므로 안 한다.