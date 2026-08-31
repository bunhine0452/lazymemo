---
schema_version: 1
type: bug
slug: "capture-paste-never-delivered"
status: done
difficulty: high
created_at: "2026-08-29T18:56:26+09:00"
session_id: "20260829-006"
agent:
  id: "claude-code"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CapturePasteTests.swift"
    op: update
  - path: "scripts/verify-capture-paste.sh"
    op: create
related: []
tags:
  - "quick-capture"
  - "paste"
  - "event-routing"
  - "nonactivating-panel"
  - "mcp-tool"
---
[x] 빠른 입력의 ⌘V 가 글 상자까지 배달되지 않았다 — 처리는 고쳤는데 배달이 없었다

사용자 신고: "빠른 창 입력에 **아직도** 이미지 붙여넣기 안돼."

## 발생 원인

지난 판에서 `MemoNSTextView.performKeyEquivalent` 가 키 윈도 없이도 ⌘V 를 처리하도록 고쳤고, `CapturePasteTests` 4건은 전부 초록이었다. 그런데 그 시험은 **텍스트 뷰의 `performKeyEquivalent` 를 직접 부른다** — 그 함수가 하는 일은 지키지만 **키가 거기까지 오는지**는 재지 못한다.

실제 ⌘V 는 `NSApp.sendEvent` 를 지난다. 그리고 `NSApp.sendEvent` 는 ⌘ 조합을 **키 윈도**의 `performKeyEquivalent` 로만 흘려보낸다. 빠른 입력 상자는 `.nonactivatingPanel` 이고 `NSApp.activate()` 는 비동기이며 macOS 가 활성화를 거절하기도 해서, 상자가 **키 윈도가 아닌 채로 서 있는 순간**이 실제로 있다. 그때 `NSApp.keyWindow` 는 nil 이므로 그 호출이 아예 일어나지 않고, 텍스트 뷰의 처리는 불릴 기회조차 없다.

평범한 글자는 `event.window` 로 곧장 가므로 멀쩡히 들어간다. 그래서 화면에서는 정확히 **"글자는 쳐지는데 사진만 안 붙는다"** 로 보였다.

고친 자리가 처리였고, 남은 구멍은 배달이었다.

## 해결 방법

상자가 열려 있는 동안만 사는 **지역 keyDown 감시자**를 둔다 (`QuickCaptureController.editingKeyMonitor`). 지역 감시는 `NSApp.sendEvent` **앞에** 서므로 키 윈도 여부와 무관하게 같은 길이 된다.

- `handles(_:)` — ⌘ 조합이고, 이벤트가 상자(또는 창 없음)로 온 것이고, 글 상자가 첫 응답자일 때만 맡는다. 상자 밖(메모 창이 키일 때의 ⌘C 등)으로는 손대지 않는다.
- 우리가 처리한 이벤트는 삼킨다 — 상자가 키일 때도 두 번 붙지 않는다.
- ⌘V 뿐 아니라 ⌘A·⌘C·⌘X·⌘Z·⌥⇧⌘V 가 같은 길로 함께 살아난다.

## 검증

`scripts/verify-capture-paste.sh` — 사람이 쓰는 클립보드(`.general`)에 진짜 PNG 를 올리고, 다른 앱(Finder)을 앞에 세운 뒤, ⌘V 를 `NSApp.sendEvent` 로 흘려보낸다. **키 윈도가 있을 때와 없을 때를 둘 다 잰다.**

- 고치기 전: `키윈도없이{글자=true 넣음=0 조각=0 파일=false}` / `키윈도로{넣음=1}` — 사용자 증상 그대로 재현
- 고친 뒤: 두 경우 모두 `넣음=1 조각=1 파일=true`

시험도 배달 경로를 잰다 (`CapturePasteTests.routesCommandKeysToTheEditor`). 전체 314건 통과.