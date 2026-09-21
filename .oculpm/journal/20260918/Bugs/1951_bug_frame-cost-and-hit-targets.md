---
schema_version: 1
type: bug
slug: "frame-cost-and-hit-targets"
status: done
difficulty: high
created_at: "2026-09-18T19:51:53+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Calendar/CalendarGrid.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerRow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PlaceCards.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/NowBand.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
related:
  - ref: "20260917/Bugs/1913_bug_phone-calendar-swipe-jank.md"
    kind: "followup"
  - ref: "20260918/Chores/1950_chore_motion-ux-audit-2026-09-18.md"
    kind: "blocked_by"
  - ref: "20260918/Refactors/1950_refactor_one-motion-vocabulary.md"
    kind: "followup"
tags:
  - "ux"
  - "performance"
  - "swiftui"
  - "calendar"
  - "drawer"
  - "accessibility"
  - "macos"
  - "ios"
  - "mcp-tool"
---
[x] 맥 달력이 한 프레임에 날짜 서식을 84번 짓던 것 — 판을 Equatable 로 떼고, 서랍 호버를 줄 안으로, 과녁을 44 로

## 발생 원인

**렉은 그림이 아니라 글자를 짓는 데서 났다.** 계산 속성이 `body` 안에서 몇 번 읽히는지를 세어 보고 알았다.

- **맥 달력 (가장 비쌌다).** `carry(_:)` 의 `DragGesture.onChanged` 가 손가락 자리를 `@State` 에 적으므로 줄을 끄는 **매 프레임** `CalendarView.body` 가 돈다. 그 안에서 칸마다 `dayHelp(date)` 를 **둘씩**(`.help` 와 소리 이름표) 부르는데, 그 한 줄이 `DateWords.monthDay` → **새 `Date.FormatStyle` 을 만들어 서식**한다. 42 × 2 = **프레임마다 84번**. 거기에 42칸의 `ZStack`·`Button`·`onTapGesture` 트리 diff 와 `monthInk` 의 42일 순회가 얹혔다. 120Hz 의 8ms 예산을 서식만으로 먹는다. **폰이 2026-09-17 에 고친 바로 그 결함이 맥에 그대로 남아 있었다.**
- **서랍.** 호버가 `DrawerView` 의 `@State` 라, 손이 줄 하나에 스치면 스물몇 줄이 **전부** 다시 지어졌다. 줄마다 본문을 쪼개 둘째 줄을 만들고(`snippet` 이 `rest` 를 부르는 계산 속성이라 **두 번** 쪼갠다), 시각을 서식하고(`MemoTimeLabel` 을 줄마다 **세 번** — 부를 때마다 `Date()` 와 `Calendar.current` 를 새로 뜬다), 판형을 다시 셌다. 게다가 판 전체에 `.animation(…, value: pointed)` 이 걸려 있어 목록이 통째로 애니메이션 갈래를 탔다.
- **폰 목록.** `nowCards` 와 `listed` 가 계산 속성이고 `listed` 가 `nowCards` 를 부른다. `body` 한 번에 `nowCards` 4번 · `listed` 6번 읽혀서 **메모 전부를 열 번 넘게** 훑었다. 폰 달력의 `marks`·`today` 도 같은 꼴.
- **과녁.** 「봤어요」 28pt — 그것도 **카드 전체가 단추인 그 안에** 있어서, 누르려다 메모가 열린다. 시각 칩 34pt. 맥 자리 카드의 「가는 길」 19pt. HIG Buttons "a button needs a hit region of at least 44x44 pt".
- **대답이 없다.** 폰에서 날을 눌렀을 때 대답이 아래 목록이 바뀌는 것뿐이라, 고른 날이 비어 있으면 「누른 것」과 「아무 일도 없는 것」이 똑같이 보였다. 달이 넘어갈 때도 손끝에 아무것도 없어, 튕겨 되돌아온 손짓과 실제로 넘어간 손짓이 손에는 구별되지 않았다.

## 해결 방법

**판을 `Equatable` 인 자식으로 뗀다** — 폰이 `MonthStrip`·`MonthPanel` 로 고친 방법 그대로.

