---
schema_version: 1
type: chore
slug: "release-0-8-4-settings-drawer-phone"
status: done
difficulty: low
created_at: "2026-09-18T17:17:39+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
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
  - ref: "20260918/Bugs/1649_bug_drawer-performdrag-returns-immediately.md"
    kind: "followup"
  - ref: "20260918/Bugs/1650_bug_ios-litert-per-layer-embedding-null.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1651_feature_settings-window-grouped-form.md"
    kind: "followup"
  - ref: "20260918/Chores/0154_chore_release-0-8-3-other-session-work.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "mcp-tool"
---
[x] 0.8.4 배포 — 설정 창·서랍 끌기·폰 검색 오류: GitHub 판 + TestFlight 아이폰·맥

사용자: 「커밋하고 배포해줘」.

## 한 일

- 커밋 셋(명시 경로, 공유 파일은 `git apply --cached` 로 hunk 를 갈라): `1e95b6e fix(drawer)` · `92e0a2f fix(assistant)` 폰 entitlement·오류 말·웹 결과 유지 · `b76e007 feat(settings)` 설정 창.
- `2e60246 chore(release): 0.8.4` — README 「이번 판 — 0.8.4」 세 줄, Info.plist 0.8.4 (16), Version.swift. 태그 `v0.8.4` 푸시 → `release` 워크플로 success: `lazymemo-0.8.4.zip`(24.6MB) + sha256.
- TestFlight: 태그에서 detach 한 worktree(`../lazymemo-release`)에서 `archive.sh` → 아이폰 `Upload succeeded`(17:14), `archive.sh mac` → 맥 `Upload succeeded`(17:16). 아이폰 아카이브의 서명에 `extended-virtual-addressing`·`increased-memory-limit` 둘 다 실린 것을 `codesign -d --entitlements` 로 확인. dSYM 경고(CLiteRTLM)는 전과 같다.
- 정리: worktree(build 270M)와 그 DerivedData(741M), 그리고 어제 세션이 남긴 고아 DerivedData(738M, 지워진 스크래치 worktree 것) 삭제 → 프로젝트 2.2G.

## 검증

- 배포 전 전체 시험 956 초록, 아이폰 기기 빌드 ✓. release 워크플로 success(자산 둘), TestFlight 두 판 `Upload succeeded`.

## 메모

- 폰 판의 요점(층별 임베딩 mmap)은 **실기기에서만** 확인된다 — 이 TestFlight 판을 아이폰에 올리고 웹에서 찾기·메모 묻기, 그리고 앱을 한참 쓴 뒤 다시 한 번. App Store 심사 제출은 이번에도 안 했다.
- `archive.sh` 는 여전히 홈의 DerivedData 를 쓴다(용량 규칙 3 과 어긋남) — 다음에 `-derivedDataPath` 를 주면 정리가 한 줄 준다.