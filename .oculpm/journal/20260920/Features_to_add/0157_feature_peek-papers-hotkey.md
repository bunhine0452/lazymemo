---
schema_version: 1
type: feature
slug: "peek-papers-hotkey"
status: done
difficulty: medium
created_at: "2026-09-20T01:57:48+09:00"
session_id: "20260920-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/Hotkey.swift"
    op: update
  - path: "Sources/LazyMemoUI/Settings/SettingsScreen.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoUITests/PeekTests.swift"
    op: create
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "mac"
  - "windows"
  - "hotkey"
  - "settings"
  - "comfort"
  - "mcp-tool"
---
[x] 「종이 보기」 ⌥⌘P — 다른 창 뒤에 눕는 종이를 전부 잠깐 앞에 세운다, 다시 누르면 내려앉는다

## 추가 기능

- `NoteWindowManager.peek(for:)` — 바탕화면에 보이는 종이(`window.isVisible`) 전부를 `riseBriefly(4초)` 로 손이 닿은 자리(`focusedLevel`)에 세운다. 포커스는 뺏지 않는다 — 하던 앱에 손이 그대로 있고, 그 사이 종이를 누르면 그 종이만 `becomeKey` 로 남는다. 이미 서 있는 종이(레벨이 `focusedLevel` 이고 키 윈도가 아닌 것)가 있으면 **전부 `settle`** — 「봤다」의 손짓. 치운 종이(서랍)는 `controllers` 에 없어 세우지 않는다. 세운 수를 돌려준다.
- 전역 단축키 셋째 — `Hotkey.peek`(⌥⌘P), 등록 id 4. 설정 `peekHotkeyKeyCode/Modifiers`(nil = 기본), 메뉴 「종이 보기」에 조합 표기, 설정 창 「입력」절에 「바꾸기…」 줄. 세 단축키가 서로 같은 조합이 되지 않게 바꾸기 흐름마다 나머지 둘을 막는다(기존 둘에도 종이 보기 검사를 얹었다). 다른 앱이 선점했으면 메뉴에 ⚠︎ 한 줄 — 앞의 둘과 같다.
- 왜: 종이는 바탕화면 높이에 눕는 것이 이 앱의 뜻인데(§7), 하루의 대부분 바탕화면은 브라우저 뒤다. 편의성 감사(`docs/research/convenience-audit-2026-09-17.md` §2.7)가 「월페이퍼 클릭에 종이가 살아남는가」를 이 앱의 상주가 편의인지 가르는 단 하나의 질문으로 꼽았고, 이것은 그 질문에 대한 앱 쪽의 답이다 — 클릭 한 번 대신 키 한 번, 그리고 스스로 도로 눕는다.

## 동작 흐름

1. 어느 앱에서든 ⌥⌘P → `MenuBarController.peekPapers` → `windows.peek()` → 종이 전부 4초 앞에.
2. 4초 안에 다시 ⌥⌘P → `settle` 로 곧바로 내려앉음. 4초가 지나면 `riseBriefly` 의 타이머가 스스로 내린다(키 윈도가 된 종이는 그대로).
3. 메뉴 → 「종이 보기」도 같은 길. 설정 → 입력 → 「종이 보기 · 바꾸기…」로 조합을 바꾼다(`HotkeyRecorder`).

## 검증

- `Tests/LazyMemoUITests/PeekTests.swift` 넷 — 두 장을 세우고 레벨이 `focusedLevel`·키 윈도 아님, 다시 누르면 `desktopLevel`; 80ms 뒤 스스로 내려앉음; 종이 없으면 0; 치운 종이는 세지 않음. 전체 `./scripts/test.sh` 초록(제목 시험 하나는 별도 일지의 변경으로 고침).
- 실제 화면(다른 앱 창 위로 종이가 서는 모습)은 손으로 보지 않았다 — 레벨 값만 확인. 사용자 손검증 항목: 브라우저를 앞에 두고 ⌥⌘P → 종이가 서고 4초 뒤 눕는가, 그 사이 종이 클릭이 그 종이만 남기는가.

## 메모

- ⌥⌘P 는 Finder 의 「경로 막대 보기」 같은 앱 안 단축키를 가로챈다 — 앞의 두 조합(⌥⌘N·⌥⌘V)과 같은 종류의 대가이고, 설정에서 바꿀 수 있다.
- 서랍 탭·달력 창은 세우지 않는다 — 종이만. 필요하면 `DrawerWindowController.window.riseBriefly` 를 같은 자리에 얹으면 된다.