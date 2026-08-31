---
schema_version: 1
type: feature
slug: "tidy-finished-memos-retreat"
status: done
difficulty: high
created_at: "2026-08-29T19:13:01+09:00"
session_id: "20260829-006"
agent:
  id: "claude-code"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Tidy.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/TidyRuleTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/TidySweepTests.swift"
    op: create
  - path: "scripts/verify-tidy.sh"
    op: create
  - path: "README.md"
    op: update
related: []
tags:
  - "tidy"
  - "philosophy-3"
  - "menu"
  - "core-rule"
  - "mcp-tool"
---
[x] 끝난 것이 스스로 물러난다 — 다 체크한 목록과 지난 일정을 숨김으로, 메뉴가 «치워 둔 N장» 이라 적는다

철학 3("오래된 것은 스스로 물러난다")이 코드에 없었다. 다 끝낸 장보기 목록과 지난주 약속이 바탕화면과 메뉴 목록을 계속 차지했고, 게으른 사람에게 그것은 붙여넣기 안 되는 것보다 빨리 앱을 버리게 만든다 — 정리하기 싫어서 쓰기 시작한 앱이므로.

## 추가 기능

**규칙 (`Tidy`, LazyMemoCore)** — 화면 없이 서고 시험으로 못 박힌다.

- **다 체크한 목록**: 칸이 하나 이상 있고 전부 체크됐으며, 마지막으로 손댄 지 **사흘**. 마지막 칸을 체크한 순간 사라지면 성취가 아니라 사고로 보인다.
- **지난 일정**: 적힌 날이 끝나고 **하루** 더. 다음 날 온종일 남아 있다가 그 다음 자정에 물러난다 — "어제 뭐 했더라" 가 되어야 한다.
- 손대지 않는 것 셋: 고정한 것, 이미 치운 것, 휴지통에 있는 것.
- 체크상자가 없는 메모는 영영 건드리지 않는다 — 끝났는지 앱이 알 길이 없다.

**저장 자리**: frontmatter `tidied:`. `layout.json` 이 아니라 파일에 두는 이유는 `deleted:` 와 같다 — 파생물에 두면 Application Support 를 지우는 것만으로 몇 달치 끝난 메모가 한꺼번에 바탕화면으로 되살아난다. 복원이 아니라 사고다.

## 동작 흐름

기동 시와 하루가 바뀔 때 `MemoStore.tidy` 가 돈다 (`DayClock` — 이미 있던 통로).

- `store.active` (치우지 않은 것)를 바탕화면·메뉴 목록·빠른 입력 「요즘 메모」가 본다.
- `store.memos` 는 그대로 둔다 — 지난 일정은 달력에 남아야 하고, 치웠다고 못 찾게 되면 그건 삭제다.
- 치울 때 `layout.json` 을 건드리지 않는다. 그래서 도로 꺼내면 종이가 **원래 있던 자리로** 돌아온다.

**되돌리는 길 둘** (`{#tidy-visible-undo}`):
1. 메뉴에 `치워 둔 2장 — 다 체크한 목록·지난 일정` + `도로 꺼내기` 한 줄. 왜 물러났는지를 낱말로 적는다 — 수만 적으면 무엇을 잃었는지 몰라 결국 눌러 봐야 한다.
2. 빠른 입력에서 찾아 열면 그 자리에서 풀린다 (`reveal`). 고쳐도 풀린다 (`MemoService.update`). 풀 때 `updated` 를 지금으로 찍는다 — 안 그러면 규칙이 다음 날 도로 치우고, 그건 사람 눈에 고장이다.

## 검증

`scripts/verify-tidy.sh` — 임시 Vault 에 세 장(열흘 전 다 체크한 목록 / 한 달 전 일정 / 칸이 남은 목록)을 놓고 실제 앱이 메뉴를 짓게 한다.

```
· 메모 1장
▪︎ 이사 준비
──────
· 치워 둔 2장 — 다 체크한 목록·지난 일정
· 도로 꺼내기
```

시험 330건 통과 (`TidyRuleTests` 경계 9건 + `TidySweepTests` 파일·목록 7건 신규). `verify-notes.sh`·`verify-capture-paste.sh` 도 함께 통과.