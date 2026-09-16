---
schema_version: 1
type: bug
slug: "paper-grip-drag-handle"
status: done
difficulty: low
created_at: "2026-09-16T22:46:23+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/PaperGrip.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PlaceCards.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperGripTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260914/Features_to_add/2205_feature_mac-place-cards.md"
    kind: "followup"
  - ref: "20260828/Bugs/2115_bug_desktop-note-interaction-comfort.md"
    kind: "followup"
tags:
  - "mac"
  - "ux"
  - "window"
  - "place-cards"
  - "drag"
  - "mcp-tool"
---
[x] 종이 머리의 색띠를 손잡이로 — 자리 카드가 선 종이를 잡을 곳이 없었다

사용자 요청: 종이 머리의 색띠(`---`)를 더 크게, 그리고 거기를 끌어 종이를 옮길 수 있게.

## 발생 원인

- 본문 끌기는 `MemoNSTextView` 가 창으로 넘기지만(§7.1 둘째 규칙), 자리 카드가 서면 종이 머리는 SwiftUI `ScrollView`(NSScrollView)라 `isMovableByWindowBackground` 가 닿지 않는다. 남는 것은 색띠 둘레 14pt 뿐 — 38×3 색띠는 `allowsHitTesting(false)` 라 손잡이로 읽히지도, 잡히지도 않았다.

## 해결 방법

- `PaperGrip` 신설 — 머리 한 줄(20pt = `Theme.loose`, 본문 위 여백과 같아 글을 밀지 않는다)을 `mouseDownCanMoveWindow = true` 인 NSView 로 깔고, 그 위에 52×4 색띠. 끌기는 AppKit 에 맡긴다 — `performDrag` 를 직접 부르지 않는 이유는 우클릭: 배경 끌기는 왼쪽 버튼에만 걸리고 오른쪽 버튼은 응답자 사슬을 타고 올라 종이 메뉴가 그대로 열린다. `acceptsFirstMouse` 도 연다.
- `NoteView` — 바깥 overlay 였던 색띠를 지우고, 내용 VStack 에 `.overlay(alignment: .top)` 로 얹는다. **조작(×)보다 아래**라 오른쪽 위 모서리에서는 치우기가 이긴다 (SwiftUI 요소가 representable 위에서 클릭을 먼저 받는 것은 아래 캡슐이 텍스트 뷰 위에서 이미 쓰는 성질).
- `PlaceCardsView` — 카드의 위 여백 14 → `PaperGrip.height`. 손잡이 줄과 카드가 겹치지 않는다.
- `PreviewRenderer` — `ImageRenderer` 는 `.task` 를 돌리지 않아 note.png 에 자리 카드가 한 번도 서지 않았다. 표본의 자리를 직접 `load` 한다(좌표가 있어 지도에 묻지 않음).
- `docs/DESIGN.md` §7.1 표에 여섯째 규칙 「머리의 색띠는 손잡이다」.

## 검증

- `swift build` 무경고 · `./scripts/test.sh --filter LazyMemoUITests` 324 통과 + 새 `PaperGripTests` 2건(머리 줄 hit-test 가 `mouseDownCanMoveWindow == true` 인 뷰를 맞히고 그 아래는 `MemoNSTextView`; 첫 클릭 허용).
- `render-ui.sh` note.png: 52×4 색띠 아래 20pt 에 카드가 앉고 ×는 모서리에 그대로.
- **실제 끌기는 사람 눈 확인 필요** — CGEvent 로 끌어 보려 했으나 화면이 Chrome/Ocul-PM 으로 전부 덮여 있어 진짜 이벤트는 남의 창에 가고, `postToPid` 는 AppKit 의 창 끌기 루프에 닿지 않았다. 확인할 것: 카드 있는 종이의 색띠 줄 끌기, 그 줄 우클릭 메뉴, 다른 앱에서 바로 잡기.

## 메모

- 머리 줄이 본문 위 여백(20pt)을 덮으므로 편집 중 그 여백을 눌러 첫 줄에 커서를 세우던 동작은 사라진다 — 글자 위를 누르면 되고, 그 자리를 잡으려는 손이 더 많다.