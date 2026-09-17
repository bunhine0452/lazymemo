---
schema_version: 1
type: feature
slug: "calendar-widget-month-grid"
status: done
difficulty: medium
created_at: "2026-09-17T16:21:35+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoWidgets/CalendarWidget.swift"
    op: create
  - path: "ios/LazyMemoWidgets/LazyMemoWidgets.swift"
    op: update
  - path: "ios/LazyMemoWidgets/WidgetVault.swift"
    op: update
  - path: "ios/LazyMemoWidgets/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoWidgetsCore/WidgetKind.swift"
    op: update
  - path: "Sources/LazyMemoWidgetsCore/WidgetLink.swift"
    op: update
  - path: "Sources/LazyMemoWidgetsCore/WidgetAgenda.swift"
    op: update
  - path: "Tests/LazyMemoWidgetsCoreTests/WidgetAgendaTests.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/2319_feature_widgetkit-now-next-write.md"
    kind: "followup"
tags:
  - "widget"
  - "widgetkit"
  - "calendar"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] 달력 위젯 — 아이폰·맥 위젯 확장에 이번 달 격자와 일정 점, 큰 가족은 「오늘부터」 네 줄

## 추가 기능

위젯 셋(「지금」·「다음 약속」·「적기」)에 넷째 **「달력」**이 섰다. 병렬 fork 세션이 구현하고 부모가 수거했다.

- 가족: iOS·맥 모두 `systemSmall`·`systemMedium`·`systemLarge`. 잠금 화면 가족은 격자가 안 들어가 뺐다.
- **small**: 오늘 한 칸 — 요일·큰 날짜·「일정 N」/「일정 없음」. 애플 달력 작은 위젯과 같은 말.
- **medium**: 왼쪽 오늘 칸 + 오른쪽 격자(요일 줄·5~6주). 오늘은 포레스트 원, 일정은 숫자 밑 점(≤3), 일/토 잉크, 넘어온 칸은 옅게 — 폰 `MonthGridView`·맥 달력과 같은 낱말(§10.4).
- **large**: 「9월 2026 … 9월 17일 (수)」 머리 + 넉넉한 격자 + 「오늘부터」 4줄(`WidgetAgenda.upcoming(includingToday:)`; 「오늘 · 오후 3:00 치과」 — Now 위젯의 「다음」 줄과 같은 꼴). 줄을 누르면 그 메모.
- 시간표: `dayChanges(now:count:)` = 지금 + 자정 셋(`CalendarDate.nextMidnight`, DST 안전), `.atEnd`. 메모가 바뀌면 `WidgetRefresher` 가 `WidgetKind.identifiers` 전부를 다시 그리므로 `case calendar` 만 더하면 자동.

## 동작 흐름

1. `WidgetVault.memos()` → `WidgetAgenda.monthMarks(_:in:)` 가 격자 범위(넘어온 칸 포함)의 날짜별 일정 수를 센다 — 폰 달력 `marks` 와 같은 기준(물러난 것은 세고 지운 것만 뺌).
2. 얼굴은 `MonthGrid`(LazyMemoCore) 그대로. 날마다 `Link(WidgetLink.calendar(day))` → `lazymemo://calendar/YYYY-MM-DD`.
3. `WidgetLink.calendarStop(of:)` 파서(`.month`/`.day`)를 WidgetsCore 에 두었으나 **`Destination` 열거에는 넣지 않았다** — 앱 둘(`AppModel.open`·`AppDelegate`)이 `default` 없이 가르고 있어 case 를 더하면 그 두 파일(하나는 다른 세션 미커밋)이 깨진다. 그래서 지금은 **앱만 열린다**; 후속으로 `switch` 앞에 `if let stop = WidgetLink.calendarStop(of: url)` 한 줄이면 그 날로 간다. `InboundLink` 는 이 주소를 add 로 오해하지 않고 조용히 버린다(시험으로 고정).
4. 갤러리 견본(`WidgetSample`)에 날짜만 있는 메모 둘(5일·12일 뒤)을 더해 격자에 점이 보이게 했다.

## 검증

- `./scripts/test.sh --filter LazyMemoWidgetsCoreTests` → 18 tests / 3 suites 통과 (monthMarks·upcoming(includingToday)·dayChanges·달력 주소 왕복/깨진 날·kinds 4).
- `xcodebuild build` LazyMemo-iOS(iPhone 17 시뮬레이터)·LazyMemo-macOS, derivedData `.build/ios` → 둘 다 BUILD SUCCEEDED, appex dylib 에 `CalendarWidget` 심볼 확인. `du -sh .build/ios` 2.0G → 2.0G(증분).
- 사람 눈 확인 필요: 홈 화면·알림 센터에서 세 가족의 실제 배치(medium 6주 달의 줄 높이, large 아래 4줄 잘림 여부), 다크 모드 색, 갤러리 견본.

## 메모

- `scripts/check-l10n.sh` 는 위젯 타깃을 세지 않는다 — en 표는 손으로 맞췄다.
- 후속: 날짜 딥링크를 앱이 받게 하기(iOS `AppModel.open`, 맥 `AppDelegate`) · README 「위젯」절에 「달력」 한 줄.