---
schema_version: 1
type: bug
slug: "mac-note-autosave-drops-keystrokes-mid-write"
status: done
difficulty: low
created_at: "2026-09-18T17:42:21+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteSaveFailureTests.swift"
    op: update
related:
  - ref: "20260917/Bugs/2139_bug_mac-photo-reference-reappears-after-save.md"
    kind: "followup"
tags:
  - "autosave"
  - "note"
  - "data-loss"
  - "bug-hunt"
  - "mcp-tool"
---
[x] 맥 종이 — 파일에 쓰는 사이에 친 글자가 안 적혔다 (돌아온 저장이 dirty 표시를 지웠다)

## 발생 원인

`NoteModel.persistBody` 가 `await store.update(memo.id, body: text)` 에서 actor 를 건너가는 사이(파일 쓰기)에 사람이 한 글자를 더 치면 `edited` 가 `isDirty = true` 로 두고 600ms 저장을 다시 잰다. 그런데 첫 저장이 돌아오며 무조건 `isDirty = false` 로 지웠다. 다시 잰 저장은 `guard isDirty` 에서 「적을 것 없음」으로 돌아가고, 그 뒤 손이 멈추면 마지막 글자(들)는 다음 타건까지 어디에도 안 적힌다 — 그 채로 창을 닫으면 `flush` 도 dirty 가 아니라 안 쓴다. 폰의 `MemoEditorView.save` 는 `lastSaved = body`(보낸 글)로 비교해서 이 문제가 없었다.

## 해결 방법

보낸 글(`saving`)을 잡아 두고, 돌아온 뒤 `text == saving` 일 때만 dirty·unsaved 표시를 지운다. 다르면 표시를 그대로 두어 `edited` 가 잰 다음 저장이 맡는다.

## 검증

- `NoteSaveFailureTests.keystrokesDuringWriteAreNotLost` 추가 — `flush()` 를 Task 로 띄우고 `Task.yield()` 뒤 한 글자 더 친 다음 다시 flush: 고치기 전 「치」만 적히고 「치과」가 안 적히는 것을 재현(실패 확인) → 고친 뒤 통과, 5회 반복 통과.
- `swift test` 전부 통과.