---
schema_version: 1
type: bug
slug: "mac-photo-reference-reappears-after-save"
status: done
difficulty: medium
created_at: "2026-09-17T21:39:37+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PhotoPasteTypingTests.swift"
    op: create
related:
  - ref: "20260829/Bugs/0227_bug_dawn-keyword-photo-paste-paper-opacity.md"
    kind: "followup"
  - ref: "20260828/Features_to_add/2040_feature_real-paper-markdown-photos-links.md"
    kind: "followup"
tags:
  - "mac"
  - "editor"
  - "photo"
  - "sync"
  - "mcp-tool"
---
[x] 맥에서 사진을 붙이면 잠시 뒤 `![](attachments/…)` 가 드러났다 — 파일이 끝 줄바꿈을 떼고 돌아와 커서가 그 줄로 튀었다

사용자: 「mac 에서 사진 붙여넣기 하면 사진만 보이게 해줘, `![](attachments/01M2….png)` 이게 보여」.

## 발생 원인

붙이는 순간은 멀쩡했다 — 시험으로 재현하니 참조는 0.01pt 로 감춰지고 다음 글자는 14pt 다. 문제는 그 뒤였다. 붙여넣기는 `\n![](경로)\n` 을 넣어 커서를 새 빈 줄에 둔다 → 600ms 뒤 자동 저장 → `VaultWatcher` 가 우리 쓰기를 보고 `reconcile` → `MemoFile.decode` 가 본문의 **끝 줄바꿈을 떼고** 읽는다 → `NoteModel.adopt` 가 「본문이 달라졌다」고 편집기에 되민다 → `MemoTextSync.apply` 가 커서를 글 끝으로 죄는데 그 끝이 곧 `![](…)` 줄 → 「커서가 든 줄은 기호를 보인다」는 규칙대로 참조가 작은 글씨로 드러난다. 재현 시험: 되민 뒤 참조의 글꼴이 5.9pt(0.62×0.68 배)로 살아났다.

## 해결 방법

`NoteModel.adopt` 가 앞뒤 줄바꿈만 다른 본문은 바뀐 것으로 치지 않는다 — 파일 형식이 만드는 차이지 사람이 고친 것이 아니다. `isDirty` 가 아닐 때만 보는 곳이라 저장 고리도 돌지 않는다(다음 편집에서 줄바꿈 든 글이 다시 저장되고 다시 무시된다).

## 검증

- `PhotoPasteTypingTests` 3건: 붙인 직후 참조는 숨고 친 글자는 보임 · 끝 줄바꿈이 잘린 본문을 되밀면 참조가 드러남(결함의 길을 그대로 고정) · `adopt` 가 그 차이를 무시하되 진짜 변경은 따라감. 전체 UI 시험 344 통과.

## 메모

- 커서를 손으로 그 줄에 두면 여전히 작은 글씨로 보인다 — 맥에서 사진을 떼는 유일한 길이라 그 규칙은 남긴다(`MarkdownStyler`).