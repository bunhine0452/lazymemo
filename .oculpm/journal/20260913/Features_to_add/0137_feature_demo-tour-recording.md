---
schema_version: 1
type: feature
slug: "demo-tour-recording"
status: done
difficulty: medium
created_at: "2026-09-13T01:37:57+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Demo/DemoTour.swift"
    op: create
  - path: "scripts/record-demo.sh"
    op: create
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "site/media/demo.mp4"
    op: create
  - path: "site/media/demo.gif"
    op: create
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "site/img/drawer.png"
    op: create
related:
  - ref: "20260913/Features_to_add/0039_feature_drawer-folders-list-redesign.md"
    kind: "followup"
tags:
  - "demo"
  - "video"
  - "site"
  - "release"
  - "mcp-tool"
---
[x] 소개 영상 — 앱이 스스로 한 바퀴 도는 주행 모드와 화면 기록 스크립트

## 추가 기능

사용자가 「깃허브에 동작 동영상」과 「랜딩페이지 디자인 업그레이드」를 요청.

- `DemoTour` (`LAZYMEMO_DEMO=x,y,w,h`): 임시 Vault 에 표본 메모·폴더·좌표를 심고, 화면의 한 구역(무대)에 바탕을 깔고, 빠른 입력에 한 자씩 치고 → 확정(달력이 받음) → 종이 한 장 적기 → 서랍에 날려 넣기 → 서랍 펼치기 → 폴더 하나 보기·줄 펼치기 → 두 장 골라 옮기기 → 새 폴더 → 도로 꺼내기. 포인터가 필요한 손짓은 흉내 내지 않는다. 포인터는 화면 구석으로 치운다.
- `scripts/record-demo.sh`: 무대 구역만 `screencapture -V -R` 로 담고 ffmpeg 로 mp4(1280, h264)·gif(880, 12fps)·포스터를 만든다. 결과는 `site/media/`.
- 소개 페이지(ko·en)를 크림·포레스트로 다시 그렸다: 판 배지, 영상 히어로(`<video>` + gif 대체), 4단계 설명, 설치 카드, 「서랍과 폴더」 절, 새 렌더 스크린샷(`site/img/`). 외부 요청은 여전히 없다 (pages 워크플로 검사 로컬 통과).

## 동작 흐름

무대의 창은 다른 앱 창과 위젯 위에 서야 찍힌다 → `DesktopLevelWindow.stageLevel` 로 눕는 자리를 `normal+2`, 바탕은 `normal+1` 로 올린다. **`.floating` 은 3 이라 거기서 넷을 빼면 일반 창 아래로 떨어진다** — 첫 녹화에 터미널이 그대로 찍혔다. 서랍 탭 자리는 창 컨트롤러가 생길 때 읽으므로 `placeForDemo(at:)` 로 무대 안에 다시 놓고 보이게 적는다. 폴더 차례도 `adoptFolders` 로 늦게 심는다. 새 종이의 계단 자리는 `NoteWindowManager.stage` 로 무대 안에 가둔다.

## 검증

- `scripts/record-demo.sh` 여섯 번 반복하며 ffmpeg 로 뽑은 접촉 인쇄(8프레임)를 눈으로 확인: 남의 창 없음, 종이·빠른 입력·달력·서랍 탭·펼친 서랍·폴더 칩·펼친 줄·되돌아온 종이 모두 무대 안. 29초, mp4 0.5MB, gif 1.6MB.
- 단위 시험 676개 통과. 사이트 외부 자원 검사(grep) 통과.

## 메모

- 녹화 중 이 앱의 무대 창이 30초 동안 일반 창 위에 뜬다. 다른 앱은 숨기지 않는다.
- 펼친 줄의 높이를 본문 줄 수에 맞췄다 (`DrawerGeometry.expandedExtra(lines:)`) — 영상에서 한 줄짜리 메모 밑이 텅 빈 것이 보였다.