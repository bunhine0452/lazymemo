---
schema_version: 1
type: chore
slug: "release-0-8-0-drawer-esc-widget-swipe"
status: done
difficulty: low
created_at: "2026-09-17T18:47:16+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
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
  - ref: "20260917/Features_to_add/1635_feature_drawer-one-gesture-summon-bigger.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1626_feature_note-escape-puts-away.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1621_feature_calendar-widget-month-grid.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1700_feature_phone-calendar-swipe-motion.md"
    kind: "followup"
  - ref: "20260916/Chores/2138_chore_drop-odsay-redo-demo-0-6-1.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "shared-worktree"
  - "mcp-tool"
---
[x] 0.8.0 배포 — 서랍 한 손짓·Esc 치우기·달력 위젯·폰 달력 스와이프, GitHub 판 + TestFlight 아이폰·맥

사용자: 「커밋하고 배포해줘」.

## 한 일

- 커밋 둘: `e09f4df feat(ux)` (네 갈래 코드·문서·일지 5건) · `e8f799f chore(release): 0.8.0` (README 「이번 판」·Info.plist 0.8.0 (12)·Version.swift). 이번 판 노트에는 같은 태그에 실리는 다른 세션의 「웹에서 찾기」(d9b490d)도 한 줄 넣었다.
- **공유 워킹트리에서 내 hunk 만 담기**: README·UI en strings·MOBILE_DESIGN 은 다른 세션(lazymemo-5a)의 미커밋 hunk 와 한 파일에 섞여 있었다. `git add -p` 는 대화형이라 못 쓰므로, HEAD 내용에 내 변경만 다시 적용한 파일을 `git hash-object -w` → `git update-index --cacheinfo` 로 index 에 직접 올렸다. 워킹트리와 index 의 diff 가 남의 hunk(4+1+1)뿐인 것을 확인하고 커밋. 남의 파일(Package.swift·AppDelegate·NoteWindowManager·Reminders·폰 화면 다섯·UITests)은 stage 하지 않았다.
- **배포 전 검증은 깨끗한 검출본에서**: `git worktree add --detach <스크래치패드> HEAD` 로 뽑아 `./scripts/test.sh` 전체 초록 — 다른 세션의 미커밋 코드 없이도 서는 것을 확인한 뒤 태그.
- 태그 `v0.8.0` 푸시 → `release` 워크플로 성공(4m57s): `lazymemo-0.8.0.zip` + sha256, 홈브루 탭.
- TestFlight: 같은 worktree(v0.8.0 검출본)에서 `ios/scripts/archive.sh` → 아이폰 `Upload succeeded`, `archive.sh mac` → 맥 `Upload succeeded`. 미커밋 변경이 아카이브에 섞이지 않는다. dSYM 경고(CLiteRTLM 벤더 바이너리)는 전과 같다.
- 정리: worktree(.build 977M + build 266M)와 그 DerivedData(726M) 삭제. 프로젝트 `.build` 는 다른 세션이 이미 `clean.sh --all` 로 비웠다.

## 검증

- 깨끗한 worktree 에서 전체 단위 테스트 통과, release 워크플로 success, TestFlight 두 판 업로드 succeeded.
- `git diff README.md` 에 남은 것이 다른 세션의 4 hunk 뿐임을 눈으로 확인.

## 메모

- 폰 실기기 확인 항목은 각 기능 일지의 「사람 눈 확인」 참조.
- App Store 심사 제출(`asc-submit`)은 이번에도 하지 않았다 — TestFlight 까지.