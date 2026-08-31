---
schema_version: 1
type: bug
slug: "controls-no-longer-cover-title"
status: done
difficulty: medium
created_at: "2026-08-29T19:21:28+09:00"
session_id: "20260829-006"
agent:
  id: "claude-code"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteControlLayout.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteControlLayoutTests.swift"
    op: create
related: []
tags:
  - "note-window"
  - "controls"
  - "layout"
  - "philosophy-4"
  - "mcp-tool"
---
[x] 겹쳐 뜨는 조작이 제목을 덮었다 — 읽으려는 손짓이 읽을 것을 가렸다

## 발생 원인

종이에 포인터를 올리면 조작 캡슐이 오른쪽 **위**에 떴다. 다섯(휴지통·색·고정·달력·×)에 구분선까지 한 줄이라 캡슐이 106pt 인데, 기본 종이는 260pt 이고 글이 놓이는 폭은 220pt 다 — **첫 줄의 42% 가 그 밑으로 들어갔다.**

핵심은 폭이 아니라 **누가 그것을 부르는가**였다. 캡슐을 부르는 손짓(포인터 올리기)이 곧 읽으려는 손짓이다. 이 앱은 포인터가 오면 종이를 진하게 되살리는데(철학 3), 같은 손짓이 제목을 가렸다 — 읽으려고 다가가면 읽을 것이 사라지는, 스스로를 무는 조작이었다.

첫 줄은 이 앱에서 가장 비싼 한 줄이다. 메뉴 목록도, 빠른 입력도, 달력도 그 줄을 제목으로 쓴다.

렌더로도 안 잡히고 있었다 — `note.png` 의 표본이 「치과 예약」 네 글자라 캡슐 밑에 닿지 않았다. 제목이 줄을 채우는 표본(`note-long-title`)을 넣으니 「받기」가 잘린 채 나왔다.

## 해결 방법

**조작을 두 모서리로 나눈다.**

- **오른쪽 위 — 치우기(×) 하나.** 창을 닫으러 가는 손은 오른쪽 위 모서리로 가고, 그 습관을 이 앱만 다르게 만들 이유가 없다. 혼자 남으면 24pt 라 첫 줄에서 덮는 폭이 6pt — 한 글자(14pt)보다 좁다.
- **오른쪽 아래 — 휴지통·색·고정·달력.** 마지막 줄은 제목이 아니고, 꼬리(날짜·태그)는 왼쪽에 붙으므로 오른쪽 아래는 대개 비어 있다.

덤으로 **지우기와 치우기가 종이의 높이만큼 멀어졌다** — §6 이 원하던 갈라 놓기가 더 세졌다.

숫자는 `NoteControlLayout` 한자리에 모으고 `QuietButton` 도 같은 상수를 쓴다. 흩어 두면 버튼 하나 더하는 것만으로 조용히 되돌아오는데, 그 사실은 렌더를 눈으로 보기 전에는 드러나지 않는다.

**남는 겹침**: 태그가 길면 꼬리의 오른쪽 끝이, 사진이 있으면 그 오른쪽 아래 모서리가 포인터를 올린 동안 가려진다. 날짜는 맨 왼쪽이라 안전하다. 제목을 가리는 것과 견주면 훨씬 싼 값이라 그대로 둔다.

## 검증

`scripts/render-ui.sh` 에 `note-long-title` 표본을 추가해 결함을 먼저 눈으로 재현하고, 고친 뒤 같은 표본으로 확인했다 (제목 온전, 캡슐은 아래).

`NoteControlLayoutTests` 4건 — 첫 줄에서 덮는 폭이 한 글자보다 좁을 것(160~400pt 모든 종이 크기에서), 옛 배치(5+구분선)가 글 폭의 40% 를 넘었다는 사실, 캡슐 폭 셈이 실제 배치와 어긋나지 않을 것. 0pt 가 아니어야 한다는 것도 못 박았다 — 0 이면 첫 줄에 영구히 홈을 판 것이고 그건 철학 4 를 어긴다.

시험 334건 통과. `verify-tidy.sh`·`verify-capture-paste.sh` 도 통과.