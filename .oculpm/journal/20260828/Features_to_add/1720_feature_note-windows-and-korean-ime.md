---
schema_version: 1
type: feature
slug: "note-windows-and-korean-ime"
status: done
difficulty: high
created_at: "2026-08-28T17:20:57+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/LayoutStore.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoTextSync.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemo/main.swift"
    op: update
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "scripts/verify-notes.sh"
    op: create
  - path: "Tests/LazyMemoUITests/MemoTextSyncTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/LayoutStoreTests.swift"
    op: create
related: []
tags:
  - "nswindow"
  - "swiftui"
  - "nstextview"
  - "korean-ime"
  - "layout-json"
  - "glass-effect"
  - "autosave"
  - "memo-ui"
  - "mcp-tool"
---
[x] 메모 창 UI — 메모당 NSWindow, 좌표 영속화, 한글 IME 조합 회귀 테스트

플래너 `{#memo-ui}` 4개 항목과 `{#undo-ui}` `{#autosave}` `{#multi-display}` 를 함께 끝냈다.

## 추가 기능

`LayoutStore`(창 좌표 정본) · `FrameClamping`(디스플레이 복원 계산) · `NoteWindowManager`(목록 ↔ 창 동기화) · `NoteWindowController` · `NoteView`(SwiftUI) · `NoteModel`(자동 저장) · `MemoTextEditor`(NSTextView) · `MemoTextSync`(IME 보호 규칙).

메뉴바에 메모 목록과 **최근 삭제 되돌리기**(D6) 동선을 붙였다. 하드 삭제 항목은 여기에도 없다.

## 동작 흐름

`MemoStore.memos` 가 바뀌면 `withObservationTracking` 이 `NoteWindowManager.sync()` 를 깨우고, 목록과 창을 맞춘다. 창을 옮기거나 크기를 바꾸면 `NSWindowDelegate` → `LayoutStore`(500ms 디바운스) → `layout.json`. 타자가 멈추면 600ms 뒤 `MemoStore.update` → 파일. 종료 시에는 `applicationShouldTerminate` 에서 `.terminateLater` 를 돌려주고 전 창을 flush 한 뒤 실제로 종료한다 — 저장 버튼이 없으므로 종료가 마지막 저장 지점이다.

## 설계 결정

**"창을 닫는다 = 메모를 숨긴다".** `layout.json` 의 `hidden` 플래그로 기록하고 파일은 그대로 둔다. 삭제(D6, 휴지통)와는 완전히 다른 개념이고, 메뉴에서 다시 열 수 있다. 메뉴 항목에 체크 표시를 달아 "지금 바탕화면에 있는지"가 보이게 했다.

**동시에 띄우는 창을 24개로 제한했다.** "메모는 항상 바탕화면에 있다"는 약속과 성능 예산(§11, 10장에 100MB)이 정면으로 부딪힌다. LLM 이 한 번에 메모 20장을 만드는 경우도 있다. 상한을 넘는 메모는 창을 만들지 않고 메뉴 목록에서 열 수 있게 했다.

**`FrameClamping.clamp` 과 `restore` 를 분리했다.** 처음엔 "손잡이 80pt 만 화면에 남기는" 하나의 규칙으로 짰는데, 테스트가 모니터를 뽑았을 때 창이 화면 밖으로 걸쳐 남는 걸 잡아냈다. 두 상황은 요구가 반대다 — 사용자가 **일부러** 걸쳐 놓은 창은 건드리면 안 되고, 모니터가 사라져 **아무 화면에도 닿지 않는** 창은 완전히 안으로 데려와야 한다. `restore` 가 `isReachable` 로 갈라 준다.

**AppKit 비의존 순수 함수로 뺐다.** 덕분에 `{#multi-display}` 의 "다중 디스플레이 연결·해제 왕복 후 좌표 복원"을 실제 외부 모니터 없이 검증한다.

## 알아낸 것 — 실행 파일 타깃은 테스트에서 import 할 수 없다

`{#ime-check}` 를 자동 테스트로 만들려는데 UI 코드가 전부 `main.swift` 를 가진 executableTarget 안에 있어 `@testable import` 가 안 됐다. `main.swift` 한 줄만 남기고 나머지를 `LazyMemoUI` 라이브러리 타깃으로 내렸다. 앱 진입점과 앱 코드를 나누는 편이 어차피 옳다.

## 한글 IME 를 지키는 한 줄

조합 중인 글자는 아직 `NSTextView.string` 에 확정되지 않은 임시 상태다. SwiftUI 바인딩이 그 위로 문자열을 되밀면 자모가 흩어진다 — `TextEditor` 대신 `NSTextView` 를 쓰는 이유이자 D1 의 근거 중 하나다.

보호 규칙을 `MemoTextSync.apply` 라는 순수 함수로 떼어냈다. 사람이 타자를 쳐야만 드러나는 종류의 버그라 회귀가 쉬운데, `setMarkedText` 로 조합 상태를 흉내 내면 자동으로 지킬 수 있다. 규칙은 셋이다.

1. `hasMarkedText()` 면 아무것도 하지 않는다.
2. 내용이 같아도 대입하지 않는다 — 대입만으로 선택 범위가 초기화된다.
3. 반영할 때 커서를 원래 자리로 되돌린다. 안 그러면 문서 끝으로 튄다.

`textDidChange` 에서도 조합 중이면 자동 저장을 걸지 않는다. 그러지 않으면 파일에 "ㅊ" 같은 중간 자모가 저장된다.

## 검증

- `./scripts/test.sh` — 65개 테스트 10개 스위트 통과. 그중 IME 6개는 `setMarkedText` 로 만든 실제 조합 상태에서 돌고, 특히 "조합 중 외부 변경(파일 감시)이 들어와도 무시된다"를 못 박았다.
- `./scripts/verify-notes.sh` — 임시 Vault 에 메모 2장을 넣고 앱을 띄워 바탕화면 레벨 창이 정확히 2개 뜨는 것을 확인. 좌표는 `(1212, 73)` `(1182, 103)` 으로 30pt 계단 배치가 동작한다. 실제 사용자 메모는 건드리지 않도록 `LAZYMEMO_VAULT` 환경변수 재지정을 넣었다.
- **육안 확인은 여전히 대기** — 화면 기록 권한이 없어 유리 재질과 hover 버튼의 실제 모습은 사용자가 봐야 한다.