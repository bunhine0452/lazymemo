---
schema_version: 1
type: chore
slug: "motion-ux-audit-2026-09-18"
status: done
difficulty: medium
created_at: "2026-09-18T19:50:07+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/research/motion-ux-audit-2026-09-18.md"
    op: create
related:
  - ref: "20260917/Bugs/1913_bug_phone-calendar-swipe-jank.md"
    kind: "followup"
  - ref: "20260918/Bugs/1649_bug_drawer-performdrag-returns-immediately.md"
    kind: "followup"
tags:
  - "ux"
  - "motion"
  - "performance"
  - "audit"
  - "macos"
  - "ios"
  - "mcp-tool"
---
[x] 움직임·조작감 감사 — 소유 구역의 애니메이션·과녁·매 프레임 비용을 전부 훑어 문서 하나로

사용자: 「사용자의 UX 사용감을 더더욱 증가시켜야하며, 절대 불편하면 안된다. 모션또한 매우 부드러워야하며, 최적화가 잘 되어있어야한다.」

서랍·빠른 입력·달력·메뉴바와 폰의 목록·펜·달력·시트를 대상으로, `withAnimation`·`.animation(`·`NSAnimationContext`·`animator()`·`.transition(`·`Timer`·`asyncAfter`·`.onHover`·`.contentShape`·`hitTarget` 을 전부 훑고 **계산 속성이 `body` 안에서 몇 번 읽히는지를 손으로 셌다.**

결과는 `docs/research/motion-ux-audit-2026-09-18.md` — 항목마다 `파일:줄` · 무엇이 불편한가 · 어긋난 애플 원문 · 고친 것. 한 문장으로: **움직임은 느린 게 아니라 제각각이었고(여섯 가지 속도), 렉은 그림이 아니라 글자를 짓는 데서 났다.**

찾은 것 중 큰 셋.

- 맥 달력이 줄을 끌 때마다 **날짜 서식을 한 프레임에 84번** 지었다 — 폰이 2026-09-17 에 고친 바로 그 결함(`1913_bug_phone-calendar-swipe-jank`)이 맥에 그대로 있었다.
- 서랍은 손이 줄에 스치기만 해도 판 전체가 다시 그려지고 애니메이션 갈래를 탔다. 빠른 입력은 루트에 `.animation` 이 **열 겹**이었고 그중 하나가 「손이 얹힌 줄」이라, 포인터가 목록 위를 지나기만 해도 **적고 있는 글 상자까지** 움직였다.
- 「봤어요」(28pt, 카드 전체가 단추인 그 안) · 시각 칩(34pt) · 「가는 길」(19pt)이 HIG 의 과녁 바닥 아래였다.

「고칠 것 없음」으로 근거를 남긴 것도 적었다 — 소유 구역에 `Timer`·`repeatForever` 는 하나도 없고, `LazyVStack` 은 `scrollTo` 와 다투므로 바꾸지 않으며, `drawingGroup` 은 격자의 글자를 흐리게 하므로 넣지 않는다.

## 검증

연구 문서라 코드 검증은 이어지는 두 일지(움직임 낱말 통일 · 걸림 고치기)가 진다. 이 문서의 §6 에는 그 두 일지가 돌린 명령과 **실제로 나온 숫자**가 그대로 들어 있다 — 통과한 것, 남의 진행 중인 작업에 막힌 것, 내 것이 아님을 측정으로 가른 것(RSS 126.9 ↔ 127.4MB)을 나눠 적었다.