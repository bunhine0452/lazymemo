---
schema_version: 1
type: feature
slug: "capture-rotating-prompt-drop-dot"
status: done
difficulty: low
created_at: "2026-08-29T15:37:25+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/CapturePrompt.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CapturePromptTests.swift"
    op: create
related: []
tags:
  - "quick-capture"
  - "ui"
  - "copywriting"
  - "mcp-tool"
---
[x] 빠른 입력 — 안내 문구를 열 때마다 바꾸고, 뜻 없는 보라색 점을 걷어냄

## 추가 기능

빠른 입력 상자의 안내 문구를 고정된 "무엇이든" 에서 **열 때마다 바뀌는 문구**로 바꿨다. 고정된 안내는 며칠이면 벽지가 되어 읽히지 않고, 읽히지 않는 안내는 없는 것과 같다.

문구는 세 갈래로 섞어 20개를 준비했다.
- **재촉** — "지금 머리에 걸린 것", "손에서 놓기 전에"
- **본보기** — "내일 3시, 라고 적어도 됩니다", "치과 목요일 두 시" (날짜 인식을 안내 없이 가르친다)
- **안심** — "닫아도 남습니다", "사진은 붙여넣으면 됩니다"

## 동작 흐름

`CapturePrompt.next(after:)` 가 **방금 본 것을 뺀** 나머지에서 뽑는다 — 무작위로만 두면 같은 것이 연달아 나오는 날이 있고, 사람 눈에는 그 한 번이 "안 바뀐다" 의 증거가 된다. `QuickCaptureModel.prepareForShow()` 가 상자를 열 때마다 새로 집으므로, 화면에 이미 뜬 문구가 중간에 바뀌는 일은 없다.

## 걷어낸 것 — 글머리의 보라색 점

⌘⏎ 를 누르면 벌어질 일을 색으로 말하던 9pt 점이었다. 보라면 새 메모, 노랑이면 달력행, 메모 색이면 그 메모를 연다.

그런데 그 셋은 이미 **글자로** 말하고 있다 — 날짜 칩의 "달력으로", 목록에서 골라진 줄. 같은 말을 아무도 배운 적 없는 색으로 한 번 더 하는 셈이라, 사용자에게 남은 것은 "이 점은 무슨 뜻이지" 라는 물음뿐이었다. 뜻이 겹치면 조용한 쪽을 버린다. 점을 감싸던 `HStack` 과 칩들의 `padding(.leading, 9 + Theme.normal)` 도 함께 없애 글·사진·칩이 모두 같은 왼쪽 끝에 선다.

## 검증

- `scripts/test.sh` — 239개 전부 통과. 새 시험 4개(`CapturePromptTests`): 연속 중복 없음(200회), 준비된 문구 안에서만 나옴, 한 줄 길이(20자 이내), 모델이 열 때마다 새로 집음(20회에 2종 이상).
- `scripts/render-ui.sh` — `capture.png` 에서 점이 사라지고 글·사진·날짜 칩의 왼쪽 끝이 맞은 것, `capture-recent.png` 에서 빈 상자에 뽑힌 문구("짧을수록 남습니다")가 뜨는 것을 눈으로 확인.