- 새 파일 `Sources/LazyMemoUI/Calendar/CalendarGrid.swift` 의 `MonthPanel`. 견주는 것은 값뿐이고(닫힘은 뺀다) 달·판형·고른 날·오늘·놓을 자리·`inkVersion` 이 그대로면 SwiftUI 가 `body` 를 건너뛴다. 끄는 동안 실제로 다시 그려지는 것은 **겨누는 칸 하나**다. 이름표 42개는 판마다 한 벌만 짓는다.
- `CalendarModel.inkVersion` 한 숫자를 더했다 — `byDay` 는 사전이라 프레임마다 견주면 그 자체가 비싸다. 「잉크가 달라졌나」를 숫자 하나가 답한다.
- 덤으로 `CalendarView` 가 1035 → 924줄이 됐다 (`{#split-large-files}` 쪽으로 한 걸음).

**서랍의 호버를 줄 안으로.** `DrawerRow: View, Equatable` + `.equatable()`, 호버는 줄의 `@State`. 손이 옮겨 가면 **떠난 줄과 닿은 줄 둘만** 다시 그려진다. 본문 쪼개기는 `lines` 한 번에, 시각은 부르는 쪽이 줄마다 한 번 지어 `DrawerRow(time:)` 로 넘긴다. 키보드가 짚은 자리는 그대로 밖에서 온다 — 짚은 것과 얹힌 것은 같은 표시이지만 정본이 다르다.

**폰은 `body` 머리에서 한 번만 센다.** `let cards = nowCards; let rows = listed(excluding: cards)` 로 지역 값을 만들어 들고 다닌다. 폰 달력의 `marks`·`today` 도 같다. `MonthGridView.weekdays` 는 `static let` 으로 (말은 앱이 도는 동안 안 바뀐다).

**과녁은 보이는 것을 그대로 두고 누르는 자리만 넓힌다.** 「봤어요」는 알약 28 그대로 44×44 판정, 늘어난 만큼은 카드 여백을 먹으므로 그림은 안 달라진다(카드 위 여백을 그만큼 덜었다). 시각 칩은 `minHeight: 44` 로 — 겸사겸사 목록의 폴더 칩과 **같은 만듦새**로 맞췄다. 맥 「가는 길」은 `hitTarget(28)`.

**대답을 손끝에 준다.** 폰 달력의 날 고르기에 `.sensoryFeedback(.selection, trigger: picked)`, 달 넘김에 `trigger: ordinal(grid)` — 정본이 바뀐 때만 울리므로 튕겨 되돌아온 손짓에는 조용하다. 펜의 칩이 서고 물러나는 것도 이제 움직인다(앞선 판은 「내일 3시」를 치는 순간 칩이 툭 나타나며 펜이 한 줄 자라고 목록이 뛰었다).

## 검증

- `swift build` 통과 · `./scripts/test.sh --filter LazyMemoUITests` 377 tests / 56 suites — 15 이슈는 전부 다른 세션의 테마 시험이고 내 구역 스위트는 전부 초록.
- `verify-drawer.sh` ✓ · **`verify-drawer-mouse.sh` ✓** (합성 마우스로 탭 잡아 끌기·누르기·머리 줄 끌기·×·바깥 클릭 — `DrawerRow` 가 제 호버를 갖게 되면서 누르기와 끌기의 우선순위가 달라질 수 있던 자리다) · `verify-capture.sh` ✓ · `verify-capture-dismiss.sh` ✓.
- `verify-performance.sh` 는 **RSS 127.4MB 로 예산(100MB) 초과**. 내 것인지 가르려고 **고친 맥 파일 아홉을 HEAD 판으로 되돌리고**(새 파일 둘은 치우고) 같은 스크립트를 다시 돌렸다 — **126.9MB.** 차이 0.5MB, 잡음이다. 오늘의 워킹트리가 이미 넘겨 놓았고 이 장면(창 열 개)에는 내가 고친 화면이 하나도 서지 않는다. idle CPU 는 0% ✓.
- 폰 스모크(`LAZYMEMO_DERIVED=…/.build/ios-motion ./ios/scripts/uitest.sh`)는 23 중 6 실패 — 두 번 돌려 두 번 다 같은 여섯이고, 크래시 보고서 여섯 건이 **한 글자도 다르지 않은 같은 스택**(`closure #1 in themedUIColor` → `ShapeStyleResolver` → `updateOutputsAsync`, 즉 메인 밖). 다른 세션의 `ios/LazyMemo/Theme.swift` 다. `DateSheet.swift` **한 파일만** HEAD 로 되돌려 같은 시험을 돌리면 통과한다 — 내 판이 `.background(…, in: Capsule())` 로 `ShapeStyle` 경로를 타서 그 크래시를 드러낸 것이고 값 자체는 같다.

## 메모

`.build/ios-motion`(874MB)은 검증이 끝나고 지웠다 (용량 규칙 4). 진단용 임시 XCUITest 도 지웠다.