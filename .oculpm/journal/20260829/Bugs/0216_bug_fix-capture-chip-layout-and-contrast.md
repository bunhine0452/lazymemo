---
schema_version: 1
type: bug
slug: "fix-capture-chip-layout-and-contrast"
status: done
difficulty: medium
created_at: "2026-08-29T02:16:21+09:00"
session_id: "mcp-20260829-021621"
agent:
  id: "claude-code"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCapturePanel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureChipLayoutTests.swift"
    op: create
related: []
tags:
  - "quick-capture"
  - "layout"
  - "contrast"
  - "appkit"
  - "mcp-tool"
---
[x] 빠른 입력 날짜 칩 — 상자가 위로 밀려 잘리던 것과 안 읽히던 날짜 색

사용자 보고: "내일"·"오늘" 을 치면 날짜가 자동 입력되는데 그때 UI 가 상단으로 올라가며 가려지는 부분이 생기고, 날짜 색이 잘 보이지 않는다.

## 발생 원인

### ① 창을 다시 재는 시점이 칩보다 늦었다

`QuickCaptureModel.query.didSet` 은 날짜를 **즉시** 인식해 칩을 띄우지만, 창 크기를 다시 잡아 달라는 부탁(`onLayoutChange`)은 검색 디바운스(120ms) 뒤 `scheduleSearch` 의 Task 안에서만 나갔다. 칩이 뜨는 경로에는 그 부탁이 아예 없었다.

재현 측정 (테스트 하네스, 화면 상단 949):

```
빈 상태   : 내용 90  창 96   maxY 947
"내일" 직후: 내용 124 창 96   ← 28pt 가 창 밖
```

넘친 28pt 는 창 밖으로 밀려 잘렸고, 계속 타이핑하면 디바운스가 매번 취소되어 사람이 손을 멈출 때까지 그 상태가 유지됐다.

### ② 크기와 자리를 나눠서 정했다

`resize()` 가 `setContentSize` → `moveToCaptureAnchor` 순으로 창을 두 번 건드렸다. `setContentSize` 는 창의 **왼쪽 아래** 모서리를 붙잡으므로 커지는 순간 위로 자라 메뉴바를 파고들었다가(maxY 975 > 949) 되돌아왔다.

### ③ 밝은 호박색을 글자에 썼다

`Theme.highlight`(0.99, 0.76, 0.31) 를 미색 종이 위 11pt 글자에 그대로 썼다. 대비 **1.5:1** — 있는 줄은 알겠는데 안 읽히는 상태. 다크 모드는 9.9:1 로 멀쩡했다.

## 해결 방법

- `CaptureHostingView` 신설 — `layout()` 에서 실제로 잰 높이가 달라지면 창에 알린다. 모델이 "이쯤이면 커졌겠지" 하고 짐작하던 길(`onLayoutChange`/`requestLayout`)은 걷어냈다. 빠짐이 생기는 구조였고 날짜 칩이 정확히 그 빠짐이었다.
- `moveToCaptureAnchor(below:contentHeight:)` — 크기와 자리를 **한 번의 `setFrame`** 으로 정한다. 위로 튀었다 돌아오는 중간 상태가 존재하지 않는다.
- `Theme.highlightInk` / `highlightWash` — 같은 호박색을 외관별로 나눈다. 빛 모드 글자는 잉크 쪽으로 가라앉혀 5.2:1, 칩 바탕은 그만큼 또렷하게. 다크 모드는 그대로. `intentColor` 점에도 같이 적용.

## 검증

- `CaptureChipLayoutTests` 4건 신설 — 실제 `QuickCaptureController` 를 몰아 검색을 기다리지 않고 잰다. 즉시 재배치를 도로 빼면 2건이 `창 96 < 내용 123.5` 로 실패하는 것을 확인했다.
- 전체 187개 테스트 통과.
- `render-ui.sh` 로 실물 뷰를 다시 그려 빛/어둠 두 모드에서 날짜가 읽히는 것을 눈으로 확인.