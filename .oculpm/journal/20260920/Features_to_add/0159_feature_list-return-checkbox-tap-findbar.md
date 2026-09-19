---
schema_version: 1
type: feature
slug: "list-return-checkbox-tap-findbar"
status: done
difficulty: medium
created_at: "2026-09-20T01:59:09+09:00"
session_id: "20260920-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/ListEditing.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/ListEditingTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoTitleTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecallTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/ListReturnTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/FindBarTests.swift"
    op: create
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related: []
tags:
  - "editor"
  - "mac"
  - "ios"
  - "checklist"
  - "find"
  - "core"
  - "mcp-tool"
---
[x] 메모 앱 기본기 — 목록 줄의 ⏎ 가 머리를 잇고(맥·폰), 폰 체크상자는 눌러 뒤집고, 종이에 ⌘F 찾기 줄

## 추가 기능

- **`LazyMemoCore/ListEditing`** — 규칙 한 곳, 편집기 둘. `onReturn(in:selection:)` 은 `- `·`- [ ] `·`1. `·`> ` 줄의 ⏎ 에 다음 줄 머리(체크상자는 빈 것, 번호는 +1, 들여쓰기·`*`/`+` 모양은 사람이 쓴 그대로)를 내놓고, 머리만 남은 빈 항목의 ⏎ 는 머리를 떼는 바꿈을 내놓는다(목록에서 나온다). 머리 **안**의 ⏎ 는 nil(그냥 줄바꿈 — 항목을 밀어 내리는 손). 머리 뒤 빈칸은 하나만 머리로 친다. `toggleCheckbox(inLineContaining:in:)` 은 괄호 안 한 글자만 뒤집는 바꿈. 글자를 어떻게 바꿀지만 계산하고 바꾸는 것은 편집기 — 되돌리기·조합 상태가 편집기의 것으로 이어진다.
- **맥** `MemoNSTextView.insertNewline` 오버라이드 — 조합 중이면 손대지 않고, 규칙이 있으면 `insertText(_:replacementRange:)`(되돌리기 한 걸음). 빠른 입력이 ⏎ 를 가로채고 싶으면 `doCommandBy` 가 먼저라 그대로다.
- **맥 ⌘F** — 배선(`StandardMenu` 「찾기」)만 있고 `usesFindBar` 가 꺼져 있어 아무것도 안 서던 자리. `MemoTextEditor.findable`(종이만 켠다, `NoteView`) 이 `usesFindBar`·`isIncrementalSearchingEnabled` 를 켜고, `MemoNSTextView.perform` 이 ⌘F 를 메인 메뉴 없이 직접 받아 `performFindPanelAction(showFindInterface)` — 빠른 입력(findable 아님)에서는 받지 않아 상자 높이 셈이 흔들리지 않는다.
- **폰** `PaperTextView` — `shouldChangeTextIn` 이 `"\n"` 을 받으면 같은 규칙으로 잇거나 뗀다(선택을 그 자리에 두고 `insertText`/`deleteBackward` — 사진 참조 지우기와 같은 길). 체크상자 머리 `- [ ] ` 에 `.textItemTag` 를 붙여 누를 수 있는 글 조각으로 — `primaryActionFor` 가 **키보드가 내려가 있을 때만** 뒤집고(적는 중의 누르기는 커서를 놓는 손), 길게 눌러도 메뉴 없음. 폰은 마크다운을 꾸미지 않으므로 `- [ ]` 원문이 그대로 보이되 누르면 `[x]` 로.
- **제목** `Memo.textLines` 가 체크상자 괄호를 뗀다 — 「- [ ] 우유」의 제목은 「우유」(목록 줄·알림·Spotlight 전부). `RecallTests` 의 「[x] 우유」 기대값을 「우유」로.

## 동작 흐름

1. 종이(맥)·펜/종이(폰)에서 `- [ ] 우유` 를 치고 ⏎ → 다음 줄 `- [ ] ` 위에 커서. 더 적을 것이 없어 ⏎ 를 한 번 더 → 머리가 떨어져 빈 줄. 줄 가운데의 ⏎ 는 항목을 둘로 가른다.
2. 폰에서 메모를 열면 키보드는 내려가 있다(원래 규칙) → `- [ ]` 를 누르면 `[x]`, 600ms 뒤 파일에 적힌다. 글 어디든 눌러 키보드가 올라온 뒤에는 누르기가 커서를 놓는다.
3. 맥 종이에서 ⌘F → 찾기 줄이 스크롤 뷰 머리에 서고 치는 대로 짚는다. esc 로 접는다.

## 검증

- `ListEditingTests` 9(규칙), `ListReturnTests` 5(진짜 `MemoNSTextView` 에 `insertNewline` — 잇기·커서 자리·빈 머리 떼기·되돌리기 한 걸음·조합 중 무간섭), `FindBarTests` 2(⌘F 이벤트로 `isFindBarVisible`, findable 아니면 안 받음), `MemoTitleTests` 체크상자 제목. 전체 `./scripts/test.sh` 초록(1081).
- 폰 시뮬레이터(iPhone 17) `SmokeTests.testReturnContinuesTheChecklist`(줄 끝 탭 → `\n계란` → 파일에 `- [ ] 우유\n- [ ] 계란`) · `testTappingACheckboxTogglesIt`(머리 탭 → `- [x] 우유`, 키보드 안 올라옴, 다시 탭 → `- [ ]`) 둘 초록, 기존 `testBackspaceRemovesAPhotoWhole` 초록.
- 맥의 찾기 줄이 실제 종이 위에서 어떻게 보이는지는 손으로 안 봤다 — 상태 값만.

## 메모

- 시험을 쓰며 「- [ ] 우유」를 9자로 잘못 세어(6+2=8) 커서가 한 칸 어긋난 것으로 오해했다 — `insertText` 는 커서를 제대로 둔다. 명시적 `setSelectedRange` 는 넣지 않았다.
- Tab 들여쓰기(중첩 목록)는 두지 않았다 — 스캐너가 들여쓴 머리를 같은 여백에 그려 화면이 구분하지 못한다. 필요해지면 `LineMarker.gutter` 를 들여쓰기에 비례시키는 것이 먼저다.