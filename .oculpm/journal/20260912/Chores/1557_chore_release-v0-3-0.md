---
schema_version: 1
type: chore
slug: "release-v0-3-0"
status: done
difficulty: medium
created_at: "2026-09-12T15:57:25+09:00"
session_id: "20260912-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
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
  - ref: "20260901/Chores/1237_chore_release-v0-2-0.md"
    kind: "followup"
  - ref: "20260912/Refactors/1535_refactor_cream-forest-visual-redesign.md"
    kind: "followup"
  - ref: "20260912/Features_to_add/1545_feature_interactive-first-launch-tutorial.md"
    kind: "followup"
tags:
  - "release"
  - "ci"
  - "homebrew"
  - "readme"
  - "mcp-tool"
---
[x] v0.3.0 배포 — 9/1·9/12 의 미커밋 몸통을 한 판으로 내보내고 리드미를 새로 쓴다

## 동기

v0.2.0 이후 두 물결의 작업(9/1 Tahoe 아이콘·서랍 찾기/키보드/여러 장 고르기, 9/12 크림·포레스트 개편·4단계 튜토리얼·빠른 입력 개편·App Store 판 갈이 차단)이 전부 워킹트리에만 있었다. 사용자가 스냅샷·리드미·배포를 한 번에 요청했다.

## 변경 요약

- `cce8e55` 몸통 — 새 파일 8개 포함, 명시 경로로만 stage (`git add -A` 금지 규칙). `.oculpm/agents/_template.md.bak` 은 뺐다
- `1363487` 판 올리기 — Info.plist 0.2.0 → 0.3.0 (CFBundleVersion 2 → 3), Version.swift, README 전면 재작성
- README: 「이번 판」 요약 절, 「처음 켜면」(튜토리얼 4단계 표), 달력·서랍 조작표, 깔린 길(직접·brew·App Store·개발)에 따른 판 갈이 표, 「크림과 포레스트」 디자인 절(VISUAL_DESIGN.md 링크), 배포 절차. 옛 손그림 달력·클립 아이콘 서술은 걷어냈다. 코드에 없는 주장 둘(31일 이동 확인 대화, Reduce Motion 범위)은 grep 으로 잡아 고쳤다
- 태그 `v0.3.0` 푸시 → 릴리스 워크플로 `34679337641`

## 검증

배포 전: `scripts/test.sh` 649개/98 스위트 통과, `package-release.sh` 로컬 성공(번들 3.6MB, zip 1.6MB, 서명 재검사 통과). 배포 후: 워크플로 초록(탭 갱신 단계 성공 = 「못 갱신했다」 skipped). 나간 바이트를 직접 받아 확인 — sha256 `7ad1ac99…` 이 자산 `.sha256` 과 탭 cask 값 모두와 일치, `codesign --verify --deep --strict` 통과, 번들·`lazymemo-mcp --version` 모두 0.3.0. pages 워크플로는 site/ 변경이 없어 돌지 않았다.