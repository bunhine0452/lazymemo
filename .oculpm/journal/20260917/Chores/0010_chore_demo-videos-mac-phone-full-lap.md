---
schema_version: 1
type: chore
slug: "demo-videos-mac-phone-full-lap"
status: done
difficulty: medium
created_at: "2026-09-17T00:10:08+09:00"
session_id: "mcp-20260917-001008"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Demo/DemoTour.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "scripts/record-demo.sh"
    op: update
  - path: "ios/scripts/record-demo.sh"
    op: update
  - path: "ios/LazyMemoUITests/DemoTests.swift"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "site/media/demo.mp4"
    op: update
  - path: "site/media/phone.mp4"
    op: update
related:
  - ref: "20260916/Chores/2138_chore_drop-odsay-redo-demo-0-6-1.md"
    kind: "followup"
tags:
  - "site"
  - "demo"
  - "route"
  - "mac"
  - "ios"
  - "mcp-tool"
---
[x] 맥·폰 소개 영상을 사람이 쓰듯 다시 찍어 랜딩에 — 가는 길 장면까지 한 바퀴

사용자: 「데모 영상을 실제 사용자처럼 모바일 영상과 mac 영상을 제대로 찍어서 랜딩 페이지에 넣어줘.」

## 한 일

- **맥** `DemoTour.run` 에 가는 길 장면: 「금요일 저녁 6시반 밥약속」을 치고 링크는 붙여 넣은 것처럼 한 번에 → 상자가 「어디서 출발하시나요?」 → 「강남역」 → 「무엇으로 갈까요?」 → `chooseRouteForDemo("지하철")`(진짜 접속) → 달력 → 종이를 무대 한가운데에 세워 지도·길·링크 카드 → 그다음 다시 보기·서랍·종이가 올라오는 원래 장면. 58초. 컨트롤러에 `routeStepForDemo`·`queryForDemo`·`chooseRouteForDemo`.
- **폰** `DemoTests.testTour` 를 한 이야기로: 적기 → 약속+링크 → 되물음 → 지하철 → 카드 → 다시 보기 → 지금 → 알림 켜기 → 출발 배너 → 열림. 77초. 사람이 치는 속도(0.09s/자)와 읽는 멈춤.
- 랜딩 EN·KO 의 「한 바퀴」·「아이폰」 절 문구와 aria-label 을 새 이야기로. `route.*`(가는 길 절)는 그대로.

## 걸린 것

- 맥: `screencapture -V 55` 가 주행(~58초)보다 짧아 **끝이 잘렸다** — 마지막 장면(종이가 올라옴)이 없었다. 80초로. 그리고 `LENGTH = END−START−0.8` 로 두니 앱이 내려간 뒤 **사용자 바탕화면(브라우저·음악 앱)이 마지막 프레임에 찍혔다** — 녹화는 START 1초 전에 시작하고 mp4 는 2.6초부터라 영상이 앱 종료를 0.8초 넘긴다. −2.6 으로 잡고, 이번 것은 손으로 58.0초에서 잘랐다. 접촉 인쇄와 마지막 프레임을 반드시 눈으로.
- 맥: 자리 없는 종이의 첫 자리는 화면 기준이라 길 종이가 무대 오른쪽 밖에 걸쳤다 — 보이기 전에 `layouts.set` 으로 무대 한가운데 300×600.
- 폰: 시험이 끝나면 앱이 내려가 홈 화면이 찍힌다 — `done` 앞에서 자른다(−0.2). GIF 가 5.8MB 라 8fps·300px 로 3.3MB.

## 검증

- 두 영상 모두 접촉 인쇄(ffmpeg tile)로 장면과 처음·끝 프레임 확인 — 잠금 화면·바탕화면 없음. 크기: demo.mp4 0.9MB·gif 2.9MB, phone.mp4 2.1MB·gif 3.3MB(4MB 규칙 안).
- 시뮬레이터는 끝나고 껐다. main 푸시 → pages 배포.