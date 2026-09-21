---
schema_version: 1
type: chore
slug: "widget-design-doc"
status: done
difficulty: medium
created_at: "2026-09-18T19:11:28+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/WIDGET_DESIGN.md"
    op: create
related:
  - ref: "20260916/Features_to_add/2319_feature_widgetkit-now-next-write.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1621_feature_calendar-widget-month-grid.md"
    kind: "followup"
tags:
  - "widget"
  - "design-doc"
  - "hig"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] 위젯 설계 문서 — 네 위젯 × 가족별 정보 위계·글자·여백·과녁을 HIG 원문에 근거해 못 박았다

`docs/WIDGET_DESIGN.md` (171줄). 앞선 두 판(WidgetKit 확장·달력 위젯)은 얼굴을 먼저 짓고 규칙은 코드 주석에만 남아 있었다. 재설계 전에 규칙을 한 곳에 모으고, **결정마다 애플 원문을 인용**했다 (`docs/research/apple-design-principles.md` 와 같은 방식).

절: ① 한 문장 ② 한 장의 문법(네 위젯이 함께 쓰는 여섯 조각의 표) ③ 여백과 과녁 ④ 위젯 × 가족(1초/3초에 읽히는 것) ⑤ 조작 ⑥ 렌더 모드 ⑦ 프라이버시 ⑧ 시간표 ⑨ 빈 상태·갤러리 ⑩ 접근성 ⑪ 검증.

인용 출처는 넷으로 좁혔다 — HIG Widgets · HIG Accessibility · WWDC23 10028 「Bring widgets to life」 · WidgetKit 「Adding interactivity…」. HIG 페이지는 자바스크립트로 그려져 `WebFetch` 가 제목만 가져온다 — `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/widgets.json` 이 같은 글의 원본 JSON 이고 그쪽은 그대로 읽힌다. 다음에 HIG 원문이 필요하면 이 길로.

문서가 **결정으로 적은** 것 몇 가지:

- 글자의 바닥은 `.caption2` = 11pt (「display text using fonts at 11 points or larger」). 그 아래로는 안 내려간다.
- 바깥 여백은 얹지 않는다 — 시스템이 16pt 를 주고 맥 데스크톱·잠금 화면에서는 더 좁게 준다.
- 과녁의 타협을 숫자로 적었다: 중간 위젯의 「봤어요」는 44 가 아니라 36×34 — 줄 높이가 34 라 44 를 주면 위아래 줄의 과녁이 겹치고, **겹친 과녁은 44 보다 나쁘다.**
- 큰 「지금」의 아래 절은 넉 줄 — 머리 16 + 카드 3×52 + 「다음」 22 + 줄 4×32 ≈ 322 가 350 안에 드는 마지막 수다. 다섯째는 잘리고 잘린 줄은 없는 줄보다 나쁘다.
- 「하루 미루기」는 위젯에 두지 않는다(§4에 이유). 「봤어요」는 폰만(맥 확장에 App Group 이 없다).
- 테마를 붙일 자리는 `WidgetTheme.paper` 한 곳 — `ThemeCatalog` 가 서면 그 `static let` 하나만 갈아 끼운다.

## 검증

문서만 바뀌었으므로 빌드·시험에 영향 없다. 인용 20여 개는 전부 위 네 출처에서 그대로 옮겼고(지어낸 문장 없음), 문서가 말하는 숫자·파일 이름은 같은 날 올린 구현 일지의 코드와 대조했다. 171줄로 상한(250) 안.