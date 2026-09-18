---
schema_version: 1
type: bug
slug: "vault-modify-duplicated-moved-file"
status: done
difficulty: low
created_at: "2026-09-18T17:43:10+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoVaultTests.swift"
    op: update
related: []
tags:
  - "vault"
  - "storage"
  - "bug-hunt"
  - "mcp-tool"
---
[x] Finder 로 다른 폴더에 옮긴 메모 파일을 고치면 규격 자리에 하나 더 생겨 목록에 둘로 섰다 — 찾은 자리에 되쓴다

## 발생 원인

`MemoVault.locate` 는 규격 자리(`notes/YYYY/MM/<ulid>.md`)에 없으면 `notes/` 를 훑어 찾는다(사람이 옮겼을 수 있다고 주석까지 있다). 그런데 `modify` 와 `MemoService.update` 는 찾아 읽은 뒤 `save(memo)` 로 **규격 자리에** 새로 썼다. 옮겨 둔 원본은 그대로 남아 같은 id 의 파일이 둘 — `loadAll` 이 둘 다 돌려주니 메뉴 목록·서랍에 같은 메모가 두 줄, 이후 고치기는 규격 자리 쪽만 바뀌어 둘의 글이 어긋난다.

## 해결 방법

- `MemoVault.save(_:at:)` — 자리를 받으면 거기 쓴다. `modify` 는 `locate` 가 찾은 자리를 넘긴다.
- `MemoService.update` 를 `vault.modify` 위에 올렸다 — 읽고 고치고 쓰기가 vault 의 한 호출 안에서(사이에 `await` 없음) 끝나고, 같은 자리에 되쓴다. `restore`·`adopt` 는 규격 자리가 맞으므로 그대로.

## 검증

- `MemoVaultTests.modifiesMovedFileInPlace` — `notes/2020/01/` 로 옮긴 파일을 `modify` 한 뒤 `loadAll` 이 1개, 규격 자리에 파일이 없다.
- `swift test` 전부 통과 (`MemoServiceTests`·`MemoServiceModifyTests`·`MemoStoreTests` 포함).