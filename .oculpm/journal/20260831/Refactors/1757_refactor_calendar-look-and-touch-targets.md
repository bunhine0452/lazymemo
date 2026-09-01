---
schema_version: 1
type: refactor
slug: "calendar-look-and-touch-targets"
status: done
difficulty: medium
created_at: "2026-08-31T17:57:53+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteControlLayout.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/RowTrash.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MemoRow.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarLayout.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarInk.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/PenMarks.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CalendarLayoutTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteControlLayoutTests.swift"
    op: update
related: []
tags:
  - "ui"
  - "calendar"
  - "accessibility"
  - "hit-target"
  - "mcp-tool"
---
[x] 달력 생김새를 다시 잡고, 화면 전체의 과녁을 Theme.touch 로 올린다

## 동기

사용자가 두 가지를 한 번에 말했다 — **「달력 디자인이 별로다」**, **「모든 버튼이 너무 작아서 클릭하기 힘들다」**. 렌더(`scripts/render-ui.sh`)를 놓고 보니 둘은 같은 뿌리였다: 그림과 과녁을 갈라 놓지 않아서 「조용한 화면」이 「안 눌리는 화면」이 되어 있었고, 달력의 머리·얼룩·띠가 각자 다른 크기로 서로 밀치고 있었다.

## 변경 요약

### 1. 과녁 — 그림은 그대로, 누르는 자리만 넓힌다

`Theme.touch = 24` / `Theme.touchRow = 22` 와 `View.hitTarget(_:)` 을 세워 한자리에서 정한다. 이걸 지키도록 올린 것들:

| 자리 | 전 | 후 |
|---|---|---|
| `QuietButton` (종이의 ×·휴지통·색·고정·달력) | 18 | 24 (`NoteControlLayout.button`) |
| `RowTrash` (빠른 입력·달력 목록) | 20 | 21pt 원판 + 24 판정 |
| 메뉴 한 줄 / 그 줄의 휴지통 | 30 / 22 | 32 / 24 |
| 달력 이웃 달 (`7월`·`9월`) | 글자 폭 그대로 | 24 높이 + 좌우 10, 손이 오면 자리가 옅게 드러남 |
| 달력 「오늘」·「미루기」·「종이로」·핀 | 9pt·15pt 높이 | 10.5pt·22~24pt 높이 |
| 달력 「되돌리기」·「그만두기」·「이 날에 적기」 | 글자만 | 24 높이 |
| 종이 꼬리의 날짜·장소 칩 | 13 | 19 (`footerLine`) |
| 색 고르기 여섯 개 | 17 | 26 판정 |

주 높이 최소도 30 → 32 로 올렸다. 칸 하나가 `Theme.touch` 보다 작으면 이 창에서 가장 자주 누르는 과녁 마흔둘이 전부 최소치 아래라는 뜻이고, 착지 판정도 같은 칸이다. 그만큼 최소 창(272×300 → 288×356)과 기본 창(300×440 → 320×470)도 함께 올렸다.

### 2. 달력 생김새

- **머리**: `7월 8월 9월` 이 붙어 한 문장으로 읽히고 해(2026)는 오른쪽 끝에 떠 있던 부스러기였다. 달과 해를 한 덩어리로 묶고, 이웃 달은 제 몫의 자리를 갖는 버튼이 됐다. 머리 높이 36 → 42.
- **요일 줄**: 9.5 → 11pt, 아래에 아주 옅은 획 하나. 요일 일곱 자가 숫자 마흔둘 위에 그냥 떠 있던 것을 갈라 놓는다. 높이 15 → 19.
- **얼룩**: 반지름을 1/3 로 줄이고(`0.11+0.22·spread` → `0.05+0.09·spread`) 심을 또렷하게(그라디언트 0.58 까지 원색). 앞선 값은 **초점 안 맞은 사진**으로 보여서 달을 통째로 보면 칸마다 먼지가 앉은 것 같았다. 벌어지는 비율(`legibleSpan`)은 그대로다.
- 얼룩이 앉는 자리 0.30 → 0.34, 눌린 정도 0.74 → 0.86. 고른 날의 밑줄과 뭉쳐 **초승달 모양의 고장**처럼 보이던 것이 갈렸다.
- **이번 주 자국**: 0.30 → 0.16, 띠 높이 0.72 → 0.60. 큰 창에서 형광펜 자국이 아니라 쏟은 것으로 보였다.
- **목록 한 줄**: 조작 넷을 줄 **안에** 밀어 넣던 것을 종이와 같이 **겹쳐 뜨는 캡슐**로 바꿨다(`rowControls`). 포인터가 와도 줄이 다시 짜이지 않고(장소가 사라지고 제목이 줄던 출렁임이 없다), 조작은 제 크기를 갖는다.
- 숫자 몫 0.64 → 0.68, 눈금 범위 `mark 16…30` / `numeral 11.5…19`.

### 3. 덤으로 잡은 것

버튼이 커지면서 종이의 조작 캡슐도 높아졌고, **아랫줄만 덮던 것이 윗줄까지 닿아** 「#병원」의 아랫동강이 캡슐 밑으로 들어갔다. 윗줄에도 자리를 비우면 날짜가 「8월 31일…」로 잘리므로 — 그 잘림은 자리가 모자라서가 아니라 캡슐이 아랫줄에 있어서 생긴 것이라 사람이 이유를 알 수 없다 — 꼬리를 두 줄일 때 통째로 캡슐 위로 올렸다 (`NoteControlLayout.footerTwoLineInset`).

## 검증

- `./scripts/test.sh` — 538개 전부 통과. 판형 표본의 「최소」 창을 새 최소치로 바꾸고, 주 높이 하한을 `Theme.touch` 로 못 박고, 두 줄 꼬리가 캡슐 위로 올라서는지 새로 시험 하나를 더했다.
- `./scripts/render-ui.sh` — 기본·넓은·큰 창, 끌고 있는 중, 놓을 날을 고르는 중, 종이(짧은 제목/긴 제목), 메뉴, 빠른 입력을 빛·어두움 두 벌로 눈으로 확인.