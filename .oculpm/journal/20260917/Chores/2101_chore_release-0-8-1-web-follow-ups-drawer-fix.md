---
schema_version: 1
type: chore
slug: "release-0-8-1-web-follow-ups-drawer-fix"
status: done
difficulty: low
created_at: "2026-09-17T21:01:13+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
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
  - ref: "20260917/Chores/1847_chore_release-0-8-0-drawer-esc-widget-swipe.md"
    kind: "followup"
  - ref: "20260917/Bugs/2001_bug_drawer-drag-collapse-dismiss.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/2002_feature_web-answer-follow-ups-results-list.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "shared-worktree"
  - "mcp-tool"
---
[x] 0.8.1 배포 — 웹의 답 뒤 되물음·결과 카드, 맥 서랍 끌기·접힘·치우기: GitHub 판 + TestFlight 아이폰·맥

사용자: 「커밋해줘」→「배포해줘」. 0.8.0 (18:47) 두 시간 뒤의 같은 날 후속 판이라 patch 번호.

## 한 일

- 커밋 둘: `650ed2a feat(assistant)` (32 파일) · `1e54794 chore(release): 0.8.1` (README 「이번 판」·Info.plist 0.8.1 (13)·Version.swift).
- **공유 워킹트리에서 내 hunk 만**: `README.md`·UI `en.lproj/Localizable.strings`·`ios/LazyMemo/StackView.swift` 는 다른 세션의 미커밋 hunk 와 한 파일. `git diff` 를 hunk 단위로 골라(새 쪽 시작 줄은 빠진 hunk 만큼 되짚고, strings 는 hunk 안의 남의 줄 하나를 빼고 개수 재계산) `git apply --cached` 로 올렸다 — 0.8.0 때의 `hash-object`/`update-index` 대신. 남은 워킹트리 diff 가 남의 hunk 뿐임을 확인.
- 깨끗한 검출본(`git worktree add --detach <스크래치패드> HEAD`)에서 `./scripts/test.sh` 전체 초록(933) → 태그 `v0.8.1` + main 푸시 → `release` 워크플로 success(6m8s): `lazymemo-0.8.1.zip`(24.5MB) + sha256.
- TestFlight: 같은 worktree 에서 `ios/scripts/archive.sh` → 아이폰 `Upload succeeded`, `archive.sh mac` → 맥 `Upload succeeded`(iCloud·App Sandbox·LazyMemoAppStoreBuild ✓). dSYM 경고(CLiteRTLM)는 전과 같다.
- 정리: worktree(.build 982M + build 268M)와 DerivedData(733M) 삭제 → 프로젝트 1.9G.

## 검증

- 깨끗한 worktree 전체 단위 테스트 통과, release 워크플로 success(자산 둘), TestFlight 두 판 `Upload succeeded`.
- `git diff` 의 남은 hunk 가 다른 세션 것(README 2·strings 1·StackView 5)뿐임을 눈으로 확인.

## 메모

- 사람 눈 확인이 남은 것은 2001·2002 일지의 「검증」 참조 — 서랍 끌기·접힘, 실모델의 「정리해서 남기기」.
- App Store 심사 제출(`asc-submit`)은 이번에도 안 했다 — TestFlight 까지.