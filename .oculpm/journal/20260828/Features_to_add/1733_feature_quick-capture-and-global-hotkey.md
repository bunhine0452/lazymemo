---
schema_version: 1
type: feature
slug: "quick-capture-and-global-hotkey"
status: done
difficulty: medium
created_at: "2026-08-28T17:33:48+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyManager.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NSViewSearch.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/Collection+Safe.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "scripts/measure-capture.sh"
    op: create
related: []
tags:
  - "hotkey"
  - "carbon"
  - "nspopover"
  - "quick-capture"
  - "latency"
  - "performance"
  - "korean-ime"
  - "mcp-tool"
---
[x] 빠른 입력 — ⌥⌘N 전역 단축키와 팝오버, 실측 중앙값 12.5ms

플래너 `{#quick-capture}` 4개 항목 중 `{#menubar-popover}` `{#global-hotkey}` `{#latency-measure}` 를 끝냈다 (`{#autosave}` 는 메모 창 작업에서 함께 처리됨).

## 추가 기능

`HotkeyManager`(Carbon 전역 단축키) · `QuickCaptureModel`(입력 겸 검색) · `QuickCaptureView` · `QuickCaptureController`(팝오버 + 지연 측정).

## 동작 흐름

⌥⌘N → 팝오버 표시 → 커서 활성. 치면 기존 메모가 걸러지고, ↑↓로 고른 뒤 Return 이면 그 메모를 열고, 아무것도 고르지 않은 채 Return 이면 새 메모가 된다. Esc 로 닫는다.

## 설계 결정

**단축키를 ⌥⌘N 으로 골랐다.** 한국어 사용자의 손에 익은 조합을 피해야 한다 — ⌘Space(Spotlight), ⌃Space·⌃⌥Space(입력 소스 전환)는 건드리면 안 되고, ⌥Space 는 Raycast·Alfred 가 흔히 선점한다. 등록 실패(다른 앱이 선점)는 조용히 넘기지 않고 메뉴에 경고 줄로 띄운다.

**Carbon `RegisterEventHotKey` 를 쓴다.** `CGEventTap` 은 손쉬운 사용 권한을 요구하는데, 메모 앱이 첫 실행에서 사용자를 시스템 설정으로 보내면 "게으름 타파"라는 전제가 그 자리에서 무너진다. Carbon API 는 낡았지만 권한이 필요 없다.

**입력과 검색을 한 상자가 겸한다.** 모드 전환이 없어야 조작 수가 줄어든다 (§11 의 "생각 → 저장 2회 이내").

**좌클릭은 빠른 입력, 우클릭은 메뉴.** `statusItem.menu` 에 메뉴를 걸면 좌클릭이 메뉴에 잡혀 빠른 입력이 막힌다. `button.sendAction(on:)` 으로 갈랐다.

**Return 을 가로채되 조합 중에는 넘기지 않는다.** 한글 입력에서 Return 은 먼저 조합을 확정하는 키다. `doCommandBy` 에서 `hasMarkedText()` 를 확인하지 않으면 마지막 글자를 잃는다.

## 실측 — 목표 150ms, 결과 중앙값 12.5ms

`scripts/measure-capture.sh` 로 release 빌드에서 12회 측정했다.

```
표본 12회  최소 4.1ms  중앙값 12.5ms  최대 34.3ms
✓ 목표 150ms 이내
```

프리워밍이 효과가 있었다 — `NSHostingController` 를 앱 기동 시 만들고 `layoutSubtreeIfNeeded()` 로 `loadView` 를 미리 치른다. 팝오버 애니메이션도 껐다(`animates = false`): 150ms 예산에서 애니메이션은 사치이고, 즉시 나타나는 편이 오히려 빠르게 느껴진다.

측정 범위의 한계를 밝혀 둔다. 전역 단축키를 프로그램으로 누르려면 손쉬운 사용 권한이 필요해서, **단축키 이후의 경로(팝오버 표시 + 커서 세우기)만** 반복 측정했다. Carbon 이 이벤트를 넘겨주는 시간은 포함되지 않는다. 예산 대비 여유가 10배라 그 몫을 더해도 안전하다고 본다.

## 검증

- `./scripts/measure-capture.sh 12` — 위 수치.
- `swift build` 경고 0, 기존 68개 테스트 그대로 통과.
- **육안 확인 대기** — 팝오버의 실제 모습과 ⌥⌘N 이 다른 앱과 충돌하지 않는지는 사용자가 봐야 한다.