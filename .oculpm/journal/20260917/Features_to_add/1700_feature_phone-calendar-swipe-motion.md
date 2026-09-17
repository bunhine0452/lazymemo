---
schema_version: 1
type: feature
slug: "phone-calendar-swipe-motion"
status: done
difficulty: medium
created_at: "2026-09-17T17:00:14+09:00"
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
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
related:
  - ref: "20260914/Bugs/1934_bug_ux-polish-search-empty-calendar-marks.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0400_feature_phone-ui-second-edition.md"
    kind: "followup"
tags:
  - "ios"
  - "calendar"
  - "motion"
  - "gesture"
  - "hig"
  - "mcp-tool"
---
[x] 폰 달력 월 넘김 — 손가락을 따라오는 세 판 미끄러짐, 반 문턱·속도로 넘기고 화살표·오늘도 같은 길

## 추가 기능

사용자 말 "스와이프로 달력을 넘길 때 자연스러운 모션". `MonthGridView` 는 `DragGesture.onEnded` 에서 `onStep(±1)` 만 불러 격자가 **뚝** 바뀌었다. 병렬 fork 세션이 구현하고 부모가 수거했다.

- **세 판**(앞·이번·다음)을 `GeometryReader` 폭으로 나란히 두고 `offset(x: -width + touch.offset + drag)`. 화면 가장자리에서 `clipped()` — 안쪽 여백에서 자르면 들어오는 달이 여백 밖에서 뚝 나타난다.
- 손가락 몫은 `@GestureState`(`Touch{axis, offset}`) — 시트가 내려가거나 목록이 스크롤을 뺏어 `onEnded` 가 안 와도 스스로 0 으로 돌아간다. 축은 첫 이동으로 잠그고(세로면 무시), 오프셋은 ±width 로 clamp.
- **놓기**: `predictedEndTranslation.width`(거리+속도) 절댓값이 **width/2** 를 넘고 손이 간 방향과 같으면 `onStep(±1)`, 아니면 되돌아온다 — 시스템 페이징과 같은 반 문턱.
- **한 길**: 손짓·화살표·「오늘」·이웃 달 칸 누름 모두 정본 `grid` 만 바꾸고, `onChange(of: grid)` 가 옛 달을 `shown` 에 붙든 채 목적지 판을 옆에 세워 `.smooth(duration: 0.3)`(bounce 0 — 튕기면 판 셋 너머 빈 띠가 비침)로 민다. 완료 시 `land()` 가 `disablesAnimations` 트랜잭션으로 `shown=nil, drag=0` — 한 프레임도 안 튄다. 미끄러지는 중 새 손짓은 `generation` 으로 앞 것을 그 자리에 놓고 따라간다. 제목은 `contentTransition(.numericText)`.
- `CalendarView.load()` 가 앞·뒤 달까지 읽어 옆 판에도 점이 선다. `DateSheet` 는 같은 격자라 자동으로 같은 모션.
- **Reduce Motion**: 판이 손을 따라가지 않고 `.easeInOut(0.18)` 크로스페이드.
- 근거: `docs/research/apple-design-principles.md` §2 WWDC18 803 "Touch and content should stay together and move as one thing" / "Allow for constant redirection and interruption"; HIG Accessibility "Replacing transitions in x-, y-, and z-axes with fades".

## 동작 흐름

끌기 → 축 잠금 → 세 판이 손가락만큼 이동 → 놓기 → 반 문턱 판정 → `onStep` → `grid` 바뀜 → `onChange` 가 목적지 판으로 미끄러짐 → `land()` 로 정리. `highPriorityGesture` 라 판이 손과 함께 움직여도 손 밑의 칸이 놓는 순간 눌리지 않는다(1차 프로브에서 「19」가 선택되던 것). 옆 판은 `accessibilityElement(children: .ignore)` + `accessibilityHidden` — 화면 밖 「15일」이 VoiceOver/XCUITest 목록에 남지 않게.

## 검증

- `xcodebuild build -scheme LazyMemo-iOS -derivedDataPath .build/ios` ✓ (경고 0, `.build/ios` 2.0G 그대로).
- 임시 XCUITest(달력 탭·날짜 시트, 끝나고 삭제): 느린 끌기→10월 · 튕김→11월 · 짧은 끌기→11월 유지, 칸 안 눌림 · 오늘→9월 · 지난달→8월 · 세로 끌기→달 유지 · 오른쪽 튕김→7월 · 시트 안 튕김→10월 · 시트 세로 끌기→달 유지 — passed. `./ios/scripts/uitest.sh testCalendarShowsTheDay` passed.
- `simctl io screenshot` 연사로 중간 프레임 확인 — 9월이 밀리고 10월이 점까지 달고 들어오는 것을 부모도 눈으로 봄(스크래치패드, 프로젝트 밖).
- 사람 눈(실기기) 확인 필요: 진짜 손가락 튕김의 속도 판정(XCUITest 의 press-drag 는 속도 0), Reduce Motion 크로스페이드, 미끄러지는 중 다시 잡는 느낌.

## 메모

`docs/MOBILE_DESIGN.md` §6 손짓 표에 「좌우로 쓸기 (격자)」 행을 부모가 넣는다(다른 세션 미커밋 파일이라 fork 는 안 건드림).