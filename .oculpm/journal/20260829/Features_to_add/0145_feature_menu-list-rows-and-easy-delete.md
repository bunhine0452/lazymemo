---
schema_version: 1
type: feature
slug: "menu-list-rows-and-easy-delete"
status: done
difficulty: medium
created_at: "2026-08-29T01:45:54+09:00"
session_id: "mcp-20260829-014554"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/MenuBar/MemoRow.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/Hotkey.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoUITests/MemoRowTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "ui"
  - "menubar"
  - "delete"
  - "design"
  - "mcp-tool"
---
[x] 메뉴바 목록을 직접 그리고, 지우는 길을 목록과 종이 위에 냈다

## 추가 기능

사용자 지적 두 가지 — "메뉴 디자인이 맘에 안 든다", "메모 삭제도 쉬워야 한다".

**목록 줄을 직접 그린다** (`MemoRow`, `NSMenuItem.view`). 나머지 항목은 시스템 것을 그대로 둔다 — 메뉴가 공짜로 주는 것(키보드 이동·esc·자리 잡기)을 버릴 이유가 없다. 한 줄에 넷: 종이 색 점(찬 점 = 바탕화면에 있음, 빈 점 = 치워 둔 것) · 제목 · 시간 한 조각 · 휴지통.

- 체크 표시(✓)를 버렸다. "바탕화면에 나와 있음" 이라는 뜻이었는데 메모 앱에서 체크는 "다 한 일"로 읽힌다.
- 시간은 `MemoTimeLabel` — `내일 15:00` · `3일 전` · `9/1`. 제목만 늘어선 목록에서는 「빈 메모」 세 줄을 구별할 수 없었다.
- 나열 수를 12장 → 8장. 「바탕화면 창 스파이크」는 ⌥ 대체 항목으로 접었고, 「빠른 입력」에 지금 걸린 단축키를 적었다.

**지우는 길을 둘 냈다.** 그동안 앱 안에서 지우려면 바탕화면에서 그 종이를 찾아 오른쪽 버튼을 누르고 `NSTextView` 시스템 편집 메뉴 맨 아래까지 내려가야 했고, 목록에서는 아예 지울 수 없었다.

- 목록 줄 오른쪽 끝의 휴지통. 평소 24% 세기로 **늘 보이고** 포인터가 오면 또렷해지며, 그 위에 올라가면 붉은 원이 깔린다. 포인터가 온 줄에서만 나타나게 하면 있는 줄을 모르고, 모르면 없는 것과 같다.
- 종이 위 겹쳐 뜨는 조작 줄의 **가장 왼쪽**에 붉은 휴지통. ×(치우기)는 오른쪽 끝에 그대로 두고 사이에 구분선. 설계문서 §6 이 "겹쳐 뜨는 줄에 휴지통을 두면 × 와 헷갈린다"며 금지했던 것을 뒤집었다 — 자리와 색으로 가르는 편이, 지울 길이 사실상 없는 것보다 낫다.
- 확인 대화상자는 두지 않는다. 하드 삭제가 없으므로(D6) 물어볼 것이 없고, 안전은 되돌리기가 만든다.

**방금 지운 것은 접어 두지 않는다.** 5분 안에 지운 메모는 목록 바로 아래에 「"제목" 되돌리기」로 최상위에 뜬다. 잘못 눌렀다는 것을 아는 순간은 지운 직후인데, 그때 되돌리는 길이 하위 메뉴 안에 있으면 조작이 둘로 는다.

## 검증

- `./scripts/test.sh` — 178 tests / 28 suites 통과. 새 `MemoRowGeometry`(휴지통 좌표·넉넉한 히트 영역) 7건, `MemoTimeLabel` 5건 추가.
- `./scripts/render-ui.sh` → `build/ui/menu.png` (강조·휴지통 위 상태를 연출해 라이트/다크 나란히), `note.png` (조작 줄을 펴서 냄). 다크에서 줄 바탕이 희게 깔리는 것을 렌더가 잡아내 `cacheDisplay` 대신 직접 그리도록 고쳤다.
- `LAZYMEMO_MENU=1` 로 실제 메뉴를 지어 항목을 찍었다 — 메모 8줄이 뷰 항목으로 서고, 지운 메모가 있을 때 「"치과 예약" 되돌리기」가 최상위에 뜬다.