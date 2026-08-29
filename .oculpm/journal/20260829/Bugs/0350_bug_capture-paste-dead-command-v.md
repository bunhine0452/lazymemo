---
schema_version: 1
type: bug
slug: "capture-paste-dead-command-v"
status: done
difficulty: high
created_at: "2026-08-29T03:50:41+09:00"
session_id: "20260829-001"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CapturePasteTests.swift"
    op: create
related: []
tags:
  - "paste"
  - "photos"
  - "quick-capture"
  - "appkit"
  - "mcp-tool"
---
[x] 빠른 입력에서만 ⌘V 가 죽던 것 — 키 윈도가 없는 세상

## 발생 원인

빠른 입력에서 사진이 안 붙는다는 것은 붙여넣기 처리의 문제가 아니었다. **⌘V 가 글 상자까지 닿지 못했다.**

앞선 판(`0227_bug_dawn-keyword-photo-paste-paper-opacity`)에서 표준 편집 단축키를 메인 메뉴에 기대지 않고 `MemoNSTextView.performKeyEquivalent` 에서 직접 집도록 고쳤는데, 집은 뒤에 `NSApp.sendAction(_:to:nil:)` 으로 **되던지고 있었다.** 그 함수는 대상을 **키 윈도의 응답 체인**에서 찾는다.

빠른 입력 상자는 `.nonactivatingPanel` 이다. 앱이 활성이 아니면 패널 자신은 키가 되어 글자를 받으면서도 `NSApp.keyWindow` 는 **nil** 이다. 그래서 첫 응답자가 바로 그 텍스트 뷰인데도 대상을 못 찾고 **조용히 아무 일도 일어나지 않았다** — 글자는 쳐지는데 ⌘V 만 죽는 그 증상 그대로. 시험으로 재현해 확인했다: `appActive=false panelKey=false keyWindow=nil firstResponder=MemoNSTextView`, `targetForPaste=nil`, `sendActionResult=false`.

붙여넣기 처리 자체(`imageMarkdown` → `AttachmentStore.save` → 조각 표시)는 멀쩡했다. 직접 호출로 태우면 `![](attachments/…)` 가 들어가고 `model.images` 도 채워졌다.

## 해결 방법

**① 대상을 찾지 않는다. 우리가 한다.** 알아낸 편집 동작을 `perform(_:)` 이 **자기 자신에게 곧바로** 수행한다 (`paste`·`pasteAsPlainText`·`copy`·`cut`·`selectAll`). 되돌리기만 우리 것이 아니므로 `undoManager` 에게 넘긴다. 지금 글을 받고 있는 것이 우리인데 응답 체인을 다시 뒤질 이유가 없다.

**② 경로 글자를 감춘다.** 붙이면 40자짜리 `![](attachments/…)` 가 19pt 로 말풍선을 가득 채웠다 — 성공한 화면이 오히려 고장 난 것처럼 보였다. 빠른 입력은 마크다운 꾸밈을 켜지 않으므로(치는 동안 글자가 움직이면 방해) **사진 참조만** 감추는 길을 새로 냈다 (`MarkdownStyler.hideImageReferences`, `MemoTextArea.hidesImageReferences`). 글자는 지우지 않는다 (D4) — 커서를 그 줄로 옮기면 도로 보이는 것까지 메모 창과 같다. 붙었다는 것은 조각(`PhotoChip`)이 말한다.

**③ 끌어놓기가 받는 형식을 붙여넣기와 맞췄다.** `[.fileURL, .png, .tiff]` 로 못박혀 있어 JPEG·HEIC 를 끌면 안 받았다. `MemoNSTextView.draggedTypes` 하나로 모아 둘이 갈리지 않게 했다.

**④ 붙임판을 갈아 끼울 수 있게 했다** (`MemoNSTextView.pasteboard`). 시험이 사람의 클립보드를 헤집지 않고 ⌘V 전체 경로를 태울 수 있다.

## 검증

- `./scripts/test.sh` — 224 tests / 35 suites 통과. 새 `CapturePasteTests` 4건: **`NSApp.keyWindow == nil` 인 상태를 먼저 못박고**(결함이 살던 세상) ⌘V 이벤트를 실제 패널의 텍스트 뷰에 흘려 사진이 들어가는지, 조각이 뜨는지, 경로가 감춰지고 적던 글은 그대로인지, 끌어놓기 형식이 붙여넣기와 같은지.
- `./scripts/render-ui.sh` — `capture.png` 에 사진 조각이 뜨고 경로 글자는 보이지 않는 것을 눈으로 확인.
- 작업 중 다른 손이 `CalendarView.swift` 를 고치는 동안 빌드가 깨져 있었다. 건드리지 않고 초록이 될 때까지 기다렸다 검증했다.