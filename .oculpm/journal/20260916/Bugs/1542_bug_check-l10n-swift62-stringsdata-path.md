---
schema_version: 1
type: bug
slug: "check-l10n-swift62-stringsdata-path"
status: done
difficulty: low
created_at: "2026-09-16T15:42:15+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/check-l10n.sh"
    op: update
related: []
tags:
  - "l10n"
  - "check-l10n"
  - "swift-6.2"
  - "build-system"
  - "gate"
  - "mcp-tool"
---
[x] check-l10n.sh 가 Swift 6.2 에서 열쇠 0개

## 발생 원인

Spotlight 모듈의 새 열쇠를 확인하려고 돌렸더니 **모든 모듈이 「코드 0 · 남음 N」** — 코드에서 열쇠를 하나도 못 뽑아 en 표 전부를 「남음」으로 잘못 보고했다. 조사: Swift 6.2 의 새 빌드 시스템은 `-Xswiftc -emit-localized-strings-path <dir>` 를 무시하고 `.stringsdata` 를 목적 파일 옆 — `<scratch>/out/Intermediates.noindex/LazyMemo.build/Debug/<타깃>-t.build/Objects-normal/arm64/` (라이브러리) 또는 `<제품>-p.build/…` (실행 파일) — 에 쓴다. 스크립트는 옛 자리 `$WORK/<타깃>/*.stringsdata` 만 봤다. 게이트가 조용히 통과하는 쪽으로 깨진 것이라 아무도 못 봤다(빠짐 0 으로 읽힌다).

## 해결 방법

`extracted()` 가 패턴 여럿을 받게 하고, 모듈마다 옛 자리 + `ANYWHERE = {work}/build/out/**/*.build/**/*.stringsdata` 둘을 본다. 어느 모듈의 것인지는 이미 있던 source prefix 필터(`/Sources/<모듈>/`)가 가른다 — 그래서 실행 파일(`lazymemo-mcp-p.build`)도 잡힌다. 경로 인자는 옛 툴체인을 위해 남겼다.

결과: Core 85/85 · MCP 61/61 · Reminders 30/30 · Spotlight 2/2 전부 맞음. **UI 에 빠짐 7** — `PreviewRenderer.swift` 의 소개 페이지 표본 문장 6개와 `QuickCaptureModel.swift:598` 「약속 시간이 언제인가요?」(어제 다른 세션의 대화형 일정 기능). 이 세션 것이 아니라 고치지 않고 적어 둔다. AssistantUI 는 코드 17 · en 61 — iOS 전용 파일의 열쇠가 맥 빌드에서 안 뽑히는 것으로 보인다(`--ios` 는 앱·확장만 본다), 후속.

## 검증

`./scripts/check-l10n.sh` 두 번 — 고치기 전 전 모듈 코드 0, 고친 뒤 위 숫자. 임시 scratch 에 `--target LazyMemoSpotlight` 만 지어 `find -name '*.stringsdata'` 로 실제 자리를 확인했다.