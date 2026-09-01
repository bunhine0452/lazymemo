---
schema_version: 1
type: bug
slug: "flaky-paste-diagnostic"
status: done
difficulty: medium
created_at: "2026-08-31T20:02:34+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
related:
  - ref: "20260831/Bugs/1953_bug_capsule-too-crowded-to-press.md"
    kind: "followup"
tags:
  - "flaky"
  - "verify"
  - "quick-capture"
  - "diagnostics"
  - "mcp-tool"
---
[x] 「회귀」로 오인된 것은 진단이 시간을 기다린 탓이었다

다른 세션(`lazymemo-0c`)이 `verify-capture-paste.sh` 가 지금 트리에서 실패하고 HEAD 에서 통과한다며 «커밋 안 된 변경이 넣은 회귀» 로 보고했다. 의심 대상은 내가 한 recall 작업이었다.

## 발생 원인

**회귀가 아니라 진단이 깜빡이고 있었다.**

각자 한 번씩 뽑은 표본으로는 회귀와 깜빡임을 가를 수 없었다. 같은 트리를 다섯 번 돌리자 3승 2패가 나왔고, HEAD 를 `git worktree` 로 뽑아 같은 다섯 번을 돌리자 **분포도 패턴도 똑같았다.**

```
지금 트리 : 1✓ 2✗ 3✗ 4✓ 5✓
HEAD      : 1✓ 2✗ 3✗ 4✓ 5✓
```

원인은 `QuickCaptureController.pasteRound(deactivating:)` 의 한 줄이다.

```swift
NSApp.deactivate()
try? await Task.sleep(for: .milliseconds(400))
```

**비활성화는 비동기인데 고정 시간으로 기다리고 있었다.** 400ms 안에 실제로 물러날 때도 있고 아닐 때도 있어서, 이 진단은 재려던 세상(상자가 키 윈도가 아닌 상태)이 아니라 **그때그때 다른 세상**을 재고 있었다. 그래서 「글자가 들어갔는가」가 실행마다 갈렸다.

## 해결 방법

시간이 아니라 **상태**를 기다리게 했다 — `NSApp.isActive` 가 내려갈 때까지 25ms 씩 최대 2초, 그 뒤 창 서열이 정리될 한 박자.

**6/6 결정적으로 통과한다.** 그리고 결과가 초록이라는 것은 동작이 처음부터 옳았고 **깜빡임이 잰 쪽에 있었다**는 뜻이다.

같은 종류의 실수를 이 세션에서 두 번 했다 — `CaptureRecallTests` 도 고정 320ms 대기라 기계가 바쁘면 졌다. **비동기를 시간으로 기다리면 언젠가 진다.** 조건을 기다려야 한다.

## 검증

`./scripts/test.sh` 598개 통과. `verify-notes`·`verify-mcp`·`verify-drawer`·`verify-capture-paste`·`verify-restore`·`verify-capture-delete` 전부 통과. HEAD 워크트리는 지웠다(공유 트리는 건드리지 않았다).

## 메모

**가끔 빨간 검증 스크립트는 초록보다 나쁘다.** 이 하나가 두 세션의 시간을 먹었고, 하마터면 멀쩡한 코드를 뒤지게 만들 뻔했다.

세션끼리 규칙 하나를 세웠다 — `render-ui.sh`·`verify-*.sh` 는 전부 `pkill -f "$BIN"` 으로 시작하므로 **한쪽이 앱을 띄운 동안 다른 쪽이 돌리면 남의 실행을 죽인다.** 앞으로 앱을 띄우는 스크립트는 서로 알리고 돌린다. `swift build` 와 `test.sh` 는 앱을 안 띄우므로 아무 때나 괜찮다.

방법론 하나를 배웠다 — 상대 세션이 「HEAD 도 같은 횟수로 돌려 보라」고 짚어 주지 않았으면 트리에서만 N번 돌리고 «가끔 빨감» 에서 멈췄을 것이다. **깜빡임을 봤을 때 비교 대상도 같은 횟수로 재야** 회귀와 갈린다.