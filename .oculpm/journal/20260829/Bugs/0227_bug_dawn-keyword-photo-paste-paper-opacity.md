---
schema_version: 1
type: bug
slug: "dawn-keyword-photo-paste-paper-opacity"
status: done
difficulty: high
created_at: "2026-08-29T02:27:49+09:00"
session_id: "mcp-20260829-022749"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/TimeParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Schedule.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PaperAppearance.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/PhotoStrip.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/DaylessTimeTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/PaperAppearanceTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "parser"
  - "paste"
  - "photos"
  - "settings"
  - "ui"
  - "mcp-tool"
---
[x] 새벽을 못 읽던 것, 사진이 안 보이던 것, 그리고 종이 투명도

## 발생 원인

**① 「새벽」을 못 읽었다.** 낱말표(`TimeWords`)에는 있었는데 `NaturalDateParser` 가 **날짜 낱말이 없으면 무조건 넘기고** 있었다. `내일 새벽 2시` 는 읽고 `새벽 2시` 는 못 읽는 상태 — 「아침 회의」·「저녁 7시 약속」도 전부 같이 죽어 있었다.

**② 사진 붙여넣기가 "안 되는" 것으로 보였다.** 붙여넣기 자체는 멀쩡했다 (스크래치 붙임판으로 PNG·TIFF·NSImage·파인더 파일·웹 이미지 다섯 경우를 태워 전부 통과). 안 보인 이유가 둘이었다.

- **메모 창** — 사진을 전폭으로 펼쳐 놓았는데 기본 창 크기(260×200)에서 그것이 메모를 통째로 잡아먹었다. 글은 두 줄만 남고 사진은 종이 밖으로 삐져 나갔다. `note-default.png` 렌더를 새로 떠서 확인했다.
- **빠른 입력** — 붙은 사진을 보여주는 자리가 **아예 없었다.** 본문의 `![](…)` 는 꾸밈이 감추므로 화면에서는 정말로 아무 일도 일어나지 않았다.

**③ ⌘V 가 죽을 수 있는 구조였다.** macOS 는 표준 편집 단축키를 메인 메뉴로만 응답 체인에 흘려보내고 그 단축키는 앱이 활성일 때만 산다. 그런데 빠른 입력 상자는 `.nonactivatingPanel` 이라, 활성화가 늦거나 거절되면 글자는 쳐지는데 ⌘V 만 죽는다.

## 해결 방법

**① 때를 말로 밝힌 시각은 날짜 없이도 읽는다.** `TimeParser.Result.isExplicit` 를 새로 두어 "오전·오후를 글이 직접 말했는가" 를 들고 다니게 하고, 날짜 낱말이 없으면 **다음에 오는 그 시각**으로 읽는다. 지난 시각이면 내일이다.

갈림길은 "어느 날인가" 가 아니라 **오전인가 오후인가** 로 잡았다 — `새벽`·`저녁`·`pm`·`15:` 는 글이 말했고, 맨 `3시` 의 24시간제 값은 우리가 관행으로 고른 것이다. 그래서 `3시에 전화` 는 **여전히 넘긴다** (기존 테스트 그대로 통과). 짐작 위에 짐작을 얹지 않는다.

달력에서 날을 골라 놓고 적는 자리는 갈라야 해서 `Result.namesDay` 를 함께 뒀다 — `오후 3시 치과` 는 고른 날이 이긴다.

**② 사진에 뚜껑을 씌우고 포인터를 올리면 원본 크기로 펼친다.**
- 메모 창: 사진 몫을 종이 높이의 40% 로(여러 장이면 다시 나눔) 제한하고 넘치면 잘라 보인다 (`PhotoStrip`).
- 빠른 입력: 작은 조각으로 "붙었다" 만 말한다 (`PhotoChip`·`PhotoChipRow`).
- 원본은 **펼쳐 볼 때만** 파일에서 다시 읽는다 — 화면에 든 것은 480px 썸네일이라 메모리 예산(§11)을 지킨다.
- 두 곳이 같은 `AttachedImage`·`AttachedImages` 를 쓴다.

**③ ⌘V·⌘C·⌘X·⌘A·⌘Z 를 `MemoNSTextView.performKeyEquivalent` 에서 직접 집는다.** 창의 `performKeyEquivalent` 는 메인 메뉴보다 먼저 불리므로 앱이 활성이든 아니든 같은 일이 일어난다. 메모 창도 같은 길을 타서 두 곳이 갈리지 않는다.

**④ 종이 투명도** (메뉴 → 설정, 네 단계). §14.5 의 "유리를 쓰지 않는다" 와 부딪히는 유일한 설정이라 셋으로 조였다 — 기본은 불투명, 바닥은 0.35, 그리고 **포인터가 오면 원래대로 진해진다** (철학 3 을 그대로 씀).

## 검증

- `./scripts/test.sh` — 199 tests / 32 suites 통과. 새 `DaylessTimeTests` 8건(때 낱말·지난 시각 롤오버·맨 시각은 여전히 침묵·고른 날 우선), `PaperAppearanceTests` 5건.
- `./scripts/render-ui.sh` — `note-default.png` 로 사진이 종이를 잡아먹던 것을 잡아냈고 고친 뒤 다시 확인. `capture.png` 에 사진 조각이 뜨는 것, `note-sheer.png` 로 50% 에서도 글이 읽히는 것을 눈으로 확인.
- `LAZYMEMO_MENU=1` — 설정 하위 메뉴가 3개 → 5개로 늘고 메뉴가 정상으로 지어진다.
- 붙여넣기 경로 자체는 스크래치 붙임판 probe 로 다섯 경우 전부 확인 (probe 는 확인 후 지웠다).

## 남은 것

`CalendarView.swift` 가 다른 손에 의해 고쳐지는 중이라 한때 호출부와 함수 서명이 어긋나 빌드가 깨졌다. 건드리지 않고 되돌려 두었고 지금은 통과한다.