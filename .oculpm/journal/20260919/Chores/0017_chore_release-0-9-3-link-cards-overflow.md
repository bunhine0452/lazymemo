---
schema_version: 1
type: chore
slug: "release-0-9-3-link-cards-overflow"
status: done
created_at: "2026-09-19T00:17:15+09:00"
session_id: "20260919-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "README.md"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
related:
  - ref: "20260919/Bugs/0012_bug_hangul-hidden-was-link-cards-eating-paper.md"
    kind: "followup"
  - ref: "20260918/Chores/2350_chore_release-0-9-2-capture-dismiss-tables.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "mcp-tool"
---
[x] 0.9.3 배포 — 링크 카드가 글을 먹지 않는다·더 있음 표시·출처는 링크로·표 폭: GitHub 판 + TestFlight 아이폰·맥

사용자: 「고쳤으면 0.9.3 으로 배포까지 해줘」.

## 한 일

- 커밋 `06362ce fix(paper)` · `0aec67e chore(release): 0.9.3`(README 「이번 판 — 0.9.3」, Info.plist 0.9.3 (20), Version.swift).
- 태그 `v0.9.3` → release 워크플로 success 한 번에: `lazymemo-0.9.3.zip`(24.8MB) + sha256, 홈브루 탭 갱신.
- TestFlight: 아이폰 `Upload succeeded`(00:15), 맥 `Upload succeeded`(00:15). worktree·DerivedData 삭제, `.build` 2.7G.

## 검증

- 배포 전 맥 전체 1057 초록, 폰 스모크 23/23, 사용자의 메모로 종이 캡처 확인.