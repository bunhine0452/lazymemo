---
schema_version: 1
type: chore
slug: "release-0-5-0"
status: done
difficulty: medium
created_at: "2026-09-16T18:26:15+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Bugs/1613_bug_bundle-litert-engine-dylib.md"
    kind: "followup"
  - ref: "20260916/Bugs/1817_bug_resolver-ignores-request-timezone.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1522_feature_ci-on-push-and-pr.md"
    kind: "followup"
tags:
  - "release"
  - "0.5.0"
  - "ci"
  - "homebrew"
  - "git"
  - "mcp-tool"
---
[x] 0.5.0 배포

## 한 것

**커밋 여덟** — 워킹트리에 다른 세션의 미커밋 작업(9/15 의 한국어 복수형 고침·출시 준비 문서·자비스 명세·일지 스무 건)이 섞여 있었고, 내 Spotlight 코드가 그중 `Words.locale` 에 의존해 따로 갈 수 없었다. 전부 끝난 일(일지 done·시험 초록·9/15 mtime)이라 주제별로 나눠 명시 경로로 stage 했다(`git add -A` 금지):
1. `fix(l10n)` 「1 photos」— Words.locale (다른 세션 작업, 일지 포함)
2. `docs` 출시 준비 문서·자비스 명세·9/15 일지·플랜
3. `feat(spotlight)` + Package.swift 의 LiteRTLM product + check-l10n 고침
4. `chore(build)` 용량 다이어트·clean.sh·AGENTS/CLAUDE 규칙
5. `ci` ci.yml
6. `fix(release)` 엔진 dylib 번들 + 서명·공증 길
7. `chore(release): 0.5.0` — README 「이번 판」(0.4.0 뒤 49 커밋을 사람의 말로)·Info.plist 0.5.0(5)·Version.swift
8. `test(spotlight)` 가끔 빨갔던 지문 시험 · 9. `fix(assistant)` 요청 시간대 (아래)

**배포 전 손검증** — `dist/LazyMemo.app` 을 임시 vault(`LAZYMEMO_VAULT`)로 6초 띄워 살아 있고 `lsof` 에 `Contents/Frameworks/libCLiteRTLM_mac.dylib` 이 매핑된 것을 확인. 사용자의 lazymemo 와는 vault 가 달라 부딪히지 않았다.

**첫 CI 가 일을 했다.** main 을 밀자 UTC 러너(macOS 26.6.2·Swift 6.3.3)에서 `CommandResolverTests` 3건이 빨갔다 — 비서의 새 메모 경로가 요청의 시간대를 무시한 것(별도 일지). 고쳐 `TZ=UTC` 로도 837 통과시킨 뒤 초록을 보고 태그.

**태그 v0.5.0** → release.yml 3분 5초 성공: 시험 → 묶기(러너에서도 「엔진 포함: arm64 65M」) → 릴리스 생성(`lazymemo-0.5.0.zip` 23MB + sha256) → 홈브루 탭 `version "0.5.0"`·sha256 갱신. 서명·공증 시크릿이 없어 **ad-hoc(미공증)** — 요약에 ⚠️ 로 적혔다. 0.4.0 과 같은 상태.

## 검증

- 받는 사람의 자리에서: 릴리스 zip 을 내려받아 sha256 = 탭의 값(`8ce627d2…`), 풀어 `Contents/Frameworks/libCLiteRTLM_mac.dylib`(arm64) 있음, `codesign --verify --deep --strict` ✓, Info.plist 0.5.0, 70MB.
- `gh run view` — ci 35078589211 success, release 35078937207 success.

## 메모

- 스토어 판(macOS 0.4.0·iOS 0.1.0)은 Xcode 프로젝트의 MARKETING_VERSION 이라 이번 태그와 무관하다.
- 0.4.0 사용자에게는 메뉴의 「새 판 0.5.0 으로 바꾸기」가 뜬다 — UpdateInstaller 가 sha256·`codesign --deep --strict`·판 번호 셋을 본다. 첫 70MB 판이라 갈아 끼우는 데 전보다 오래 걸린다.
- 남은 것: 공증 시크릿 다섯 → 다음 태그가 첫 공증 판 → cask 의 `xattr` 삭제·README 미공증 문단 삭제.