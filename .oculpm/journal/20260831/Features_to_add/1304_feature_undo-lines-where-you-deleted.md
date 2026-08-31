---
schema_version: 1
type: feature
slug: "undo-lines-where-you-deleted"
status: done
difficulty: high
created_at: "2026-08-31T13:04:31+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/RowTrash.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DeleteUndoTests.swift"
    op: create
related: []
tags:
  - "delete"
  - "undo"
  - "calendar"
  - "note"
  - "mcp-tool"
---
[x] 지운 자리에 되돌리기가 남는다 — 종이의 휴지통과 달력 줄의 뚫린 구멍

## 추가 기능

§6 은 "지우는 길이 셋" 이라고 적었지만 **되돌리는 줄이 그 자리에 생기는 것은 목록뿐이었다.**

- **종이의 휴지통**만 창이 소리 없이 사라지고 화면에 흔적이 한 줄도 안 남았다. 잘못 눌렀다는 것을 아는 순간은 지운 직후인데, 그때 되돌리려면 메뉴바 아이콘을 눌러 메뉴를 뒤져야 한다 — 지우기는 한 번이고 되돌리기가 셋이면 그 휴지통은 못 누르는 버튼이다.
- **달력 줄에는 지우는 길이 아예 없었다.** 「미루기」·「종이로」는 있는데 지우기만 없어서, 필요 없어진 일정을 치우려면 날짜를 떼어 바탕화면으로 내려보낸 뒤 그 종이를 찾아 지워야 했다 — 조작이 셋이고, 그 사이 치우려던 것이 종이 한 장으로 눈앞에 난다. 「종이로」는 *언제 할지 모르겠다*는 뜻이고 지우기는 *안 하겠다*는 뜻이라 한 버튼에 묶을 수도 없다.

## 동작 흐름

**종이** — `NoteModel.justDeleted` 가 8초 동안 지운 메모를 든다. 표시는 `store.delete` **전에** 세운다: 지우는 순간 목록이 바뀌고 `NoteWindowManager.sync` 가 그 자리에서 창을 거두는데, 그 판단이 이 표시를 보고 갈리기 때문이다(`NoteWindowController.isMourning`). 8초가 지나면 `onDeletionSettled` 가 `sync()` 를 다시 불러 그때 창이 거둬진다. 화면에는 종이 위에 「「제목」 지웠습니다 · 되돌리기」가 덮이고, 그동안 편집은 막는다 — 휴지통 안의 파일에 쓰는 일이 되기 때문이다.

곁들여 하나 더 고쳤다: `layouts.prune` 이 지우는 순간 그 메모의 자리를 지워서 **되살린 종이가 엉뚱한 곳에 떴다.** 휴지통에 있는 것의 자리도 함께 남긴다 — 되돌리기는 되돌리기여야 한다.

**달력** — `CalendarModel.delete/restoreDeleted` 와 줄 오른쪽 끝의 휴지통. 바닥의 한 줄은 하나뿐이라 지우기와 옮기기가 서로를 밀어낸다(마지막 것만 남는다). 휴지통 뷰는 빠른 입력과 **같은 것을 쓰도록** `RowTrash` 로 떼어냈다 — 지우는 길이 넷인데 생김새가 넷이면 사람은 그것을 네 개의 조작으로 배운다.

## 검증

`DeleteUndoTests` 8건 신설 — 종이의 되돌리기(줄이 서는가·되살아나는가·지운 뒤 글이 안 들어가는가·자리가 남는가), 달력의 지우기와 되돌리기, 두 되돌리기 줄이 다투지 않는 것, 지우기가 날짜 떼기와 다른 일인 것. 전체 377개 통과. `note-deleted.png` 는 **정말로 한 장 지워서** 그리므로 그림이 곧 검증이다.