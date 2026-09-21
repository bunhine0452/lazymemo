---
schema_version: 1
type: bug
slug: "calendar-swipe-still-stutters-eight-bodies"
status: done
difficulty: high
created_at: "2026-09-22T01:20:04+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  session: "e79acb44-3d73-43a3-8760-06f8930dcaa9"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/Motion.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260917/Bugs/1913_bug_phone-calendar-swipe-jank.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1700_feature_phone-calendar-swipe-motion.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1945_feature_calendar-color-dots-glide-widget-circle.md"
    kind: "followup"
tags:
  - "ios"
  - "calendar"
  - "motion"
  - "performance"
  - "swiftui"
  - "accessibility"
  - "mcp-tool"
---
[x] 폰 달력 넘김이 아직도 버벅이던 것 — 한 번 넘기는 데 판 body 여덟 번과 속도 0 출발을, 정체성 있는 세 판과 속도 잇는 스프링으로

사용자: 「아직도 달력 넘어가는 모션에서 버벅거림이 느껴져.」 9/17 의 `Equatable` 판은 **손가락이 미는 동안**의 재그리기를 없앤 것이고, **놓는 순간부터 착지까지**는 손대지 않은 채였다.

## 발생 원인

`MonthGridView`·`MonthStrip`·`MonthPanel`·`CalendarView` 의 `body` 와 `load()` 에 `NSLog` 카운터를 심고 XCUITest 로 튕겨 시뮬레이터 로그를 읽었다. 한 번 넘길 때 42칸짜리 `MonthPanel.body` 가 **여덟 번**:

1. **정본이 바뀌는 프레임에 판이 뛴다.** `release` → `onStep` → `grid` 가 바뀌면 그 프레임의 `body` 에서 `current = shown ?? grid` 가 이미 **새 달**이라 세 판이 새 달 기준으로 지어졌고(126칸), 그 프레임을 다 그린 뒤에야 `onChange(of: grid)` 가 `shown = old` 로 되돌려 다시 지었다(84칸 — 가운데는 `.id` 가 같아 살아남음). 눈에는 한 프레임 새 달이 번쩍하고 옛 달로 돌아와 미끄러지는 것 — 로그의 `MonthPanel.body 2026-9/10/11` 다음 `2026-8/10` 이 그것이다.
2. **미끄러지는 중에 판이 또 지어진다.** `.task(id: grid)` 의 `load()` 가 앞뒤 한 달씩만 읽어, 돌아오면 나가는 판의 점이 범위 밖으로 꺼지고 점 사전 하나를 세 판이 같이 받아서 `marks` 가 바뀌면 세 판 전부 `==` 실패.
3. **착지에서 통째로 다시 짓는다.** `land()` 의 `shown = nil` 로 가운데 판의 `.id` 가 바뀌어 새로 생성, 옆 두 판은 달이 갈려 재구성 — 126칸. 스프링 완료(`logicallyComplete`)는 꼬리가 남은 채 불리므로 이 재구성이 마지막 프레임들에 겹친다.
4. **속도 0 에서 다시 출발.** `@GestureState` reset 과 `drag` 의 `withAnimation(.smooth)` 둘 다 초속 0 — 손가락이 800pt/s 로 가다가 놓는 순간 판이 멈췄다가 다시 가속했다. 프레임 낭비가 아니라 **손맛의 멈칫**이지만 같은 말로 읽힌다.
5. 덤: `DateWords.month(grid.month)` 가 손가락 **프레임마다** `Date` 를 짓고 서식했다.

시뮬레이터에서 판 하나 body 가 ~5ms 였으니 (1)+(3) 만으로 한 프레임에 15ms+ — 120Hz 예산의 두 배.

## 해결 방법

