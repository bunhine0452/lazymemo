---
schema_version: 1
type: bug
slug: "phone-calendar-swipe-jank"
status: done
difficulty: medium
created_at: "2026-09-17T19:13:02+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
related:
  - ref: "20260917/Features_to_add/1700_feature_phone-calendar-swipe-motion.md"
    kind: "followup"
tags:
  - "ios"
  - "calendar"
  - "performance"
  - "swiftui"
  - "mcp-tool"
---
[x] 폰 달력 넘길 때 살짝 걸림 — 손가락마다 126칸을 다시 만들며 날짜 서식 126번, Equatable 판과 늦은 서식으로

사용자: 「모바일에 캘린더를 넘길때 살짝 렉이 걸리는것같은 느낌이야.」

## 발생 원인

`@GestureState`(손가락 오프셋)가 바뀌는 **매 프레임** `MonthGridView.body` 가 다시 돌고, 그 안에서 세 판을 매번 새로 만들었다:
- `neighbor(±1)` → `MonthGrid.make` 둘 (Calendar 산수).
- 126칸 각각 `DateWords.dayWeekday(day.date)` 로 소리 이름표 **문자열**을 만든다 — `startOfDay` + 새 `Date.FormatStyle` + `formatted()`. 칸당 수십 µs × 126 이면 120Hz 프레임 예산(8ms)의 대부분이라, 미는 동안 프레임이 빠졌다.
- 126개 `dropDestination`·Button 트리 diff 도 매 프레임.

## 해결 방법

- 세 판을 `Equatable` 자식으로 뗐다: `MonthStrip`(앞·이번·다음, 옆 달 산수 포함) 과 `MonthPanel`(한 달 42칸). `==` 는 값(달·정본·incoming·고른 날·점·오늘·폭)만 견주고 닫힘은 뺀다. `.equatable()` 로 붙여 프레임마다 바뀌는 것은 부모의 `.offset` 뿐 — 판의 `body` 는 SwiftUI 가 건너뛴다.
- 소리 이름표는 문자열 대신 `Text(date, format:)` — 값과 서식만 들고 있다가 읽힐 때 서식한다. 「N일, 일정 M」 은 `Text("\(spoken), 일정 \(count)")` 로 같은 열쇠 `%@, 일정 %lld` (앱 en 표에 이 열쇠가 빠져 있던 것도 넣었다 — 위젯 표에만 있었다).
- 판이 새로 그려지는 순간은 달이 바뀌거나 점이 갱신될 때뿐이고, 그때도 서식이 없어 싸다.

## 검증

- `xcodebuild build` LazyMemo-iOS (시뮬레이터, 전체 빌드) ✓. `./ios/scripts/uitest.sh testCalendarShowsTheDay` passed — 칸 이름표(`15일 …`)가 늦은 서식으로도 접근성 트리에 그대로 선다.
- 임시 XCUITest(왼쪽 튕김 → 다음 달, 오른쪽 두 번 → 지난달, 칸 누름) passed 뒤 삭제.
- 실기기 체감은 사람 눈 확인 필요 — 시뮬레이터는 프레임 시간을 못 잰다.

## 메모

`CalendarView.load()` 가 넘김과 동시에 세 달치를 다시 읽어 `marks` 가 바뀌면 판이 한 번 더 그려지지만, 이제 서식이 없어 한 번의 재구성으로 끝난다.