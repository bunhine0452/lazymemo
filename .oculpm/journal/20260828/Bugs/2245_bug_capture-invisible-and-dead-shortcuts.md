---
schema_version: 1
type: bug
slug: "capture-invisible-and-dead-shortcuts"
status: done
difficulty: high
created_at: "2026-08-28T22:45:11+09:00"
session_id: "20260828-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCapturePanel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/StandardMenu.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "scripts/verify-capture.sh"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureNewlineTests.swift"
    op: create
related: []
tags:
  - "bug"
  - "quick-capture"
  - "appkit"
  - "menu"
  - "verification"
  - "mcp-tool"
---
[x] 다른 앱 위에서 상자가 안 뜨고, ⌘A 가 죽어 있고, 아이콘 재클릭이 안 닫히던 것

사용자가 실제로 써 보며 네 가지를 연달아 보고했다. 전부 사람이 만져야만 드러나는 종류다.

## 발생 원인

**1. 다른 프로그램 창이 앞에 있으면 단축키를 눌러도 상자가 안 보였다.** 원인이 둘 겹쳐 있었다.

- `NSPanel.hidesOnDeactivate` 는 기본이 켬이다. 켜져 있으면 앱이 활성이 아닌 동안 AppKit 이 그 창을 화면에서 내린다. 그런데 `NSApp.activate()` 는 비동기라, 단축키를 누른 순간 앱은 아직 비활성이고 우리가 올린 창이 그대로 숨는다.
- 끄는 줄을 넣었는데도 안 고쳐졌다. **`isFloatingPanel` 의 설정자가 `hidesOnDeactivate` 를 도로 켠다.** 내가 끄는 줄을 그 앞에 두는 바람에 한 줄 뒤에서 되돌려지고 있었다.
- 그러고도 5번 중 3번 실패했다. 진단을 찍어 보니 상자가 뜬 뒤 1초 안에 다른 앱이 포커스를 도로 가져가고, 내가 이번에 넣은 `didResignActiveNotification` 관찰자가 그걸 "사용자가 떠났다" 로 읽어 스스로 닫고 있었다.

**2. ⌘A 가 안 먹었다.** 상주 앱(`.accessory`)이라 메인 메뉴가 없었고, macOS 는 ⌘A·⌘Z·⌘C·⌘V 같은 표준 편집 단축키를 **메인 메뉴를 통해서만** 응답 체인에 흘려보낸다. 메뉴가 없으니 `NSTextView` 안에서 그 키들이 전부 죽어 있었다. 글을 쓰는 앱에서 전체 선택과 되돌리기가 안 되는 것은 다른 어떤 편안함으로도 못 갚는다.

**3. 메뉴바 아이콘을 다시 눌러도 안 닫혔다.** 좌클릭이 `show()` 만 부르고 있었다. 예전에 "토글이면 안 떴나 싶어 한 번 더 눌렀을 때 도로 닫힌다" 는 걱정으로 그렇게 둔 것인데, 실제로 써 보니 **닫을 길이 없는 쪽이 훨씬 답답했다.**

**4. 엔터로 줄을 바꾸면 됐다가 되돌아왔다.** 진짜 뷰 계층을 세워 타자를 쳐 보는 테스트를 짜서 확인하니 **글자는 멀쩡했다.** 되돌아오는 것은 글이 아니라 상자 높이였다 — 창 크기 재조정이 검색 결과가 돌아온 뒤(120ms)에만 걸려 있어서, 그 사이 새 줄이 창 밖으로 밀렸다.

## 해결 방법

- `hidesOnDeactivate = false` 를 **`isFloatingPanel` 뒤에** 둔다. 순서가 곧 의미다.
- `.nonactivatingPanel` 을 더해 앱을 앞으로 끌어내지 않고도 키 입력을 받게 한다.
- **앱 비활성화로 닫는 규칙을 버렸다.** 유예 시간(700ms)도 시도했지만 튕김이 그보다 늦게 오면 똑같았다. 닫는 길을 사람이 한 일로만 한정한다 — esc, ⌘⏎, 단축키·아이콘 다시 누르기, 상자 바깥 클릭(전역 클릭 감시, 권한 불필요).
- 아이콘 자리가 이상하게 잡혀도 상자가 화면 안에 남도록 y 를 화면 안으로 물린다.
- `StandardMenu` — 메뉴 막대에 보이지 않는 메인 메뉴를 세운다(앱 메뉴 + 편집 메뉴). 항목의 target 을 비워 두어 응답 체인이 지금 글 쓰는 곳으로 보낸다.
- 아이콘 좌클릭을 `toggle()` 로.
- 글 높이가 바뀌면 **그 자리에서** 창 크기를 다시 잡는다 (`requestLayout`, 한 박자 미뤄 SwiftUI 갱신 도중 재진입을 피한다).

## 검증

- `scripts/verify-capture.sh` 신설 — 다른 앱을 앞에 세운 뒤 상자를 열고 `CGWindowList` 로 실제 화면에 올라왔는지 본다. 단축키를 프로그램으로 누르려면 손쉬운 사용 권한이 필요하므로 앱이 스스로 여는 통로(`LAZYMEMO_CAPTURE=<초>`)를 뒀다. **5회 연속 통과** (고치기 전 4회 연속 실패).
- ⌘A 는 가짜 이벤트를 만들어 메인 메뉴에 흘려보내고 선택 범위가 실제로 잡히는지 확인 — `메뉴처리=true 선택된길이=5`.
- 줄바꿈은 `NSHostingView` 로 진짜 상자를 세워 실제로 타자를 치는 테스트 3개로 고정.
- 전체 135개 통과 · 지연 중앙값 2.3ms · RSS 90.9MB / idle 0%.

## 메모

**중간에 검증 스크립트 자체가 거짓 실패를 냈다.** 잇달아 돌릴 때 SwiftPM 잠금이 부딪혀 스크립트가 조용히 죽었고, 나는 그것을 앱 결함으로 두 번 읽었다. `LAZYMEMO_SKIP_BUILD=1` 을 두고 나서야 5/5 가 나왔다. 검증 도구가 흔들리면 고치는 쪽이 헛돈다.

그리고 진단 출력이 파이프에 갇혀 한 번을 통째로 날렸다 — stdout 은 파이프로 넘길 때 통째로 버퍼링돼 프로세스가 죽을 때까지 안 나온다. stderr 로 바꾸고 나서야 원인이 보였다.