---
schema_version: 1
type: bug
slug: "frontmatter-quoted-value-roundtrip-backslash"
status: done
difficulty: verylow
created_at: "2026-09-18T17:42:54+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Frontmatter.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoFileTests.swift"
    op: update
related: []
tags:
  - "frontmatter"
  - "roundtrip"
  - "bug-hunt"
  - "mcp-tool"
---
[x] frontmatter 의 따옴표 든 값이 왕복마다 역빗금을 얻었다 — 벗길 때 \" 를 되돌린다, 앞이 ' 인 값은 감싼다

## 발생 원인

`Frontmatter.quoteIfNeeded` 는 감쌀 때 안의 `"` 를 `\"` 로 적는데 `unquote` 는 바깥 따옴표만 벗기고 `\"` 를 되돌리지 않았다. `place: "봄" 카페` 는 첫 글자가 `"` 라 감싸져 `"\"봄\" 카페"` 로 적히고, 읽으면 `\"봄\" 카페` — 한 번 저장할 때마다 역빗금이 남았다(둘째 왕복부터는 안 감싸져 그대로 굳는다). `카페: "봄"` 처럼 `: ` 때문에 감싸지는 값도 같다. 별개로, `'봄'` 처럼 작은따옴표로 시작·끝나는 값은 감싸지 않고 적혀 읽을 때 따옴표가 벗겨졌다.

## 해결 방법

- `unquote`: 큰따옴표로 감싼 값 안의 `\"` → `"`. 작성기는 `"` 만 이스케이프하므로 그것만 되돌린다 — 역빗금 자체는 건드리지 않아 `역빗금 \ 그대로`·`a\"b` 도 왕복한다.
- `quoteIfNeeded`: 첫 글자가 `'` 이면 감싼다.

## 검증

- `MemoFileTests.roundTripsQuotedValues` — `"봄" 카페`·`카페: "봄"`·`@"집"`·`역빗금 \ 그대로`·`a\"b`·`'봄'`·`"` 를 두 번 왕복해 같음.
- `swift test` 전부 통과.