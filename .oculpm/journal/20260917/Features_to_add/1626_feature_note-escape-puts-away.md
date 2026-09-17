---
schema_version: 1
type: feature
slug: "note-escape-puts-away"
status: done
difficulty: medium
created_at: "2026-09-17T16:26:49+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteEscapeTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260917/Bugs/1626_bug_paper-grip-perform-drag-bigger.md"
    kind: "followup"
tags:
  - "mac"
  - "note"
  - "keyboard"
  - "escape"
  - "drawer"
  - "mcp-tool"
---
[x] 종이에서 Esc — ×와 같은 치우기(서랍으로), 조합 중·되돌리기 중은 무시

## 추가 기능

사용자 말 "메모 클릭하고 esc 누르면 닫게". 이 앱의 닫기는 ×와 같은 **치우기 = 서랍으로**다(지우기 아님). 지금까지 Esc 는 첫 응답자만 놓고 앱을 물러나게 했다(`blursOnEscape`).

- `MemoNSTextView.onEscape` 콜백을 새로 두어 `blursOnEscape` 를 쓰는 다른 곳(빠른 입력)의 Esc 는 그대로.
- 조합 중(`hasMarkedText`)이면 아무것도 안 한다 — 입력기 몫. 아니면 첫 응답자 놓고 `onEscape` → `NoteWindowController.escape()` → `onCloseRequest(id)`(×와 같은 길) → `NSApplication.shared.deactivate()` (상주 앱이 활성인 채 남으면 다음 타자가 허공으로 가는 기존 규칙 유지).
- 손잡이만 잡아 창이 키인 상태(텍스트 뷰가 첫 응답자 아님)는 `DesktopLevelWindow.cancelOperation`/`keyDown(53)` 이 같은 `escape()` 로 간다.
- 방금 지운 종이(`isMourning`)는 되돌리는 줄을 지키려 Esc 무시. 색 고르기 팝오버는 자기 창이 키라 우리 손에 안 온다.
- `docs/DESIGN.md` §7.1 에 「Esc 는 종이를 치운다」 행 추가, 여섯째 행의 구현 칸을 사실에 맞게 보정.

## 동작 흐름

`NoteView.onEscape` → `MemoTextArea` → `MemoTextEditor` → `MemoNSTextView.cancelOperation` (본문 길) / `DesktopLevelWindow.onEscape` (창 길) → `NoteWindowController.escape()` → `onCloseRequest` → 창 관리자가 서랍으로 날린다(`flyInto`).

**부수 발견**: 기존 `super.cancelOperation(sender)` 는 NSTextView 가 그 선택자를 **구현하지 않아 unrecognized selector 로 죽는다**(시험에서 실제 crash). 빠른 입력은 delegate 가 Esc 를 먼저 먹어 안 닿았을 뿐. `nextResponder?.tryToPerform` 으로 사슬을 손으로 잇는다.

## 검증

- `swift build` 무경고. `./scripts/test.sh --filter LazyMemoUITests` — 새 시험 4건(본문 Esc→치우기·조합 중 무시·창 두 길 라우팅·컨트롤러가 지우기 아닌 치우기 & mourning 무시) 통과. 같은 실행의 실패 2건은 서랍 갈래가 진행 중이던 `DrawerTests.closedSize`.
- 사람 눈 확인 필요: 타자 중 Esc → 서랍으로 날아가고 키보드가 원래 앱으로 돌아가는지, 한글 조합 중 Esc 가 종이를 안 치우는지, 손잡이만 클릭한 뒤 Esc.

## 메모

- × 클릭 뒤에는 여전히 앱이 활성으로 남는다(기존 그대로) — Esc 만 deactivate. 원하면 `hide` 쪽에서 한 줄.
- 새 `L()` 없음. README 「쓰는 법」에 Esc 한 줄은 수거 뒤 부모가.