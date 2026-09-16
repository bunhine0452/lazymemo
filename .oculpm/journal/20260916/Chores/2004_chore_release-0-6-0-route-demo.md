---
schema_version: 1
type: chore
slug: "release-0-6-0-route-demo"
status: done
difficulty: medium
created_at: "2026-09-16T20:04:20+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoUITests/DemoTests.swift"
    op: update
  - path: "ios/scripts/record-demo.sh"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "site/media/route.mp4"
    op: create
  - path: "site/media/route.gif"
    op: create
  - path: "site/media/route-poster.jpg"
    op: create
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: update
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NoteReaderTests.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/1941_feature_naver-web-transit-no-key.md"
    kind: "followup"
  - ref: "20260916/Bugs/1947_bug_place-search-gangnam-station.md"
    kind: "followup"
tags:
  - "release"
  - "site"
  - "demo"
  - "route"
  - "mcp-tool"
---
[x] 0.6.0 — 가는 길 판을 내고, 폰 시연 영상을 랜딩에 붙였다

사용자: 「푸쉬하고 배포해줘 랜딩페이지도 시연영상 추가로 찍으면 좋을듯? 이번 기능」.

## 한 일

- **시연 영상** `./ios/scripts/record-demo.sh route` → `DemoTests.testRoute`(진짜 접속). 금요일 저녁 6시반 밥약속 + 링크 → 「어디서 출발하시나요?」 → 「강남역」 → 「경로 6개 — 버스 32분 (환승) · 지하철 14분 · 택시 7분」 → 지하철 → 지도 카드 밑 2호선 카드 → 배너 「18:12 출발 — 강남역에서 2호선 · 14분」. 42초, mp4 1.35MB · gif 3.4MB(4MB 규칙 안). 배너의 제목·본문은 `push` 파일의 둘째·셋째 줄로 스크립트가 보낸다. 알림 켜기는 `ready` 앞에서 미리 해 영상 밖. 접촉 인쇄(ffmpeg tile)로 확인.
- **랜딩** EN·KO 에 `#route` 절(「약속을 적으면, 어디서 출발하는지 묻습니다」) — `.phone.route` 로 글이 왼쪽, 폰이 오른쪽. nav 「가는 길」. 로컬 서버로 렌더 확인.
- **시연에서 잡은 둘**: 「금요일 저녁 6시반 밥약속」 밑에 링크를 붙여 넣으면 `PlaceParser.share` 가 2줄(이름+링크)로 보고 첫 줄을 자리로 삼켜 날짜가 안 읽혔다 → `NoteReader` 에서 첫 줄에 날짜가 있으면 공유가 아니다. 알림의 「강남역역에서」 → 「역」이 이미 있으면 안 붙인다.
- **판**: README 「이번 판 — 0.6.0」(0.5.0 블록은 GitHub 릴리스와 git 에 있으니 뺐다), 「이 기기의 비서」 밑 「약속의 가는 길」 절, 프라이버시 표 한 줄, 「배포」 예시 v0.6.0. Info.plist 0.6.0(6)·Version.swift. 태그 `v0.6.0` 푸시 → release 워크플로. TestFlight 는 `ios/scripts/archive.sh`(아이폰) → `mac` 차례로.

## 검증

- 전체 Swift 시험 통과(Core 459·UI 324·Places 22 …). 시연 주행 자체가 실접속 끝판 검증이다.
- 영상은 접촉 인쇄로 장면 열다섯 장 확인 — 잠금 화면 아님, 카드·배너 장면 있음.

## 메모

- `xcodebuild archive` 산출물(build/ios/*.xcarchive, ~250MB)은 업로드 뒤 지운다 (용량 규칙 4).
- 시연 영상 첫 프레임에 시뮬레이터 키보드의 「자동 완성」 안내 풍선이 잠깐 보인다 — 한 바퀴 영상과 같은 환경이라 두었다.