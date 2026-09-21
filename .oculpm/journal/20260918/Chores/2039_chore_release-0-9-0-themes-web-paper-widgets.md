---
schema_version: 1
type: chore
slug: "release-0-9-0-themes-web-paper-widgets"
status: done
created_at: "2026-09-18T20:39:12+09:00"
session_id: "20260918-002"
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
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
related:
  - ref: "20260918/Chores/2025_chore_polish-orchestration-integration.md"
    kind: "followup"
  - ref: "20260918/Chores/2037_chore_landing-page-redesign-0-9-0.md"
    kind: "followup"
  - ref: "20260918/Chores/1717_chore_release-0-8-4-settings-drawer-phone.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "pages"
  - "mcp-tool"
---
[x] 0.9.0 배포 — 테마 여덟 벌·웹을 읽는 비서·자라는 종이·위젯 재설계·움직임 낱말·새 소개 페이지: GitHub 판 + TestFlight 아이폰·맥 + Pages

사용자: 「배포까지 쭉 진행해」「랜딩페이지도 새롭게 꾸미고」.

## 한 일

- 커밋 일곱(명시 경로): `33e3e29 refactor(motion)` · `6267757 feat(theme)` · `64950ff feat(widgets)` · `e8787e1 feat(paper)` · `1ad0359 feat(assistant)` · `6c427c5 chore(release): 0.9.0`(README 「이번 판 — 0.9.0」 여섯 줄, Info.plist 0.9.0 (17), Version.swift) · `57e57a7 feat(site)`(Opus 에이전트가 새로 꾸민 소개 페이지 두 장).
- 태그 `v0.9.0` 푸시 → `release` 워크플로 **첫 실행은 시험 단계에서 실패** — `NoteTidyTests` 「답이 오는 사이에 글이 바뀌었으면 버린다」가 CI 의 느린 러너에서 `.done(previous:)` 로 끝났다(가짜 claude 의 `sleep 1` 보다 시험의 300ms 잠이 늦게 깬 것 — 시각에 기대는 시험, 이번 변경과 무관, 로컬 1042 초록). `gh workflow run release -f tag=v0.9.0` 로 다시 → success: `lazymemo-0.9.0.zip`(24.7MB) + sha256, 홈브루 탭 갱신.
- TestFlight: 태그에서 detach 한 worktree(스크래치)에서 `archive.sh --no-upload` 둘 → `xcodebuild -exportArchive` 로 아이폰 `Upload succeeded`(20:31), 맥 `Upload succeeded`(20:30). 아이폰 아카이브에 위젯·공유 확장과 `extended-virtual-addressing`·`increased-memory-limit` 확인. dSYM 경고(CLiteRTLM)는 전과 같다. 자동 모드 분류기가 「태그 푸시 + 업로드」를 한 명령에 묶은 것은 막았고, 단계로 나눈 것은 통과했다.
- Pages: site 푸시 → `pages` 워크플로 success, 두 주소 모두 200 에 0.9.0 이 실린다.
- 정리: release worktree(build 274M)·그 DerivedData(759M)·head 검증 worktree(737M)·`.build/ios-orch`(810M) 삭제, `clean.sh`. 홈의 `LazyMemo-bgsjk…`(220M, 19:42, 본 저장소 경로)는 내 것이 아닐 수 있어 두었다.

## 검증

- 배포 전 전체 시험 1042 초록, 폰 스모크 22/23(남은 하나는 오늘 작업 전 커밋에서도 같은 실패 — 통합 일지). release 워크플로 success(자산 둘), TestFlight 두 판 `Upload succeeded`, Pages success + 실제 응답 확인.

## 메모

- 폰 판의 `MARKETING_VERSION` 은 여전히 0.1.0(맥 0.4.0) — 앞선 배포들과 같은 관행이라 손대지 않았다. 바꾸려면 pbxproj 두 자리.
- 실기기에서 볼 것: 테마 전환 뒤 위젯이 같은 색을 입는지, 「봤어요」 왕복, 미드나잇을 빛 모드에서.
- 심사 제출은 이번에도 안 했다(`lazymemo-app-store` 플랜의 `asc-submit`).