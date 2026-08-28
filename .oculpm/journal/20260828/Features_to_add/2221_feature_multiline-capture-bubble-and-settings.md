---
schema_version: 1
type: feature
slug: "multiline-capture-bubble-and-settings"
status: done
difficulty: high
created_at: "2026-08-28T22:21:17+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/Hotkey.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyRecorder.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/LinkPreviewStore.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCapturePanel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/SettingsStoreTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureGrowthTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureAnchorTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
  - path: ".oculpm/discussion/lazymemo-lazy-comfort/discussion.md"
    op: create
related: []
tags:
  - "ux"
  - "quick-capture"
  - "settings"
  - "hotkey"
  - "link-preview"
  - "privacy"
  - "mcp-tool"
---
[x] 빠른 입력을 여러 줄 말풍선으로 — 단축키 설정, 사진 끌어놓기, 링크 카드

사용자가 다섯 가지를 요구했다. Return 이 다음 줄로 갈 것, 단축키를 설정에서 바꿀 수 있을 것, 사진을 넣을 수 있을 것, 링크를 자동으로 펼칠 것, 그리고 말풍선을 메뉴바 아이콘에 매달 것. 마지막으로 "게으른 사람의 앱인지" 감사해 논의 문서로 남길 것.

## 추가 기능

**1. Return 은 다음 줄로 간다.** 확정은 ⌘⏎ 가 맡는다(`performKeyEquivalent` — ⌘⏎ 는 표준 선택자가 없어 `doCommandBy` 로 오지 않는다). 상자는 글 높이에 맞춰 한 줄에서 다섯 줄까지 자란다.

여기서 **esc 를 어떻게 할지가 가장 어려웠다.** 처음엔 "닫을 때 저장" 으로 갔다가 되돌렸다 — 이 상자는 검색을 겸하므로, 메모를 찾으려고 친 낱말이 전부 새 메모가 되어 쌓인다. 반대로 버리면 여러 줄 적다가 손이 미끄러진 한 번에 전부 잃는다. 결론은 **버리지도 저장하지도 않고 상자가 들고 있는 것**이다. 다시 열면 글이 그대로 있고 전부 선택돼 있어 그냥 치면 덮어쓴다.

↑↓ 는 글줄 이동과 찾은 목록 이동을 겸하게 됐다. 커서가 끝 줄에 닿았을 때만 목록으로 넘어간다.

**2. 말풍선이 메뉴바 아이콘 밑에 매달린다.** 화면 한가운데 띄우던 것을 되돌렸다. `NSPopover` 는 쓰지 않는다 — 시스템 팝오버의 흰 배경과 화살표가 종이 위에 얹히면 두 겹으로 보인다. 우리가 그린 종이 꼬리를 직접 붙였다. 아이콘이 화면 끝에 있으면 상자를 화면 안으로 밀고 **꼬리만** 아이콘을 따라간다.

**3. 단축키를 바꿀 수 있다** (메뉴 → 설정). 목록에서 고르게 하지 않고 **누르면 그게 단축키다.** 다른 앱이 선점했으면 등록이 실패하므로 그 자리에서 말해 주고 쓰던 것을 도로 걸어 둔다 — 바꾸려다 아예 못 쓰게 되는 것이 가장 나쁘다.

**4. 사진** — 빠른 입력에서도 붙여넣을 수 있고, 편집기에 **끌어다 놓을 수 있다.** 처리는 붙여넣기와 같은 길을 타서 파일은 Vault 로 들어가고 본문에는 마크다운 참조만 남는다 (D4).

**5. 링크 카드** — 본문의 http(s) 주소를 제목·그림이 붙은 카드로 펼친다 (`LPMetadataProvider`).

## 동작 흐름

`SettingsStore`(새 Core 타입)가 `settings.json` 을 맡는다. 값이 `nil` 이면 앱 기본값 — 파일에는 사용자가 실제로 정한 것만 남는다. `MenuBarController` 가 아이콘 자리를 알려주고(`anchorProvider`), 상자는 그 밑에 매달린다.

## 검증

- `swift build` 무경고 · `./scripts/test.sh` **132개 통과** (새 테스트 11개: 설정 영속·깨진 파일 복구 4, 상자 높이 성장 3, 말풍선 자리 4 — 화면 끝 아이콘에서 상자가 화면 밖으로 안 나가는지 포함).
- `measure-capture.sh` 중앙값 2.3ms (목표 150ms) · `verify-performance.sh` RSS 90.9MB / idle 0% · `verify-notes.sh` · `verify-restore.sh` 전부 통과.
- `render-ui.sh` 로 말풍선 꼬리를 눈으로 확인. 앱을 실제로 띄워 기동 확인 (PID 58825).

## 메모

**프라이버시 약속이 갈렸다.** README 에 "기본 상태에서 네트워크를 쓰지 않는다" 고 적어 두었는데, 링크 카드는 그 주소에 접속해야 만들 수 있다. 사용자에게 이 충돌을 먼저 알리고 진행했다. 조건 세 개를 붙였다 — ① 설정으로 끌 수 있고, ② 나가는 것은 주소 하나뿐(본문 아님)이며, ③ 한 번 가져온 것은 디스크에 남겨 다시 묻지 않는다. 메뉴 항목에 "그 주소에 접속합니다" 를 함께 적었다. 켜져 있다는 사실이 보이지 않으면 약속을 지킨 것이 아니다. README §프라이버시와 DESIGN §9.3 을 그대로 고쳐 적었다.

화면 밖 렌더로는 확인할 수 없는 것이 둘 남았다 — 상자가 여러 줄로 자라는 모습(SwiftUI 대체 경로라 높이 보고가 안 돈다)과 말풍선이 진짜 아이콘 밑에 붙는지. 둘 다 테스트로 대신 막았지만, 사람 눈 확인은 여전히 필요하다.

감사 결과는 `.oculpm/discussion/lazymemo-lazy-comfort/discussion.md` 에 남겼다. 요지: 약속 ①(마찰 제거)은 지켜졌고 **②(정리를 대신 해준다)는 거의 미구현**이다. 문제 여럿이 한 뿌리에서 나온다 — "앱이 시간에 따라 스스로 하는 일이 없다".