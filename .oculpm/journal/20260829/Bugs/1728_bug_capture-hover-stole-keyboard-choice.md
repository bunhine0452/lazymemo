---
schema_version: 1
type: bug
slug: "capture-hover-stole-keyboard-choice"
status: done
difficulty: medium
created_at: "2026-08-29T17:28:19+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureHoverTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureBrowseTests.swift"
    op: update
related: []
tags:
  - "quick-capture"
  - "selection"
  - "data-loss"
  - "mcp-tool"
---
[x] 빠른 입력에서 포인터가 스치기만 해도 ⌘⏎ 가 적던 글 대신 남의 메모를 열던 것

## 발생 원인

결함이 둘이고 뿌리가 같다 — **손이 얹힌 줄과 키보드로 고른 줄이 한 값이었다.**

① `QuickCaptureView` 의 목록 줄이 `onHover` 에서 `model.selection = index` 를 **넣기만 하고 빼지 않았다.** 그런데 `QuickCaptureModel.commit()` 은 선택이 있으면 적은 글보다 선택을 먼저 본다. 그래서 세 줄 적는 중에 마우스가 목록 위를 한 번 지나가면 ⌘⏎ 가 「적기 끝」에서 「남의 메모 열기」로 바뀌고 **적던 글은 저장되지 않았다.** 같은 상태에서 ⌘⌫ 는 가리키기만 한 메모를 휴지통으로 보냈다.

② 선택의 근거가 **자리(인덱스)** 였다. 목록은 타자마다 다시 지어지는데(요즘 것 ↔ 찾은 것), 옛 `clampSelection()` 은 자리가 범위를 벗어나면 마지막 줄로 **밀어 넣었다.** 「은행」을 골라 둔 채 `치과` 를 치면 선택이 첫 줄로 미끄러져, ⌘⏎ 가 고른 적 없는 메모를 열었다.

화면으로는 구별할 수 없는 종류다. 줄이 밝아진 것까지는 맞게 보이고 틀린 것은 그 다음에 키가 무엇을 하는가뿐이라 렌더에 나타나지 않는다.

## 해결 방법

**손은 무엇을 누를 수 있는지만 비추고, 키가 무엇을 할지는 화살표와 클릭만 정한다.**

- `selection: Int?` 저장 프로퍼티를 없애고 `selectedID: ULID?` 로 바꿨다. `selection` 은 그 id 를 지금 목록에서 찾는 계산 프로퍼티로 남겨 기존 호출부(테스트·`deleteReach`·`PreviewRenderer`)를 그대로 두었다. **자리가 아니라 그 메모 자체를 들고 있으므로** 목록이 갈려도 고른 것이 바뀌지 않는다.
- `pointed: ULID?` 를 새로 두어 hover 를 받는다. 줄을 벗어나면 놓는다. 이 값은 `commit()` 도 `deleteSelected()` 도 힌트 줄도 보지 않는다.
- `clampSelection()` → `dropSelectionIfGone()`. 고른 것이 새 목록에 없으면 **밀어 넣지 않고 놓는다.** 들고만 있다가 낱말을 지우면 되살아나는 것도 같은 거짓말이라 함께 막았다.
- 지운 줄의 자리를 지키는 규칙(§8 — ⌘⌫ 연타로 위에서부터 훑기)은 `delete()` 안에서 지우기 **전에** 자리를 적어 두는 방식으로 살렸다. 고르지 않은 줄을 지웠을 때는 이제 아무것도 밀리지 않는다.
- 화면도 갈랐다. 고른 줄은 메모 색 20%, 스친 줄은 무채 잉크 5%. 같은 자국으로 그리면 화면이 ⌘⏎ 에 대해 거짓말을 한다. 힌트 줄(「열기」·「⌘⌫ 지우기」)도 이제 스칠 때 뒤집히지 않는다.

## 검증

- `./scripts/test.sh` — 268개 통과. 새 `CaptureHoverTests` 7건이 「스치고 ⌘⏎ 하면 내 글이 저장되는가」·「스치고 ⌘⌫ 하면 글자가 지워지는가」를 못 박는다.
- `CaptureBrowseTests` 의 옛 기대(`목록이 줄어들면 고른 자리도 따라 줄어든다`)는 결함 그 자체였으므로 **놓는다**로 뒤집고, 자리 번호 대신 제목으로 고르게 고쳤다 — 요즘 목록은 최근순이라 만든 차례의 역순이고, 그것 때문에 처음 쓴 시험이 엉뚱한 메모를 골랐다.
- `./scripts/verify-capture-delete.sh` — `지움=true 글유지=true 되돌릴수있음=true`. 실제 상자에서 ⌘⌫ 가 여전히 고른 메모까지 닿는다.
- `./scripts/render-ui.sh` — `capture-recent.png` 에서 고른 줄(색)과 스친 줄(무채)이 눈으로 갈린다.