- **가운데 달을 정본과 뗀다.** `shown` 이 `MonthGrid?` 가 아니라 `MonthGrid` 이고 `init` 에서 `grid` 로 시작. 정본이 먼저 바뀌어도 판은 `shown` 을 그리므로 그 프레임에 뛰지 않는다. `slide` 는 `incoming` 과 `offset` 만 움직이고, `land(on:)` 에서 `shown = new`.
- **세 판은 달 번호가 정체성.** `MonthStrip` 이 `ZStack { ForEach(slots, id: \.month.ordinal) }` 에 판마다 `offset(x: side * width)`. 착지에서 [8,9,10]→[9,10,11] 이 되면 9·10 은 **옮겨 앉고** 11 하나만 새로 짓는다 (로그: `MonthPanel.body 2026-11` 한 줄). `HStack` 이 아닌 이유 — 움직임을 줄인 사람의 교차 페이드가 옆으로 밀려 나간다.
- **판마다 제 달의 점·고른 날만.** `MonthStrip.panel` 이 `marks.filter(range.contains)` 와 `selected` 를 그 달 것으로 잘라 넘긴다. 옆 달의 점이 갱신되거나 고른 날이 옆 달로 가도 이 판의 `==` 는 참.
- **앞뒤 두 달씩 읽는다** (`CalendarView.span`). 한 번 넘기는 동안 보이는 세 달이 앞 읽기에도 다 들어 있어, `load()` 가 돌아와도 바뀌는 판이 없다. 로드 뒤 `MonthPanel.body` 0.
- **속도를 잇는다.** `Motion.settle(velocity:over:)` — `.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: v/거리)`. 초속은 ω·거리(ω=2π/0.3)에서 잘라 튕기지 않는 스프링이 목표를 지나쳐 판 셋 너머 빈 띠가 비치는 일이 없게. 손가락 자리는 `@State offset` 하나 — 되돌아옴도 넘김도 `value.velocity` 로 출발. `@GestureState` 는 `active`·`axis` 만 들고, 손짓을 뺏겨 `onEnded` 가 안 오면 `active` 가 꺼지는 것을 보고 한 틱 뒤 `offset` 을 제자리로.
- 달 이름 열둘은 `static let monthNames`.

**보조 기술의 함정 하나.** 옆 판 칸을 칸마다 `accessibilityHidden(offstage)` 로 숨기면, 옆에서 가운데로 옮겨 앉은 판의 칸이 숨김을 벗지 못해 XCUITest 가 못 눌렀다(hittable 거짓). 판을 감싸는 자리에서 `accessibilityElement(children: .ignore)` + `accessibilityHidden` 으로 묶어 숨겨야 옮겨 앉을 때 풀린다. 그리고 XCUITest 는 숨긴 요소도 세므로(`15일` 셋) 가운데 판을 `slots` 첫째에 둬 `firstMatch` 가 화면 안 칸이 되게 했다 — 앱의 접근성 나무를 직접 걸어 확인하니 VoiceOver 에는 가운데 것 하나만 선다.

## 검증

- 시뮬레이터 로그(임시 카운터, 끝나고 제거): 넘김 한 번에 `MonthPanel.body` **8 → 1** (새 옆 판 하나, 손이 놓인 뒤). 미끄러지는 중·로드 뒤·착지에서 0.
- 임시 XCUITest(삭제): 왼쪽 튕김→10월 · 오른쪽 두 번→8월 · 짧은 끌기·세로 끌기→유지 · 오늘→9월 · 화살표 연타→12월 · 이웃 달 칸→11월 29일 · 넘긴 뒤 칸 누름 · 미끄러지는 중 재잡기 연속 튕김→1월 · 날짜 시트 튕김·세로 — passed. 각 지점에서 `15일` 첫 짝 hittable.
- 회귀 시험 `testCalendarSwipeTurnsTheMonth` 를 `SmokeTests` 에 남김. `./ios/scripts/uitest.sh` 전체 **26/26 passed**.
- 사람 눈(실기기) 확인 필요: 속도 이어받기의 손맛, 빠른 튕김이 벽에 닿듯 멈추지 않는지(ω·거리 클램프), Reduce Motion 교차 페이드.

## 메모

- `predictedEndTranslation` 판정은 그대로 — 바뀐 것은 판정 뒤의 움직임이다.
- 맥 달력(`Sources/LazyMemoUI/Calendar`)에는 달 넘김 모션이 없어 이 일은 폰만이다.
- 스모크 전체는 앱을 26번 띄우니 10~15분 — 다음엔 회귀 시험 넷(`Calendar*`·`DateSheet*`)만 먼저 돌리고 전체는 백그라운드로.