---
schema_version: 1
type: chore
slug: "perf-restore-verification-and-docs"
status: done
difficulty: medium
created_at: "2026-08-28T17:43:44+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/verify-performance.sh"
    op: create
  - path: "scripts/verify-restore.sh"
    op: create
  - path: "scripts/verify-window.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "performance"
  - "verification"
  - "docs"
  - "readme"
  - "design-doc"
  - "ship"
  - "mcp-tool"
---
[x] 성능·복원 실측과 문서 동기화 — RSS 88.8MB, idle 0%, 복원 100%

플래너 `{#ship}` 의 `{#perf-measure}` `{#restore-test}` `{#docs-release}` 를 끝냈다 (`{#ime-regression}` 은 IME 작업에서 함께 처리됨).

## 한 일

**성능 실측** (`scripts/verify-performance.sh`) — 임시 Vault 에 메모 10장을 MCP 로 만들고 release 빌드를 띄운 뒤, 창 10개를 확인하고 3초 안정화 후 잰다.

```
  RSS       88.8 MB   (예산 100 MB)   ✓
  idle CPU  0.0 %     (예산 0%)       ✓
```

**재기동 복원** (`scripts/verify-restore.sh`) — 실제 재부팅을 대신한다. 재부팅이 추가로 검증하는 것은 OS 가 프로세스를 되살리는 부분뿐이고, 복원 책임은 전적으로 Vault 와 `layout.json` 에 있다.

메모는 **MCP 서버(별도 프로세스)로** 만든다 — 그 경로까지 함께 검증된다. 1차 기동 후 창 배치를 `CGWindowList` 로 찍고, 죽였다 다시 띄워 같은 배치가 나오는지 비교한다. 창 4개(메모 3 + 캘린더) 좌표·크기가 모두 일치했다.

**문서 동기화** — `docs/DESIGN.md` 의 §4 구조도(MCP 별도 프로세스 + FSEvents), §5.2(`deleted`, 초 단위 정밀도), §5.3(trigram + LIKE 폴백), §7(창 24개 상한·숨김·`NSHostingView` 함정), §8(⌥⌘N·IME 세 규칙), §9.2(`list_trash`), §11(실측 표), §13(미결 사항 재정리)을 구현에 맞췄다. README 는 사용법·MCP 연동·프라이버시·개발 안내로 다시 썼다.

## 알아낸 것 — 측정 스크립트의 함정 둘

**`ps` 의 `%cpu` 로는 idle 을 못 잰다.** 프로세스 시작 이후 **평균**이라, 기동 직후 잠깐 일한 것이 계속 섞여 들어온다. `top -l 4 -s 1 -stats pid,cpu` 로 순간 표본을 여러 번 뜨고 첫 표본을 버린 뒤 최댓값을 본다.

**`set -euo pipefail` 에서 `grep` 무매치가 스크립트를 조용히 죽인다.** `pipefail` 때문에 파이프 중간의 `grep` 이 1 을 돌려주면 전체가 실패로 잡혀, 아무 출력 없이 종료됐다. 원인을 찾는 데 두 번 헛돌았다. `awk` 로 바꾸고 `|| true` 를 붙였다.

## 짚어 둘 것

RSS 88.8MB 는 예산 100MB 에 여유가 크지 않다. 창 24개 상한(§7)이 이 숫자를 지키는 장치이므로, 상한을 올리려면 반드시 재측정해야 한다. 설계문서 §11 에 적어 뒀다.

## 검증

- `./scripts/verify-performance.sh` · `./scripts/verify-restore.sh` 둘 다 통과.
- `./scripts/test.sh` 76개 테스트 통과.
- README 의 스크립트 목록과 실제 `scripts/` 내용이 일치함을 확인.