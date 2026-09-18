---
schema_version: 1
type: bug
slug: "mac-photo-reference-always-hidden"
status: done
created_at: "2026-09-18T18:24:52+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MachineLines.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoUITests/PhotoPasteTypingTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MachineLinesTests.swift"
    op: update
related:
  - ref: "20260917/Bugs/2139_bug_mac-photo-reference-reappears-after-save.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/2140_feature_ios-hide-machine-lines-photo-remove.md"
    kind: "followup"
tags:
  - "mac"
  - "editor"
  - "photo"
  - "markdown-styler"
  - "mcp-tool"
---
[x] 맥에서 사진 참조 `![](attachments/…)` 가 커서 줄에서 드러났다 — 참조는 언제나 감추고, 커서는 못 들어가고, ⌫ 는 한 덩이로 뗀다

사용자(2026-09-18, 화면 첨부): 「사진 넣으면 텍스트 안 보이게 하라 했지? docx 에 사진 넣으면 텍스트 보이던?」 — 종이 둘째 줄에 `![](attachments/01M2….jpg` 가 작은 회색 글씨로 서 있었다.

## 발생 원인

`MarkdownStyler` 의 규칙 「기호는 커서가 놓인 줄에서만 보인다」가 사진 참조에도 적용됐다. 17일의 수정(끝 줄바꿈만 다른 본문은 되밀지 않기)은 **자동 저장이 커서를 그 줄로 보내는 길** 하나만 막았고, 사람이 글 끝을 누르면(참조가 마지막 줄일 때 늘 그렇다) 커서가 참조 줄에 서서 참조가 0.62×0.68 배 회색 고정폭으로 드러났다. 17일 일지의 메모 「커서를 손으로 그 줄에 두면 여전히 보인다 — 사진을 떼는 유일한 길이라 남긴다」가 곧 이 결함이었다.

## 해결 방법

- `MarkdownStyler.shouldHide` — `.image` 는 커서 줄과 무관하게 언제나 감춘다. `hideImageReferences`(빠른 입력)도 같다(`activeLine` 인자 제거). `.image` 의 작은 회색 꾸밈은 죽은 코드라 뺐다.
- `MemoTextEditor.Coordinator.textViewDidChangeSelection` — 커서가 참조 안에 들어오면 참조 뒤로 (`MachineLines.caret`, 폰과 같은 규칙; 선택 구간은 안 건드림). 감춘 글자(0.01pt) 뒤에 선 커서는 그 글꼴을 물려받아 조합 중의 한글이 안 보이므로 `typingAttributes` 를 바탕으로 되돌린다(`restyle` 뒤에도).
- `MemoNSTextView.deleteBackward/deleteForward` — ⌫·⌦ 가 참조에 닿으면 선택을 참조 전체로 넓힌 뒤 표준 지우기에 맡긴다 (`MachineLines.deletion(_:in:)`, 새 core 함수 — 참조만 보고 줄바꿈은 둔다: 첫 ⌫ 는 빈 줄, 둘째가 사진). 되돌리기가 그대로 이어진다. `deletesPhotoReferencesWhole` 은 참조를 감추는 편집기(꾸밈·빠른 입력)만 켠다.
- 떼는 길: `NoteView` 의 사진에 우클릭 메뉴 「사진 떼기」(+ 뒤에 종이 메뉴 그대로) → `NoteModel.removePhoto` (`flush` 뒤 `MachineLines.removingPhoto` → `store.update`). 영어 `Remove photo`.

## 검증

- 단위: `PhotoPasteTypingTests` 7건(붙인 뒤 감춤·되민 뒤에도 감춤+바탕 typingAttributes·커서 밀어내기·⌫ 두 번 순서와 되돌리기·⌦·`removePhoto`), `MachineLinesTests.deletion`. 전체 `swift test` 350+487 통과.
- 실기: 임시 vault 로 `LAZYMEMO_STAGE=1` 띄우고 합성 마우스·키보드로 — 참조 줄을 눌러도 참조가 안 보이고 사진은 아래에 서고, `ab` 를 치면 그 줄 왼쪽에 보이고, ⌫ 세 번에 `b`·`a`·참조(사진 사라짐), 파일은 `사진 메모`. 스크린샷 4장으로 확인.

## 메모

- 폰(`PaperTextView`)은 감춤·커서 규칙은 있지만 **⌫ 가 `)` 를 떼면 참조가 날것으로 드러나는 길이 그대로다** — `MachineLines.deletion` 을 `shouldChangeTextIn` 에 물리면 되나 시뮬레이터 검증이 필요해 이번엔 안 했다.
- 커밋하지 않았다 — 사용자가 시키면.