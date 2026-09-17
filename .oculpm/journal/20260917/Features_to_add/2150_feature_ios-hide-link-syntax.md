---
schema_version: 1
type: feature
slug: "ios-hide-link-syntax"
status: done
difficulty: low
created_at: "2026-09-17T21:50:18+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MachineLines.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MachineLinesTests.swift"
    op: update
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
related:
  - ref: "20260917/Features_to_add/2140_feature_ios-hide-machine-lines-photo-remove.md"
    kind: "followup"
tags:
  - "ios"
  - "editor"
  - "link"
  - "ux"
  - "mcp-tool"
---
[x] 폰의 글 칸이 링크의 기호도 감춘다 — `[이름](주소)` 는 이름만, 강조색으로

사용자: 「이것도 당연히 감춰야지」 — 맥에서 붙인 `[map.naver.com/2040338336](https://map.naver.com/p/entry/place/…)` 가 폰에서 날것으로 보이던 것.

## 추가 기능

- `MachineLines.Kind.linkSyntax` — 링크 구간 안에 든 `.syntax` 구간(`[` 와 `](주소)`)만. `#`·`**`·`> ` 같은 다른 기호는 그대로(폰은 마크다운을 꾸미지 않는다는 원칙). 맨 주소(`https://…`)는 이름이 없으니 그대로 보인다.
- 커서 규칙은 사진 참조와 같다 — 기호 안이면 뒤로. 이름 끝(기호 앞)은 밖이라 거기서 치면 이름에 붙는다.
- `PaperTextView` 가 링크 구간을 강조색(`Theme.accentInk`)으로 — 감춰진 기호가 있다는 힌트. 적는 칸이라 눌러서 열지는 않는다.

## 동작 흐름

메모 열기 → 첫 줄이 「map.naver.com/2040338336 점심 약속」(이름은 강조색) → 목록의 줄도 같은 제목(`Memo.title`, 같은 날 `2138`).

## 검증

- `MachineLinesTests.linkSyntax` 신규 — 기호 두 구간·커서 뒤로·이름 끝 유지. 전체 8건 통과.
- `testMachineLinesAreHiddenAndTypingLandsBeforeTheRoute` 의 씨앗 첫 줄을 그 링크로 바꿔 통과 — 목록 줄이 「map.naver.com/2040338336 점심 약속」으로 시작, 스크린샷 `/tmp/lazymemo-machine-lines.png` 에서 기호 없이 이름만 확인.