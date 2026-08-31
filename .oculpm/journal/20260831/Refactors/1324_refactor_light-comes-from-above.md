---
schema_version: 1
type: refactor
slug: "light-comes-from-above"
status: done
difficulty: medium
created_at: "2026-08-31T13:24:43+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteControlLayout.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PhotoStrip.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyRecorder.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperPaletteTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteControlLayoutTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "design"
  - "dark-mode"
  - "layout"
  - "contrast"
  - "mcp-tool"
---
[x] 빛은 위에서 온다 — 떠 있는 조각이 다크에서만 구멍이 되던 것과 그 일가

## 동기

렌더를 라이트/다크로 나란히 놓고 열두 장을 눈으로 훑었다. 나온 결함이 전부 **같은 한 가지**였다 — 한 값으로 둔 색이 한 외관에서만 맞다. 앞서 잉크·호박색·네이비에서 고친 것과 같은 병인데, 남은 자리가 더 있었다.

1. **떠 있는 조각이 다크에서 구멍으로 보였다.** 겹쳐 뜨는 조작 캡슐과 끌고 가는 일정 조각을 맨 종이(`Paper.surface`)로 칠했는데, 색이 스민 종이보다 맨 종이가 어두워서 **어두운 쪽에서만 밝기의 방향이 뒤집혔다.** 빛은 위에서 온다 — 떠 있는 것은 바탕보다 밝아야 한다.
2. **낮은 불투명도로 깐 면이 다크에서 사라졌다.** 놓을 자리를 가리키는 판(13%), 적는 줄의 밑줄, 단축키 칩의 바탕이 전부 딥 네이비였다. 끌고 있는 동안 **가장 중요한 표시**가 다크에서만 안 보인다.
3. **링크가 본문 크기의 하한에 못 미쳤다** — 숯색 종이에서 3.5:1, 미색 종이에서도 4.3:1.
4. **사진의 가장자리가 다크에서 통째로 사라졌다** (검정 실선 + 검정 그림자).

여기에 색이 아닌 결함 둘.

5. **꼬리(날짜·태그)가 아래 캡슐에 덮였다.** 첫 줄을 비우려고 조작을 내린 것이 마지막 줄로 문제를 옮긴 셈이다. 그 줄에는 날짜가 있고, 날짜는 누르면 달력으로 가는 버튼이다.
6. 달력 줄의 새 휴지통이 목록용 흐린 세기(28%)로 그려졌고, 「미루기」·「종이로」와 맞붙어 한 덩어리로 보였다.

## 변경 요약

- **`PaperTint.raised`** — 떠 있는 조각은 제가 앉은 **종이의 색을 그대로 들고 올라간다.** 재질은 하나이므로(§14.5) 떠 있는 것도 같은 종이의 한 조각이다. 그림자도 함께 뒤집는다 — 어두운 종이 위의 검은 그림자는 아무 일도 하지 않는다. 뷰 쪽은 `RaisedSurface` 하나로 캡슐과 조각이 같은 것을 쓴다.
- **낮은 불투명도의 면은 잉크 쪽 값으로.** 놓을 자리·밑줄·칩 바탕이 `accentInk` 로. 종이 위에서 읽혀야 하는 것에는 면 색을 쓰지 않는다.
- **링크 색을 외관마다** 잡고, 재는 자리를 **여섯 색 중 가장 불리한 종이**로 옮겼다 — 링크는 어느 색 종이에도 붙는다.
- 사진의 실선을 잉크색으로(밝은 종이에서는 어두운 테, 어두운 종이에서는 밝은 테), 그림자도 외관을 따라.
- **`NoteControlLayout.footerReserve`** — 꼬리의 오른쪽에 캡슐 자리를 **미리 비운다.** 첫 줄과 반대로 푸는 까닭: 본문에 홈을 파면 적는 면이 좁아지지만 꼬리의 오른쪽은 원래 거의 비어 있고, 비워 두면 태그가 길 때만 잘린다. **가려진 것은 가려진 줄도 모르고, 잘린 것은 잘린 줄 안다.**
- 캡슐 안의 시스템 `Divider` 를 잉크 실선으로 — 지우기와 나머지를 가르는 §6 의 안전장치인데 그 선이 안 보이면 장치가 아니다.
- 달력 줄의 휴지통은 언제나 밝은 쪽(포인터가 온 줄에만 나타나므로), 세 조작 사이를 벌렸다.

## 검증

`PaperPaletteTests` 에 3건 추가 — 떠 있는 조각이 **어느 외관에서도** 종이보다 밝은지(여섯 색 전부), 그 조각 위에서 조작이 4.5:1 인지, 링크가 여섯 색 종이 어디에서도 4.5:1 인지. `NoteControlLayoutTests` 에 3건 — 꼬리가 캡슐 밑으로 안 들어가는지(네 가지 창 폭), 비우고도 날짜 한 줄이 들어가는지, 버튼이 늘면 비우는 폭도 따라 느는지. 전체 383개 통과.

`render-ui.sh` 로 열두 장을 다시 내 라이트/다크를 나란히 확인했다 — 캡슐이 뜨고, 놓을 자리가 다크에서도 보이고, 사진에 테가 생기고, 꼬리가 안 덮인다. `verify-notes`·`tidy`·`restore`·`mcp`·`landing` 통과, RSS 87.2MB / idle 0%.