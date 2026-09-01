---
schema_version: 1
type: chore
slug: "plan-v2-surface-and-place"
status: done
difficulty: low
created_at: "2026-08-31T15:29:24+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".oculpm/discussion/lazymemo-agent-surface/discussion.md"
    op: update
  - path: ".oculpm/planner/lazymemo-v2-surface-place.md"
    op: create
related:
  - ref: "20260831/Chores/1520_chore_research-agent-surface-positioning.md"
    kind: "followup"
tags:
  - "plan"
  - "discussion"
  - "place"
  - "mcp"
  - "mcp-tool"
---
[x] 장소 축 설계를 더해 열 안 전부를 v2 플랜 5단계 31항목으로 분해

사용자가 ① 지역·위치 메모를 원한다고 했고 ② 앞 조사의 여덟 안을 전부 만들겠다고 정했다. 토의 문서에 장소 관련 두 안을 더해 닫고, 실행 계획을 만들었다. 코드 변경 없음.

## 더한 것 — 방안 I·J

`{#opt-place}` 가 「시간이 유일한 구조다」(§14.2)를 건드리는 유일한 안이라 그 충돌부터 풀었다.

**푼 방식: 장소는 자리를 정하지 않는다.** 날짜가 붙으면 종이가 물러나고 달력이 맡지만(§7.2), 장소가 붙어도 **종이는 그대로 있다.** 지도 뷰도 장소 목록도 「장소별 보기」도 만들지 않는다 — 전부 사용자가 유지해야 하는 구조이고, 게으른 사람은 유지하지 않는다. 장소는 종이에 찍힌 잉크 자국 하나이고 누르면 시스템 지도가 연다. 그러면 구조는 여전히 시간 하나이고 장소는 날짜와 같은 **부사**가 된다. 앱 안에 지도를 들이지 않는 두 번째 이유는 재질이 둘이 되면 §14.5(「재질은 하나 — 종이」)가 깨지기 때문이다.

**인식 규칙은 둘로 제한했다** — `@강남역` 형태와 한국 주소 패턴만. 산문에서 추측하지 않는다. 이것은 `{#opt-g}`(규칙 기반 자동 묶기)를 보류한 것과 같은 판단이다: 틀린 자동 분류는 정리가 아니라 치울 것을 하나 더 만든다.

`{#opt-geofence}`(가면 떠오른다)는 `{#opt-place}` 에서 떼어 별도 안으로 뒀다 — `Always` 위치 권한은 링크 카드(§9.3)와 비교가 안 되는 무게라 프라이버시 문단을 다시 써야 하고, 기본 꺼짐이어야 한다.

시너지 하나를 찾았다: `{#opt-place}` × `{#opt-shortcut-drop}` — 단축어가 「현재 위치」를 읽어 `place:`+`geo:` 가 박힌 .md 를 vault 에 떨구면 **iOS 앱 없이 아이폰 위치 메모**가 되고, macOS 쪽 코드는 0줄이다.

## 순서 기준 — 권한 비용 오름차순

이 앱의 가장 값진 자산이 "첫 실행에 아무것도 묻지 않는다" 이므로, 묻지 않고 되는 것을 먼저 다 하고 묻는 것을 뒤로 밀었다.

1. `{#p1-doors}` 문 열기(URL 스킴·서비스 메뉴·CLI·MCP prompts·아이폰 단축어) — 권한 0
2. `{#p2-surface}` `surface_at` — 권한 0. 시스템 알림이 아니라 `riseBriefly` 창 레벨 전환
3. `{#p3-place}` 장소 — 대부분 권한 0이고 `⌥⌘L` 하나만 위치 권한. 처음 누를 때만 묻는다
4. `{#p4-foundations}` EventKit·반복 일정·게으른 찾기 — 캘린더 읽기 권한, 달력 처음 열 때만
5. `{#p5-bold}` `claude` CLI·지오펜스 — 새 실패 유형과 Always 권한

## 검증

문서가 `discussion-spec.md` 규격을 지키는지 확인했다 — `{#opt-*}`·`{#next-*}` id 가 전부 줄 끝 한 줄, discussion-log managed block 보존, 결론 작성 후 status 를 resolved 로. 플랜은 `plan_create` 응답이 `phases: 5, items: 31` 로 규격 생성을 확인해 줬다. 코드 변경이 없어 빌드·테스트는 돌리지 않았다.