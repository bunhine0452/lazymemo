---
schema_version: 1
type: feature
slug: "multilingual-time-keyword-parsing"
status: done
difficulty: high
created_at: "2026-08-28T22:53:09+09:00"
session_id: "20260828-002"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/TimeWords.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/DayParser.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/TimeParser.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/KoreanDateParser.swift"
    op: delete
  - path: "Sources/LazyMemoCore/Model/Schedule.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/NaturalDateParserTests.swift"
    op: rename
  - path: "Tests/LazyMemoCoreTests/NaturalDateParserLanguagesTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "parser"
  - "i18n"
  - "quick-capture"
  - "performance"
  - "mcp-tool"
---
[x] 시간 낱말을 네 나라 말로 읽는다 — 하루 중 때까지

## 추가 기능

`KoreanDateParser` 는 한국어만, 그것도 `오전/오후` 만 읽었다. 사용자 요청은 "오늘·내일, 오전·오후, 새벽·아침·저녁 등 시간과 관련된 모든 키워드를 영어·일본어·중국어까지 감지" 다. 파서를 넷으로 갈라 다시 지었다.

- `TimeWords` — 네 나라 말 시간 낱말표(상대 날짜·요일·주/달 표현·하루 중 때·한국어 날수). 언어 선택 설정을 두지 않는다. 표만 보므로 섞어 적어도 읽힌다.
- `DayParser` — 날짜. `2026-09-01` · `9월 1일` · `9月1号` · `Sep 1` · `1st of September` · `내일` · `明後日` · `后天` · `next tuesday` · `下周一` · `주말` · `다음 달` · `in 3 days` · `이틀 뒤`.
- `TimeParser` — 시각. `3pm` · `오후 3시 30분` · `15:30` · `at 7` · `午後3時半` · `晚上8点`, 그리고 숫자 없는 때(`내일 저녁` → 19시). `3시간 뒤` · `in 30 minutes` 처럼 지금으로부터 재는 표현은 날짜 없이도 순간이 정해져 따로 본다.
- `NaturalDateParser` — 바깥에 드러나는 이름(옛 `KoreanDateParser`). 결과 모양(`due`/`at`/`phrases`)과 `strip` 은 그대로라 `QuickCaptureModel`·`QuickSchedule` 은 이름만 바뀌었다.

## 동작 흐름

1. 지금으로부터 재는 표현이 있으면 곧바로 순간을 만든다.
2. 없으면 날짜를 찾는다 — 못 박힌 날짜 → 상대 표현 → 요일 → 주/달 → 세는 표현 순.
3. 날짜가 없으면 **아무것도 만들지 않는다** (`3시에 전화` 는 어느 날인지 알 수 없다).
4. 시각은 숫자 앞에 **딱 붙은** 때만 오전/오후를 가른다 — "아침에 산 우유 3시에 마시기" 의 아침은 3시를 꾸미지 않는다.

판단이 들어간 곳 두 가지. **숫자 없는 때에 대표 시각을 준다**(새벽 5 · 아침 8 · 오전 9 · 낮/점심 12 · 오후 14 · 저녁 19 · 밤 21 · 자정 0) — 시각을 적을 생각이 없던 사람에게 되묻지 않기 위해서고, 칩에 해석 결과가 보여 어긋나면 바로 눈에 띈다. **영어 세 글자 줄임말 중 `sun`·`sat` 은 뺐다** — 해와 sat(앉다)로 훨씬 자주 쓰인다. 라틴 낱말은 낱말 경계를 지켜 `money` 의 `mon`, `afternoon` 의 `noon` 을 잡지 않고, `at` 없는 맨 숫자는 시각으로 보지 않는다.

## 타자마다 도는 값

빠른 입력 상자는 글자마다 파서를 부른다. 처음 구현은 한 번에 2.4ms 였다(debug). 재 보니 **정규식 리터럴이 쓸 때마다 새로 짜이는 값**(하나에 0.1ms, 달 이름 정규식은 0.4ms)이 대부분이었고 `Regex` 는 Sendable 이 아니라 static 으로 캐시할 수 없다. 그래서 값싼 문지기를 앞에 세웠다 — 낱말표는 첫 글자가 본문에 없으면 건너뛰고, 정규식은 `월/月`·`시/時/点`·`뒤/후/in`·달 이름 같은 표식이 있을 때만 꺼낸다. 결과 2.4ms → 0.26ms.

## 검증

- `./scripts/test.sh` — 167 테스트 통과. 기존 한국어 테스트 14개는 한 줄도 고치지 않고 통과(이름만 `NaturalDateParser` 로 바꿈).
- `NaturalDateParserLanguagesTests` 15개 추가 — 하루 중 때, 네 나라 말 날짜·시각, 지금으로부터, 오탐 방지(`money`·`satisfying`·`tomorrow 3 boxes`), 다국어 본문 정리.
- 성능 회귀 방지 테스트 1개(한 번 파싱 2ms 상한, 현재 0.26ms).