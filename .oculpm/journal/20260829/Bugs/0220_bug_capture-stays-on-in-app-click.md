---
schema_version: 1
type: bug
slug: "capture-stays-on-in-app-click"
status: done
difficulty: medium
created_at: "2026-08-29T02:20:17+09:00"
session_id: "mcp-20260829-022017"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "scripts/verify-capture-dismiss.sh"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureDismissTests.swift"
    op: create
related: []
tags:
  - "bug"
  - "quick-capture"
  - "appkit"
  - "event-monitor"
  - "verification"
  - "mcp-tool"
---
[x] 바탕화면 메모를 고치던 중에 단축키로 상자를 열고, 아무것도 안 친 채 바탕화면 쪽을 누르면 상자가 그대로 남았다.

## 발생 원인

상자를 치우는 길은 사람이 한 일로만 한정돼 있고(esc·⌘⏎·단축키·아이콘·바깥 클릭), 그중 **바깥 클릭은 감시가 하나뿐이었다** — `NSEvent.addGlobalMonitorForEvents`.

그런데 전역 감시는 이름과 달리 모든 클릭을 보지 않는다. **다른 앱으로 가는 클릭만** 본다. 우리 앱이 받은 이벤트는 오지 않는다.

바탕화면에는 우리 앱의 창이 널려 있다. 메모 창은 `desktopIconWindow + 1` 레벨에 눕는 우리 창이다. 그러니 "메모를 고치다가 → 상자를 열고 → 바탕화면(=메모 언저리)을 누른다" 는 동선에서 그 클릭은 **우리 앱이 받는다.** 전역 감시에는 아무 일도 일어나지 않았고, 상자는 남았다.

앱 비활성화로 닫는 규칙은 이전에 버렸으므로(포커스가 잡음으로도 튄다) 상자를 치울 사람이 아무도 없는 상태였다.

## 해결 방법

**감시를 둘로 나눈다.** 바깥이 두 종류이므로 감시도 둘이어야 한다.

- 전역 감시(`addGlobalMonitorForEvents`) — 다른 앱. 그대로 둔다.
- 지역 감시(`addLocalMonitorForEvents`) — 우리 앱의 다른 창(메모·달력·설정). 새로 단다. 이벤트는 삼키지 않고 그대로 흘려보낸다. 상자를 치우는 것과 메모에 커서를 놓는 것은 **한 번의 클릭으로 같이** 일어나야 한다.

치울지 말지의 판단은 `dismissesCapture(insidePanel:at:anchor:)` 로 떼어 창 없이도 검증할 수 있게 했다. 두 가지 예외가 있다.

- 상자 자신에게 간 클릭은 바깥이 아니다.
- **메뉴바 아이콘 자리는 건드리지 않는다.** 아이콘은 스스로 토글한다(mouseUp). 여기서 mouseDown 에 먼저 닫아 버리면 이어지는 토글이 도로 열어 깜빡이기만 한다.

클릭 자리는 `NSEvent.mouseLocation` 이 아니라 이벤트에서 뽑는다 — 다른 앱으로 간 클릭은 창이 없어 `locationInWindow` 가 이미 화면 좌표다.

## 검증

- `scripts/verify-capture-dismiss.sh` 신설. 클릭을 밖에서 만들려면 손쉬운 사용 권한이 필요해(osascript 가 -25211 로 거절) 앱이 **자기 이벤트 큐에 가짜 클릭을 넣는** 통로를 뒀다 (`LAZYMEMO_DISMISS=1`). 결과: `감시=2 열림=true 안쪽클릭뒤열림=true 바깥클릭뒤열림=false`.
- **반증도 돌렸다.** 지역 감시 등록만 빼고 같은 검증을 돌리니 `바깥클릭뒤열림=true` — 사용자가 겪은 그림이 그대로 재현됐다. 검증이 결함을 실제로 잡는다는 뜻이다.
- 판단 함수 단위 테스트 4개(`CaptureDismissTests`) 추가. 전체 194개 통과.

## 메모

첫 반증 실험은 **거짓 통과**를 냈다. `let ours = NSEvent.addLocalMonitorForEvents(...)` 에서 결과를 배열에 담는 줄만 지웠는데, 그것으로는 감시가 빠지지 않는다 — 등록은 호출 시점에 이미 끝났고 배열은 해제용 손잡이일 뿐이다. `close()` 에 스택을 찍고 나서야 "빠졌다고 믿은 감시가 여전히 부르고 있다" 는 것이 보였다. 무언가를 빼는 실험은 **뺐다는 증거**까지 봐야 한다.