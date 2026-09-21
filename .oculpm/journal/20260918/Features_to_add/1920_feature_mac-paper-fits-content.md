---
schema_version: 1
type: feature
slug: "mac-paper-fits-content"
status: done
difficulty: high
created_at: "2026-09-18T19:20:28+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/PaperFit.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperFitTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/PaperFitWindowTests.swift"
    op: create
related:
  - ref: "20260914/Features_to_add/2205_feature_mac-place-cards.md"
    kind: "followup"
  - ref: "20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md"
    kind: "followup"
tags:
  - "mac"
  - "window"
  - "paper-fit"
  - "paste"
  - "layout"
  - "mcp-tool"
---
[x] 맥 종이가 글에 맞춰 한 번 자란다 — 붙인 긴 글·다듬은 결과·밖에서 자란 파일, 윗변은 그대로 화면의 70% 까지

사용자: 「정리된 메모 또는 대용량 메모를 붙혀 넣거나, 텍스트가 많다면 메모 크기를 유연하게 조절하여 사용자가 보기 편하게 해야한다.」

기본 종이는 260×200 이다. 여덟 줄이 넘어가는 순간부터 사람은 자기가 방금 붙여 넣은 것을 **못 본다** — 스크롤 막대는 「더 있다」고 말할 뿐 무엇이 있는지는 말하지 않는다.

## 추가 기능

- **`PaperFit`** (Windows/, 128줄) — AppKit 밖의 순수 계산. 창 하나의 형편(지금 프레임·글 높이·글 칸 밖이 먹는 높이·문단 수·괘선 간격·사람이 정한 크기인가)과 화면을 받아 새 프레임을 돌려주거나 `nil`(그대로 두라)을 돌려준다. 규칙:
  - **자라기만 한다.** 글이 짧아졌다고 창이 쪼그라들면 다음에 칠 자리가 사라진다.
  - **윗변 고정** — 아래로 자란다. 사람이 둔 자리는 종이의 머리이지 발이 아니라, 읽던 첫 줄이 제자리에 남는다. 화면 아래로 넘치면 그만큼 통째로 올린다.
  - **천장은 화면의 70%.** 나머지는 스크롤이 맡는다.
  - **폭은 줄이 아주 길 때만** 560pt(편히 읽히는 폭)까지. 「길다」의 기준은 한 문단이 평균 두 줄 이상으로 접히는가(`textHeight/lineHeight ÷ 문단수 ≥ 2`)다 — 목록처럼 한 줄짜리 문단이 늘어선 메모는 넓혀 봐야 읽기 쉬워지지 않는다. 넓히면 접힘이 풀리므로 높이는 폭에 반비례로 되잡고, 어긋난 만큼은 다음 재기가 고친다.
  - **사람이 정한 크기는 96pt 넘칠 때까지 안 건드린다.** 접어 둔 것은 그러라고 접은 것이다. 한 줄 넘쳤다고 펴면 그것은 조작이 아니라 싸움이다 (§7.1).
- **누가 정한 크기인가는 크기로 짐작한다** (`looksAppSized`). `layout.json` 에 열쇠를 새로 넣지 않았다 — 앱이 내놓는 크기는 몇 가지뿐이라(260×200 · 지도 320 · 가는 길 +280) 그 밖의 값은 사람의 손이거나 앱이 이미 글에 맞춰 늘려 둔 것이고, **둘 다 줄이면 안 되는 것**이다. 손으로 잡아 늘린 순간(`windowDidResize`)부터도 사람의 것이 된다.
- **동작 줄이기**를 켰으면 애니메이션 없이 즉시, 아니면 0.18초 ease-out.

## 동작 흐름

`MemoTextEditor.Coordinator.reportHeight`(이미 있던 것, 빠른 입력이 쓰던 것) → `NoteView.onTextHeight`(새 고리) → `NoteWindowController.textHeightChanged` → 디바운스 → `fitToContent`.

- **디바운스가 두 개다.** 한 번에 두 줄 넘게 뛰면 붙여넣기·다듬기 결과이므로 60ms, 그냥 치는 중이면 손이 멈추기를 450ms 기다린다. 키를 누를 때마다 창이 움직이면 글자가 손끝에서 달아난다.
- **재는 것은 콜백이 아니라 창이다** (`measurePaper`). 글 높이는 `layoutManager.usedRect`(TextKit 1 — 이 편집기가 쓰는 것) + 위아래 여백, 글 칸 밖(자리 카드·가는 길·사진·링크·꼬리)의 몫은 **창 높이에서 스크롤 뷰 높이를 뺀 나머지**로 잡는다. SwiftUI 쪽에 자를 대지 않아도 되고, 카드가 몇 장이든 저절로 맞는다.
- 폭이 바뀌면 글이 다시 접히므로 애니메이션 뒤에 **한 번 더 잰다**(`wantsRemeasure`). 자라기만 하고 천장이 있으므로 반드시 멎는다.
- 자란 뒤 `scrollRangeToVisible(selectedRange)` — 붙여 넣은 글 끝이 화면 밖이면 사람은 자기가 무엇을 붙였는지 못 본다.
- 밖에서 들어온 글(다른 기기의 파일·비서가 쓴 결과)도 `updateNSView` 에서 다음 턴에 높이를 알린다.

**함정 하나**: 애니메이션의 마지막 리사이즈 알림은 완료 핸들러 **뒤에** 한 번 더 오기도 한다. 깃발을 그때 내리면 앱이 늘린 것이 「사람이 정한 크기」로 둔갑해 그 종이는 두 번 다시 글에 맞추지 않는다 — 그래서 깃발이 아니라 **시각**(`selfResizeUntil`)으로 둔다. 자리 카드가 늘리는 기존 `grow(toAtLeast:)` 도 같은 보호를 받는다.

## 검증

- `swift test` 전부 초록 (1036건 / LazyMemoUITests 377건). 새 시험 16건: `PaperFitTests`(계산 13 — 안 줄어듦·윗변 고정·화면 밖으로 안 자람·70% 천장·손으로 정한 것 존중·긴 줄에만 폭) · `PaperFitWindowTests`(실제 창 3 — 재는 자리와 거는 자리가 이어져 있는가).
- **실제 앱** (임시 Vault, 화면 1512×949): 붙여 넣은 긴 메모가 260×200 → **560×665**(=949×0.7), 윗변 909 그대로, 오른쪽 화면 안으로 끌려 들어옴. 같은 화면의 짧은 메모는 260×200 그대로.
- **사람이 정한 크기**(layout.json 에 400×500 을 미리 적고 띄움): 조금 넘치는 글에는 400×500 **그대로**. 심하게 넘치는 종이(300×160)는 자란다.
- `scripts/verify-window.sh` ✓ · `scripts/verify-notes.sh` ✓ (종이 셋 다 260×200 그대로, subrole=AXFloatingWindow) · `scripts/verify-capture-paste.sh` ✓.

## 메모

- 천장에 닿으면 스크롤 뷰가 받는다 — `hasVerticalScroller`·`autohidesScrollers` 는 이미 켜져 있었다.
- `layout.json` 규격은 그대로다. 「사람이 정한 크기」를 파일에 적지 않은 것은 뒤로 물릴 수 있게 하기 위해서다 — 짐작이 틀려도 손해는 「조금 덜 자란다」뿐이다.
- 창이 화면 밖에 있으면 `window.screen` 이 `nil` 이라 주 화면으로 떨어진다. 다중 디스플레이에서 종이를 화면 밖에 걸쳐 둔 경우는 손으로 확인하지 못했다.