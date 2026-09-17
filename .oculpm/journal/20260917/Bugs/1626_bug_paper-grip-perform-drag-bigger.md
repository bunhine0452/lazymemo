---
schema_version: 1
type: bug
slug: "paper-grip-perform-drag-bigger"
status: done
difficulty: medium
created_at: "2026-09-17T16:26:26+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/PaperGrip.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperGripTests.swift"
    op: update
related:
  - ref: "20260916/Bugs/2246_bug_paper-grip-drag-handle.md"
    kind: "followup"
tags:
  - "mac"
  - "note"
  - "drag"
  - "grip"
  - "mcp-tool"
---
[x] 종이 머리 손잡이가 안 끌렸다 — 본문과 같은 performDrag 로, 26pt·64×5 로 키움

## 발생 원인

어제 붙인 `PaperGrip`(20260916/Bugs/2246)은 `mouseDownCanMoveWindow` 만 열고 창의 `isMovableByWindowBackground` 에 끌기를 맡겼다. 사용자가 색띠를 잡아도 안 끌린다고 확인. hit-test 는 정상(시험 통과)이라 뷰 계층 문제가 아니라 **호스팅 뷰 안에서 AppKit 의 배경 끌기 판정이 발화하지 않는** 쪽이다. 단독 프로브로 재현을 시도했으나 합성 이벤트로는 배경 끌기 판정 자체가 돌지 않아(평범한 NSView 도 안 움직임) 확정은 못 했다.

## 해결 방법

- `GripView.mouseDown` 에서 `window.performDrag(with:)` — 사용자가 매일 쓰는 **본문 끌기(`MemoNSTextView`)와 같은 메커니즘**이라 둘이 한 물건으로 움직인다. 우클릭은 `rightMouseDown` 이라 응답자 사슬을 그대로 타고 종이 메뉴가 열린다.
- 사용자 요청대로 살짝 키움: 손잡이 줄 20→26pt, 색띠 52×4→64×5. 텍스트 inset 은 20 그대로라 글이 밀리지 않는다 — 23pt 글줄에서 14pt 글자 위에 남는 ~6pt 윗머리까지만 덮는다(`gripStopsAboveFirstLineGlyphs` 가 경계를 잰다). 자리 카드는 `PaperGrip.height` 를 따르므로 6pt 내려앉는다.

## 검증

- `swift build` 무경고. `./scripts/test.sh --filter LazyMemoUITests` — 손잡이 시험 4건(hit-test·첫 클릭·글자 윗선 경계·띠 크기) 통과.
- render 로 note.png·note-plain.png 확인: 띠와 첫 줄(`## 장보기`) 안 겹침, × 는 모서리 그대로.
- 사람 눈 확인 필요: 다른 앱을 쓰다 바로 색띠를 잡아 끌기, 편집 중 끌기, 그 줄 우클릭 메뉴. `## 제목` 첫 줄은 글자가 커서 윗머리 6pt 가 상단에 조금 걸칠 수 있다 — 거슬리면 24pt 로.

## 메모

병렬 fork 세션이 구현하고 부모가 수거했다.