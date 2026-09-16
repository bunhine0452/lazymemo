---
schema_version: 1
type: chore
slug: "footprint-rules-for-all-sessions"
status: done
difficulty: verylow
created_at: "2026-09-16T15:22:16+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "AGENTS.md"
    op: update
  - path: "CLAUDE.md"
    op: create
related:
  - ref: "20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md"
    kind: "followup"
tags:
  - "footprint"
  - "agents-md"
  - "guideline"
  - "multi-session"
  - "mcp-tool"
---
[x] 용량 규칙을 모든 세션이 읽는 지침으로

## 왜

7.1GB 를 82MB 로 줄인 직후에도 다른 세션이 `.build/ios`(600MB)를 두 번 다시 만들었다 — 지우는 것만으로는 다음 주에 같은 자리다. 규칙이 사람 하나의 기억이 아니라 **세션이 시작할 때 읽는 파일**에 있어야 한다.

## 어디에

- **`AGENTS.md`** — oculpm managed block(`<!-- oculpm:end -->`) **뒤**에 「용량 규칙 — 파생물은 쌓이지 않게」 7조. Codex 와 다른 에이전트가 이 파일을 읽는다. managed block 은 플러그인이 갈아 끼우므로 그 안에는 넣지 않았다.
- **`CLAUDE.md`(신설, 루트)** — 본문은 세 줄. `@AGENTS.md` 로 들여와 Claude Code 세션도 같은 규칙을 읽는다. 규칙은 한 곳(AGENTS.md)에만 두고 이 파일은 고치지 않는다고 적었다.

## 7조 요지

1. 저장소를 클론하는 의존 금지 — vendored `LiteRTLM` 을 path 로. 새 패키지는 `.build/repositories` 500MB 넘으면 멈추고 말한다.
2. 가중치는 `~/Library/Caches/lazymemo-models/` 한 자리 한 파일. snapshot 금지. `clean.sh` 도 안 지운다.
3. xcodebuild derivedDataPath 는 `.build/ios`(`LAZYMEMO_DERIVED`).
4. 끝난 산출물(xcarchive·PNG·spike .build·dist)은 만든 세션이 지운다.
5. 300MB 넘는 것은 받거나 만들기 전에 크기를 말한다.
6. 세션 끝에 `./scripts/clean.sh`(기본). `--all` 은 요청 또는 2GB 초과. `.build` 는 세션들이 공유한다 — 남의 빌드 도중에 빼지 않는다(`pgrep -x`).
7. 저장소에 큰 파일 금지 — 미디어 4MB 이하, 벤치는 `.md` 결과만.

## 검증

- `CLAUDE.md` 의 `@AGENTS.md` 는 Claude Code 의 import 문법 — 다음 세션이 열릴 때 규칙이 컨텍스트에 실린다. 이 세션에서는 파일 내용을 눈으로 확인했다.
- `AGENTS.md` 89줄, managed block 경계(`oculpm:begin`/`end`) 그대로.