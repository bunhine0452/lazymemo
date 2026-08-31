---
schema_version: 1
type: chore
slug: "docs-catch-up-with-code"
status: done
difficulty: low
created_at: "2026-08-31T13:06:05+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
  - path: ".oculpm/discussion/lazymemo-lazy-comfort/discussion.md"
    op: update
related: []
tags:
  - "docs"
  - "mcp-tool"
---
[x] 문서를 코드에 맞춘다 — comfort-v2 로 달라진 것과 닫는 토의

## 무엇을 맞췄나

`lazymemo-comfort-v2` 로 달라진 것을 설계문서와 README 에 반영하고, 이 계획의 뿌리였던 토의를 닫았다.

**docs/DESIGN.md**

- §5.1 — 「(설정으로 이동 가능)」이 오랫동안 코드에 없는 문장이었다는 것과, 지금 그것이 어떻게 되는지(문 하나·정본만 옮김·껐다 켜기·없어진 폴더).
- §6 — 지우는 길이 셋에서 **넷**으로(달력 줄이 마지막까지 뚫려 있었다). 되돌리는 줄이 지운 그 자리에 남는다는 규칙과, 종이만 예외였던 까닭.
- §8 — 끊긴 자리에 끊겼다고 적고 넓어지는 목록. 화면에 놓는 수와 아는 수를 갈라 놓은 것이 요점.
- §8.2 — 비율 한 벌을 두 외관이 함께 쓰다가 다크에서 같은 일이 반복된 것, 재서 못 박은 방법, 면 색과 글자 색을 가른 것.
- §14.10 — 골라진 줄이 시스템 파랑에서 종이색으로.
- §14.11 신설 — 조용한 화면에도 이름은 있어야 한다 (VoiceOver).

**README** — 조작 표에 「끝에서 ↓ 한 번 더」·달력 줄 휴지통·종이의 인라인 되돌리기, 메모 폴더 옮기는 길, 소리로 읽는 이름 한 문단, 테스트 수 260 → 377.

**discussion/lazymemo-lazy-comfort** — `## 결론` 을 쓰고 `status: resolved`. 채택 셋({#opt-a}·{#opt-b}·{#opt-f})이 어디로 갔는지 항목별로 적고, 보류({#opt-g})와 이월 셋({#opt-c}·{#opt-d}·{#opt-e})을 갈라 남겼다. 로그에는 닫는 줄 한 개만 append.

## 검증

문서에 적은 낱말이 실제 화면·코드와 같은지 하나씩 대조했다 — 메뉴 항목 이름은 `LAZYMEMO_MENU=1` 출력으로, 조작 표의 손짓은 `build/ui/*.png` 와 테스트 이름으로. 테스트 수는 `./scripts/test.sh` 의 실제 출력(377)을 옮겼다.