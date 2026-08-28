---
schema_version: 1
type: chore
slug: "create-planner-and-design-doc"
status: done
difficulty: medium
created_at: "2026-08-28T16:37:17+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/DESIGN.md"
    op: create
  - path: ".oculpm/planner/lazymemo-v1.md"
    op: create
related: []
tags:
  - "planner"
  - "design-doc"
  - "lazymemo"
  - "macos"
  - "swiftui"
  - "mcp"
  - "mcp-tool"
---
[x] lazymemo v1 플래너와 설계문서 작성

resolved 된 문제 해결 문서 `lazymemo-계획서` 의 결론을 실행 가능한 두 산출물로 옮겼다. 코드는 아직 손대지 않았다.

## 한 일

**플래너** (`plan_create` 로 생성, 8 phase / 34 항목)

discussion 의 `## 다음 단계` 10개를 실행 단위로 분해했다. phase 순서는 리스크 순으로 잡았다 — 기반 골격 → **바탕화면 창 스파이크** → 데이터 → 메모 UI → 빠른 입력 → LLM → 캘린더 → 품질·배포.

창 스파이크를 두 번째에 둔 이유는 이 영역(Stage Manager, Mission Control, 월페이퍼 클릭 데스크탑 표시, 다중 디스플레이)이 문서화가 부족하고 프로젝트 최대 리스크인데, 여기서 막히면 D2(메모당 NSWindow) 자체를 다시 봐야 하기 때문이다. 뒤에 두면 이미 쌓은 UI 를 버리게 된다.

**설계문서** (`docs/DESIGN.md`)

discussion 이 "왜 이 결정인가"(기각된 대안 포함)를 담는다면, 설계문서는 "그래서 무엇을 만드나"를 담게 나눴다. 논거 전문은 중복 서술하지 않고 `{#opt-x}` 로 참조만 걸었다.

주요 내용: 확정 결정 7개(D1~D7) 표, 실측으로 검증된 기술 전제 표, 레이어 구조, 디렉터리 레이아웃과 마크다운 frontmatter 스키마, 삭제·되돌리기 안전 모델, 창 시스템, MCP 도구 인터페이스, 성능 예산, 배포 경로.

## 설계문서에서 새로 정한 것

discussion 에 없던 세부 결정 세 가지를 여기서 확정했다.

- **창 위치를 메모 파일이 아니라 `layout.json` 에 분리.** 메모 파일은 사용자와 LLM 이 읽고 쓰는 대상이라, 드래그할 때마다 정본이 갱신되면 동기화 충돌과 무의미한 diff 가 생기고 LLM 이 파일을 다시 쓰며 좌표를 날릴 수 있다. UI 상태는 파생 영역으로 격리했다.
- **메모와 일정을 별도 타입으로 나누지 않음.** `due` / `at` frontmatter 필드가 있으면 캘린더에도 나타나는 방식. LLM 이 "약속"과 "목표"를 타입으로 구분해 저장할 필요 없이 날짜 필드만 채우면 되므로 D3 의 도구 표면이 단순해진다.
- **하드 삭제를 MCP 도구로 노출하지 않음.** `delete_memo` 는 trash 이동까지만 한다. D6 을 규약이 아니라 도달 불가능한 코드 경로로 강제하기 위해서다.

## 검증

`plan_status` 로 활성 플랜이 없음을 확인한 뒤 생성했고, 결과 파일에서 frontmatter(`status: active`), phase 헤딩 8개, `- [ ]` 항목 34개, 모든 `{#id}` 가 줄 끝에 위치함을 확인했다. `docs/DESIGN.md` 는 215줄로 작성됐고 discussion·planner 상대경로 링크가 실제 파일을 가리킨다.