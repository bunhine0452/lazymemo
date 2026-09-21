---
schema_version: 1
type: feature
slug: "calendar-color-dots-glide-widget-circle"
status: done
difficulty: medium
created_at: "2026-09-21T19:45:15+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoWidgetsCore/WidgetAgenda.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemoWidgets/CalendarFaces.swift"
    op: update
  - path: "ios/LazyMemoWidgets/CalendarWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/WidgetMarks.swift"
    op: delete
  - path: "docs/MOBILE_DESIGN.md"
    op: update
  - path: "docs/WIDGET_DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260917/Features_to_add/1700_feature_phone-calendar-swipe-motion.md"
    kind: "followup"
  - ref: "20260917/Bugs/1913_bug_phone-calendar-swipe-jank.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1912_feature_widget-redesign-precise-comfortable.md"
    kind: "followup"
tags:
  - "ios"
  - "calendar"
  - "widget"
  - "motion"
  - "design"
  - "testflight"
  - "mcp-tool"
---
[x] 달력 칸의 점이 메모의 색을 띠고 고른 날의 원이 칸 사이를 미끄러진다 — 위젯 달력의 오늘은 정확한 원으로

사용자: 「모바일 위젯에 있는 캘린더의 해당 날짜를 알려주는 동그라미 부분을 정확한 원으로 만들어줘. 그리고 달력 칸에서 보여지는 일정을 보여주는 디자인의 모습을 더욱 업그레이드 해주고, 날짜를 넘길때 부드럽게 넘어가도록 해줘」. 「달력 칸」과 「날짜를 넘길 때」는 폰 앱의 달력 탭(과 같은 격자를 쓰는 날짜 시트)으로 읽었다 — 달 넘김은 이미 손가락을 따라오는 세 판이라(9/17), 뚝 바뀌던 것은 **날을 고를 때**였다.

## 추가 기능

- **위젯 달력의 오늘 — 정확한 원.** `HandRing`(손으로 그린 동그라미, 세 도막·기울기·흔들림)을 `Circle().strokeBorder(theme.accentInk, lineWidth: 1.6/1.4)` 로. 30pt 안에서 흔들림은 손이 아니라 찌그러진 타원으로 읽혔다. 테두리라 숫자는 종이에 그대로 남는다. `WidgetMarks.swift` 삭제(위젯에서만 쓰였다; 맥 달력의 `PenMarks.HandRing` 은 별개).
- **칸의 점이 메모의 색이다.** `WidgetAgenda.monthInks(_:in:)`/`(_:from:through:)` — 날짜별 `[MemoColor]`(시각 순, 날짜만 있는 것이 먼저, 같으면 id). `monthMarks` 는 그 수. 폰 `CalendarView.marks` 와 위젯 `CalendarEntry.marks` 가 같은 셈을 써서 홈 화면과 앱이 같은 점을 찍는다. 폰 격자의 점은 4→6pt·간격 3, 색은 `color.ink`(아래 목록의 색 점과 같은 말) — 오늘의 포레스트 원 위에서는 크림 한 색. 셋을 넘으면 셋(§10.4, 수를 세게 하지 않는다). 위젯은 `theme.ink(for:)`, 색을 걷는 렌더에서는 계층색.
- **고른 날의 원이 미끄러진다.** `MonthPanel` 에 `@Namespace` 를 두고 고른 날의 원에 `matchedGeometryEffect(id: "picked")`. `CalendarView.pick` 과 `DateSheet.onPick/onToday` 가 `withAnimation(Motion.settle(reduceMotion))` 안에서 `picked`/`grid` 를 바꾼다 — 원이 옛 칸에서 새 칸으로 가고, 아래 목록의 줄과 머리의 날짜(`contentTransition(.numericText())`)가 같은 박자로 갈린다. 이웃 달 칸을 누르면 판 미끄러짐과 원 이동이 한 트랜잭션. Reduce Motion 이면 짧은 페이드. 「오늘」 단추는 `pick(today)` 하나로(격자 이동은 `pick` 이 한다).
- 문서: MOBILE_DESIGN §6 칸·고른 날 규칙, WIDGET_DESIGN 오늘 원·점 색, README 위젯·달력 줄.

## 동작 흐름

칸을 누른다 → 원이 0.3초 스프링으로 그 칸에 가 앉고 목록이 갈린다 → 손끝에 한 번(기존 `sensoryFeedback`). 옆 달 칸을 누르면 판이 미끄러지며 원도 함께 간다. 위젯: 자정에 오늘 원이 옮겨 가고, 일정이 있는 날은 메모 색 점.

## 검증

- `swift test --filter WidgetAgendaTests` 초록(20, `monthMarks` 시험은 `monthInks` 의 수로 그대로 통과). iOS 빌드 성공.
- 폰: `uitest.sh --shots` 의 달력 스크린샷에서 22·23·24일에 노랑·파랑·초록 점(씨앗 메모의 색)을 봤다. `testCalendarShowsTheDay` 초록.
- 위젯: 시뮬레이터 홈 화면에 「달력」 중간 위젯을 놓고(좌표 탭 프로브) 21일이 정확한 원으로 둘린 것을 스크린샷으로 봤다. 프로브 시험과 그림은 지웠다.
- 사람이 볼 것: 실기기에서 원이 미끄러지는 느낌(시뮬레이터 스크린샷은 정지 화면), 다크에서 색 점의 대비.

## 메모

- `MonthPanel` 은 `Equatable` 이라 `selected` 가 바뀔 때만 다시 그려진다 — 미끄러짐이 손가락 프레임마다 판을 다시 만들지는 않는다(9/17 의 걸림 수정 그대로).
- 맥 달력(`CalendarGrid`)은 손으로 그린 동그라미와 번진 잉크 그대로다 — 사용자가 위젯만 말했다.