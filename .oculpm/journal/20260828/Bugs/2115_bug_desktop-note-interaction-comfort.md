---
schema_version: 1
type: bug
slug: "desktop-note-interaction-comfort"
status: done
difficulty: medium
created_at: "2026-08-28T21:15:28+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
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
  - path: "Sources/LazyMemoUI/Views/FirstMouseHostingView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/HoverSensor.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Stream/StreamView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Stream/StreamWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "ux"
  - "appkit"
  - "window"
  - "focus"
  - "quick-capture"
  - "mcp-tool"
---
[x] 바탕화면 메모의 조작 결함 6건 — 못 옮기고, 안 보이는 창으로 포커스가 가고, 지울 길이 없었다

사용자가 정한 사용성 기준: **"조작에서 불편을 느끼는 순간 끝이다."** 그 기준으로 조작 경로를 전수 점검해 결함 6건을 찾아 고쳤다.

## 발생 원인

전부 **"바탕화면에 상주한다"는 선택이 만든 함정**이고, 보통 앱에서는 나타나지 않아 코드만 봐서는 정상으로 보였다.

1. **메모를 옮길 수 없었다.** `isMovableByWindowBackground = true` 를 켜 두었지만 본문 `NSTextView` 가 창을 거의 다 덮고 있어 배경 끌기가 영영 발화하지 않는다. 끌면 글자만 선택됐다.
2. **첫 클릭이 사라졌다.** `acceptsFirstMouse` 기본값이 false 라, 다른 앱을 쓰다 메모를 누르면 첫 클릭은 앱 활성화에만 쓰였다. 두 번 눌러야 커서가 섰다.
3. **빠른 입력 Return 이 보이지 않는 창으로 포커스를 넘겼다.** `windows.open(memo, activating: true)` 인데 메모 창은 `desktopIconWindow+1` 이라 브라우저 뒤에 있다. 이어서 친 글자가 화면 어디에도 안 보이는 창으로 들어갔다.
4. **검색해서 연 메모도 같은 이유로 안 보였다.** "열기"를 눌러도 화면상 아무 일이 없다.
5. **앱 안에서 메모를 지울 방법이 아예 없었다.** `NoteModel.delete()` 는 호출처가 없는 죽은 코드였고, 메뉴바에는 복원만 있고 삭제가 없었다.
6. **빠른 입력을 닫아도 앱이 활성으로 남았다.** 상주 앱(.accessory)이 상자를 띄우려 스스로 활성화하는데, 숨기기만 하면 보이는 창이 하나도 없는 채로 활성이라 다음 타자가 허공으로 갔다.

여기에 하나 더 — SwiftUI `.onHover` 는 **키 윈도에서만** 반응한다. 바탕화면 메모는 대개 키가 아니므로 철학 3(오래된 것이 바래고 포인터를 올리면 되살아남)과 철학 4(겹쳐 뜨는 조작 버튼)가 실사용에서 통째로 죽어 있었다.

## 해결 방법

가르는 기준을 하나로 통일했다 — **지금 이 메모를 쓰고 있는 중인가.** 쓰는 중이면 글자를 다루고, 아니면 종이를 다룬다. 기존 링크 열기 규칙이 이미 쓰던 기준이라 새로 배울 것이 없다.

- `MemoNSTextView` — `acceptsFirstMouse` 를 연다. 편집 중이 아니면 끌기를 `window.performDrag` 로 넘기고, 편집 중이라도 **글자가 닿지 않는 여백**에서 시작한 끌기는 넘긴다(`isOnBlankPaper`). 끝난 뒤 창이 3pt 미만 움직였으면 클릭으로 보고 원위치시킨 뒤 그 자리에 커서를 세운다 — 여기서 `super.mouseDown` 을 부르면 이미 끝난 마우스 업을 기다리며 멈추므로 커서를 직접 놓는다.
- `DesktopLevelWindow` — 자리를 둘로 나눴다. 평소 `desktopIconWindow+1`, 키를 잡은 동안 `floating-1`. `becomeKey`/`resignKey` 에서 오간다. `floating` 이 아니라 한 칸 아래인 이유는 메모 편집 중 ⌥⌘N 을 눌렀을 때 입력 상자가 가리면 안 되기 때문.
- `riseBriefly()` — 빠른 입력으로 만든 메모는 **포커스를 뺏지 않고** 1.6초 앞으로 나왔다 내려앉는다. 활성화하면 안 보이는 창으로 입력이 가고, 아무것도 안 하면 "적히긴 한 건가"가 남는다.
- `QuickCaptureController.close(returningFocus:)` — 상자를 닫을 때 `NSApp.deactivate()` 로 하던 앱에 키보드를 돌려준다. 검색 결과를 열 때만 예외(사용자가 "그 메모를 보자"고 한 것).
- `MemoNSTextView.cancelOperation` — Esc 로 편집에서 손을 뗀다. 첫 응답자를 놓고 앱을 물러나게 해 종이가 바탕으로 내려앉는다.
- `menu(for:)` — 오른쪽 버튼 메뉴 끝에 「이 메모 지우기」. 조작 줄에 휴지통을 두면 「치우기(×)」와 나란히 서서 잘못 누른다 — 결과는 전혀 다른데 생김새가 닮는다. `subtitle` 로 되돌릴 수 있음을 누르기 **전에** 알린다 (D6).
- `HoverSensor` — `.activeAlways` 추적 영역. 앱이 뒤에 있어도 포인터 반응이 산다. `hitTest` 로 자기를 비워 클릭은 그대로 통과시킨다.
- `FirstMouseHostingView` — 겹쳐 뜨는 조작 버튼과 「흐름」의 화살표도 첫 클릭에 눌린다. SwiftUI 요소의 hit view 는 호스팅 뷰 자신이라 여기서 열면 된다.

## 검증

- `swift build` 무경고 · `./scripts/test.sh` 115개 전부 통과 (IME 조합 회귀 6건 포함).
- `verify-notes.sh` — 바탕화면 레벨 창 3개, 기대 레벨과 일치(평소 자리는 안 바뀜).
- `verify-restore.sh` — 창 4개의 좌표·크기·내용 재기동 복원 통과.
- `measure-capture.sh` — 중앙값 1.4ms (목표 150ms).
- `verify-performance.sh` — RSS 100.2MB 로 예산 100MB **초과**. 다만 stash 후 HEAD 를 같은 방법으로 재면 100.0MB 라 이번 변경 몫은 +0.2MB(오차)이고, 회귀는 앞선 종이/사진 커밋 구간에서 이미 발생해 있었다. 별건으로 남긴다.
- 클릭·끌기·포커스 이동은 기계로 확인할 수 없다(터미널에 화면 기록/손쉬운 사용 권한 없음). `dist/LazyMemo.app` 을 조립해 두었고 사람 눈 확인이 필요하다.

## 메모

`NoteModel.delete()` 가 호출처 없는 죽은 코드였다는 사실이 이 점검의 가장 큰 수확이다 — 타입 검사도 테스트도 잡아 주지 않는 종류의 구멍이라, **동선을 사람 손으로 따라가 보는 점검**이 따로 필요하다는 근거가 된다.

RSS 예산이 이미 천장(100.0MB)에 닿아 있다. 창 24개 상한이 방어선이라던 앞선 판단이 실제로 시험대에 올랐다.