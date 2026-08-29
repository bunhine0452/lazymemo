---
schema_version: 1
type: feature
slug: "quick-capture-recent-list"
status: done
difficulty: medium
created_at: "2026-08-29T15:39:38+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureBrowseTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "quick-capture"
  - "navigation"
  - "ui"
  - "mcp-tool"
---
[x] 빠른 입력이 요즘 메모를 들고 있다 — 적는 상자에서 다른 메모로 가는 길

## 추가 기능

빠른 입력 상자가 **적기 전용**이었다. 목록은 한 글자라도 쳐야 나왔는데, "무엇을 적어 뒀더라" 를 확인하려는 사람은 기억해 낸 낱말을 먼저 대야 했다 — 기억이 안 나서 여는 것인데도. 다른 메모를 다시 보려면 메뉴바 아이콘을 눌러 목록을 뒤지는 수밖에 없었고, 그 길이 이 앱에서 가장 자주 하면서 가장 멀었다.

- **빈 상자에도 목록이 있다.** 열면 요즘 메모 5장이 아래에 놓인다 (`MemoStore.memos` 차례 = 고정한 것 먼저, 그 다음 최근 수정 순). 메뉴 목록은 8장인데 여기를 5장으로 줄인 것은, 여기는 적는 자리가 먼저이고 목록이 길면 적을 자리가 화면 밖으로 밀리기 때문이다.
- **치면 그 자리가 찾은 것으로 바뀐다.** 목록이 사라졌다 나타나지 않는다 (`listing: .recent | .found`). 지우면 도로 요즘 것이 된다.
- **줄의 생김새는 메뉴 목록과 같은 낱말을 쓴다** (§14.10): 종이 색 점(찬 점 = 바탕화면에 있음, 빈 점 = 치워 둔 것) + 제목 + 시간 한 조각(`MemoTimeLabel`). 두 곳에서 같은 메모를 다르게 그리면 사람은 그것을 두 개의 목록으로 배운다.
- **손과 키보드가 같은 것을 가리킨다.** 포인터가 얹힌 줄이 곧 화살표로 고른 줄이고, 클릭하면 바로 열린다.
- 아래 힌트가 `⌘ 열기` / `↑↓ 요즘 메모` 로 지금 상태를 말한다. 빈 상자에서 눌러도 아무 일 없는 `⌘ 적기 끝` 은 감췄다 — 거짓말이기 때문이다.

## 동작 흐름

단축키 → (빈 상자에 요즘 메모가 이미 놓여 있음) → ↓ → ⌘⏎ → `windows.reveal(id)`. 적으러 온 사람의 길은 그대로다: 열자마자 커서가 서 있고 고른 것이 없으므로 ⌘⏎ 는 새 메모를 만든다.

`matches` 를 `listed` 로 바꿨다. 이제 놓인 것이 "찾은 것" 만은 아니다. 목록이 줄면 고른 자리를 함께 당기는 보정(`clampSelection`)을 한 곳으로 모았다.

## 검증

- `scripts/test.sh` 전체 245개 통과. 새 `CaptureBrowseTests` 6개 — 열면 목록이 있다 / ↓+⌘⏎ 가 그 메모를 연다 / 치면 찾은 것으로 바뀌고 지우면 돌아온다 / 다섯 장 상한 / 선택 자리 보정 / 메모가 없으면 빈 목록.
- `scripts/render-ui.sh` 에 `capture-recent` 를 더해 빛·어둠 두 벌로 눈으로 확인했다 — 찬 점과 빈 점이 구별되는지, 목록이 적을 자리를 밀어내지 않는지는 그려 봐야만 안다 (§14.9).
- 작업 중 다른 세션이 `CalendarView.swift` 를 고치고 있어 빌드가 그쪽에서 몇 분간 깨졌다. 내 변경과는 무관하며, 그 파일이 컴파일된 뒤 전체 통과를 확인했다.