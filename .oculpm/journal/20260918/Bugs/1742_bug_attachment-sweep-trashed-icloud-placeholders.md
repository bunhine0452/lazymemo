---
schema_version: 1
type: bug
slug: "attachment-sweep-trashed-icloud-placeholders"
status: done
difficulty: low
created_at: "2026-09-18T17:42:37+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/AttachmentStore.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/AttachmentSweepTests.swift"
    op: update
related: []
tags:
  - "attachments"
  - "icloud"
  - "data-loss"
  - "bug-hunt"
  - "mcp-tool"
---
[x] 첨부 정리가 iCloud 자리표(.jpg.icloud)를 고아로 읽어 휴지통에 보냈다 — 숨은 파일은 보지 않는다

## 발생 원인

`AttachmentStore.orphans` 가 `contentsOfDirectory` 를 옵션 없이 불러 숨은 파일까지 셌다. iCloud 가 아직 안 내려받은 사진은 `.<ULID>.jpg.icloud` 자리표로 있고, 그 이름은 어느 본문의 `![](attachments/<ULID>.jpg)` 와도 맞지 않으니 고아로 읽혔다. 7일 유예(`attachmentGrace`)만 지나면 `discardOrphans` 가 `.trash/attachments/` 로 옮기고, 30일 뒤 `purgeTrashed` 가 지운다. 걸리는 경우: 맥의 「Mac 저장 공간 최적화」가 오래된 사진을 치워 둔 뒤, 폰이 그 메모를 한 번도 안 열어 사진을 안 내려받은 채 7일이 지난 뒤. 자리표를 옮기는 것은 iCloud 의 그 파일을 옮기는 것이라 다른 기기에서도 사진이 사라진다. `MemoVault.scan` 은 `.skipsHiddenFiles` 로 이미 자리표를 건너뛰고 있었고, 첨부만 어긋나 있었다.

## 해결 방법

`orphans` 에 `.skipsHiddenFiles`. 자리표는 그 사진의 진짜 파일을 가진 기기가 판단한다. (`.DS_Store` 도 더는 휴지통으로 안 간다.)

## 검증

- `AttachmentSweepTests.leavesCloudPlaceholdersAlone` 추가 — 400일 된 `.X.png.icloud` 를 두고 `store.tidy()` 뒤에도 그 자리에 있고 `orphans` 가 비어 있다.
- `swift test` 전부 통과.