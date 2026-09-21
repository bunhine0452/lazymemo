---
schema_version: 1
type: chore
slug: "release-0-9-2-capture-dismiss-tables"
status: done
created_at: "2026-09-18T23:50:54+09:00"
session_id: "20260918-004"
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
  - ref: "20260918/Bugs/2345_bug_table-columns-kern-and-hangul-probe.md"
    kind: "followup"
  - ref: "20260918/Chores/2211_chore_release-0-9-1-fixes-manifest.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "mcp-tool"
---
[x] 0.9.2 배포 — 웹의 답이 물러난다·esc 한 겹씩·표의 열 맞춤: GitHub 판 + TestFlight 아이폰·맥

## 한 일

- 커밋: `4eccc2e feat(editor)` 표 열 맞춤 + 한글 회귀 시험 · `3b52841 fix(capture)`(Opus 에이전트 — 남기면 물러남·esc 세 겹·닫으면 reset·아이러니 넷) · `3d59d04 fix(ios)` 펜 세 줄 · `1f67ef5 chore(release): 0.9.2`.
- 태그 `v0.9.2` → release 워크플로 success 한 번에: `lazymemo-0.9.2.zip`(24.8MB) + sha256, 홈브루 탭 갱신.
- TestFlight: 태그 worktree 에서 아카이브 둘 → 아이폰 `Upload succeeded`(23:48), 맥 `Upload succeeded`(23:47). worktree·DerivedData 삭제.

## 검증

- 맥 전체 1057 초록, 폰 스모크 23/23, `check-l10n.sh` 새 빠짐 0(남은 23 은 HEAD 에 원래 있던 견본 문장).

## 메모

- 「한글이 가끔 안 보인다」는 이번 판에 안 들어갔다 — 재현 못 함. 사용자에게 화면·메모·되살리는 손짓을 묻는다.