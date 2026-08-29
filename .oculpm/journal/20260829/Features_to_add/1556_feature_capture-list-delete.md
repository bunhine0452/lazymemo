---
schema_version: 1
type: feature
slug: "capture-list-delete"
status: done
difficulty: medium
created_at: "2026-08-29T15:56:47+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureDeleteTests.swift"
    op: create
  - path: "scripts/verify-capture-delete.sh"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "quick-capture"
  - "delete"
  - "keyboard"
  - "verification"
  - "mcp-tool"
---
[x] 빠른 입력의 목록에서 그 자리에서 지운다 — 휴지통·⌘⌫·되돌리는 줄

사용자 요청: "내가 메모한 것들을 손쉽게 삭제할 수 있게도 보여줘."

## 추가 기능

메뉴 목록은 여덟 장에서 끊긴다. 그 너머는 빠른 입력에서만 만나는데 **거기엔 여는 길뿐이었다** — 아홉 번째 메모부터는 바탕화면에서 그 종이를 찾아내는 것 말고 지울 방법이 없었다. 넘침 줄이 "빠른 입력에서 찾기" 라고 넘겨 놓고 정작 그곳에서 못 지우는, 길이 끊긴 자리였다.

- **줄 오른쪽 끝에 휴지통.** 평상시 28% 세기로 늘 켜 두고(메뉴 목록의 24% 와 같은 규칙 — 숨긴 조작은 없는 것과 같다), 고른 줄에서 또렷해지며, 그 위에 포인터가 오면 붉은 원이 깔린다.
- **⌘⌫ 로도 지운다.** Finder 와 같은 손짓이라 새로 배울 규칙이 없다. 고른 줄이 없으면 가로채지 않고 글 편집(`deleteToBeginningOfLine:`)으로 넘긴다.
- **되돌리는 줄은 목록 바로 아래에 남는다** (D6). 잘못 눌렀다는 것을 아는 순간은 지운 직후인데, 그때 되돌리는 길이 메뉴 안에만 있으면 상자를 닫고 아이콘을 눌러 찾아 들어가야 한다.
- 힌트 줄에 `⌘⌫ 지우기` — **⌘ 를 빼면 안 된다.** ⌫ 하나는 글자를 지우는 키라, 그렇게만 적으면 사람은 글을 지우면서 메모가 안 지워진다고 여긴다.

## 동작 흐름

- 지운 뒤 **상자는 닫지 않는다.** 치우려고 연 사람은 대개 한 장만 지우지 않는데, 지울 때마다 닫히면 단축키를 다시 눌러 같은 낱말을 또 쳐야 한다.
- 고른 자리는 지킨다. 지운 줄의 다음 줄이 그 자리로 올라와 ⌘⌫ 연타로 위에서부터 훑으며 치워진다.
- 목록은 디바운스 없이 즉시 다시 짓는다 — 지운 줄이 남아 있으면 "안 지워졌다" 로 보이고 사람은 한 번 더 누른다. 요즘 것을 보고 있었으면 요즘 것으로, 찾은 것을 보고 있었으면 같은 낱말로 다시 찾는다.
- 여는 자리와 지우는 자리를 한 뷰에 겹치지 않았다(누르기 하나를 놓고 둘이 다투면 이기는 쪽이 상황마다 달라진다). 탭 제스처는 내용 덩어리에만, 버튼은 그 밖에.
- 메뉴 넘침 줄도 "빠른 입력에서 찾기·지우기" 로 고쳤다 — 길이 생겼으면 그렇게 적어야 한다.

## 함정

**키가 어디로 갔는지는 그림에 안 나온다.** ⌘⌫ 가 메모 대신 적던 글자를 지워도 렌더는 똑같고, 이 상자는 `.nonactivatingPanel` 이라 ⌘ 조합이 글 쓰는 곳까지 못 닿은 전력이 있다(⌘V 가 죽었던 일). 그래서 앱 안에서 가짜 키를 눌러 보는 통로를 뒀다(`LAZYMEMO_DELETE=1`). **그 진단이 첫판에 자기 자신의 결함을 잡았다** — 글을 텍스트 뷰에 직접 꽂았더니 다시 그릴 때 모델의 빈 글이 되밀려(`MemoTextSync`) "⌘⌫ 가 글자를 지웠다" 로 잘못 나왔다. 글은 반드시 모델을 거쳐 넣어야 실제와 같은 길이 된다.

## 검증

- `./scripts/test.sh` — **260개 전부 통과.** 새 스위트 `빠른 입력 — 목록에서 지우기` 8건 (휴지통 이동·되돌리기·고른 자리 유지·마지막 한 장·찾은 목록 갱신·⌘⌫ 가로채기와 넘김·다시 열 때 되돌리기 줄 정리).
- `./scripts/verify-capture-delete.sh` — 가짜 ⌘⌫ 로 `지움=true 글유지=true 되돌릴수있음=true`.
- `./scripts/render-ui.sh` — `capture-recent.png` 에 휴지통 다섯 줄·붉은 원·되돌리는 줄이 라이트/다크로 확인. 되돌리는 줄은 흉내가 아니라 **실제로 한 장 지워서** 띄운다.