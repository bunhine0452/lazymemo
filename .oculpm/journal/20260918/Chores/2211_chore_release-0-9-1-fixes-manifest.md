---
schema_version: 1
type: chore
slug: "release-0-9-1-fixes-manifest"
status: done
created_at: "2026-09-18T22:11:38+09:00"
session_id: "20260918-003"
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
  - ref: "20260918/Bugs/2207_bug_app-look-long-memo-top-tables-manifest.md"
    kind: "followup"
  - ref: "20260918/Chores/2039_chore_release-0-9-0-themes-web-paper-widgets.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "mcp-tool"
---
[x] 0.9.1 배포 — 긴 메모 첫 줄부터·표·개인정보 매니페스트: GitHub 판 + TestFlight 아이폰·맥

## 한 일

- 커밋 여섯: `d6e1ae8 fix(paper)` · `90ebbe9 feat(editor)` 표 · `05ceaf0 chore(store)` 매니페스트 · `716e857 chore(perf)` footprint · `test(ios)` 날짜·키보드 · `a49a910 chore(release): 0.9.1`(README 「이번 판 — 0.9.1」, Info.plist 0.9.1 (18), Version.swift).
- 태그 `v0.9.1` → release 워크플로 success 한 번에: `lazymemo-0.9.1.zip`(24.7MB) + sha256, 홈브루 탭 갱신.
- TestFlight: 태그의 detach worktree 에서 `archive.sh --no-upload` 둘 → `-exportArchive` 로 아이폰 `Upload succeeded`(22:11), 맥 `Upload succeeded`(22:10). 두 아카이브 모두 앱·appex 에 `PrivacyInfo.xcprivacy` 실림 확인.
- 정리: worktree·DerivedData(759M)·`.build/ios-look`(878M)·render PNG 삭제, `clean.sh`.

## 검증

- 배포 전: 맥 UITests 377·스캐너 29 초록, 폰 스모크 23/23, `verify-performance.sh` ✓. release 워크플로 success, TestFlight 둘 `Upload succeeded`.

## 메모

- 심사 제출(「심사에 추가」)은 하지 않았다 — 사람 손검증 항목(`docs/APP_STORE_READINESS.md` 의 맥·아이폰 체크리스트, 플랜 `mac-sandbox-handtest`)이 남아 있고, ASC 의 두 버전 페이지에 이 빌드(0.9.1 = iOS 0.1.0·macOS 0.4.0 판 번호)를 붙이는 것도 ASC 웹에서 해야 한다.