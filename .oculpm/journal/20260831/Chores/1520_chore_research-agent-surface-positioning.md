---
schema_version: 1
type: chore
slug: "research-agent-surface-positioning"
status: done
difficulty: low
created_at: "2026-08-31T15:20:23+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".oculpm/discussion/lazymemo-agent-surface/discussion.md"
    op: create
related: []
tags:
  - "discussion"
  - "research"
  - "positioning"
  - "mcp"
  - "mcp-tool"
---
[x] 경쟁 지형 조사 + 차별 기능 후보 8안을 문제 해결 문서로 정리

사용자가 "이 앱을 쓸모 있게 만들 방안 + 비슷한 앱 조사 + lazymemo 만의 기능" 을 명시적으로 요청 — AGENTS.md §5 에 해당해 `.oculpm/discussion/lazymemo-agent-surface/discussion.md` 를 작성했다. 코드 변경 없음(문서 1건 생성).

## 한 일

웹 조사로 경쟁 지형을 네 진영으로 갈랐고, 네 진영 모두 한 칸씩 비어 있다는 것을 확인했다.

- 바탕화면 붙임쪽지(Stickies·Noticky·SideNotes·Antinote) → **시간 구조 없음**
- 날짜에 붙는 노트(Agenda·NotePlan) → **바탕화면 없음**, Agenda 는 추가로 폐쇄 포맷
- 빠른 입력(Drafts·Tot·Heynote·Quick Note·Raycast) → **보관 없음**
- 노트 MCP 서버(Apple Notes MCP 계열·Macuse·Apple-MCPs) → 전부 AppleScript/JXA 로 **남의 앱을 조종**하고 결과가 "열어야 보이는 앱" 안에 떨어짐

여기서 나온 제품 문장: **"다른 앱의 MCP 는 남의 앱에 결과를 넣는다. lazymemo 는 MCP 서버가 곧 화면이다."** — lazymemo 는 바탕화면 상주 + 시간 구조 + 열린 파일 포맷 + 네이티브 MCP 가 동시에 있는 유일한 칸이고, 이는 새로 만들 것이 아니라 D1·D5·마크다운 정본·D3 의 합이다.

후보 8안을 세 트랙으로 정리했다.

- 차별 트랙 — `{#opt-agent-surface}`(`surface_at`: Claude 가 종이가 떠오를 시각을 정한다), `{#opt-mcp-prompts}`(MCP prompts 로 「정리해줘」를 사용자가 발명하지 않게), `{#opt-throw-in}`(URL 스킴 + 서비스 메뉴 + CLI). 셋이 한 묶음 — A 가 "Claude 가 놓는 문", D 가 "무엇이든 던지는 문"
- 공짜 — `{#opt-shortcut-drop}`(단축어로 아이폰에서 던지기, iOS 앱 없이. 열린 파일 포맷이 낳은 것이라 Agenda 는 원리적으로 못 함)
- 받침 — `{#opt-eventkit}`(A 의 전제), `{#opt-recurring}`(`Tidy.past` 와 충돌 해소 필요), `{#opt-recall}`(이월된 두 안이 같은 곳을 가리키고 있었다)
- 보류 — `{#opt-claude-cli}`(F-2). 여덟 중 유일하게 새 실패 유형(기다리는 상태·서브프로세스 실패)을 들여온다

## 코드 쪽에서 확인한 것 (제안의 실현 가능성 근거)

- `Memo.preserved` 가 미지의 프론트매터 키를 보존 → `surface:` 필드를 더해도 파일 호환이 깨지지 않는다
- `Resources/Info.plist` 에 `CFBundleURLTypes`·`NSServices` 항목이 **아직 없다** → `{#opt-throw-in}` 은 plist 두 항목 + 핸들러가 전부
- `Sources` 전체에 EventKit 참조 0건 → `{#opt-eventkit}` 은 순수 신규
- MCP 도구는 CRUD 6개(`list_memos`/`create_memo`/`update_memo`/`delete_memo`/`restore_memo`/`list_trash`)뿐이고 prompts 계열 미구현

## 검증

문서가 `.oculpm/agents/discussion-spec.md` 규격을 만족하는지 확인했다 — YAML frontmatter(`oculpm_discussion: v1`, id=폴더명, status: open), `## 문제 정의` 최상단, 후보안 `{#opt-*}`·다음 단계 `{#next-*}` id 가 모두 줄 끝 한 줄, discussion-log managed block 유지. 코드 변경이 없으므로 빌드·테스트는 돌리지 않았다. 활성 플랜(lazymemo-v1)에 대응 항목이 없어 plan_update 는 생략했다 (남은 두 항목은 사람이 눈으로 확인할 환경 검증뿐).