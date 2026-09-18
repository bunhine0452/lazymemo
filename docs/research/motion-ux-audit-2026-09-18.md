# 움직임·조작감 감사 2026-09-18 — 낱말을 하나로, 프레임을 되찾고, 과녁을 넓혔다

> 2026-09-18 · 사용자: 「사용자의 UX 사용감을 더더욱 증가시켜야하며, 절대 불편하면 안된다.
> 모션또한 매우 부드러워야하며, 최적화가 잘 되어있어야한다.」
>
> 범위: 서랍(`Drawer/**`) · 빠른 입력(`QuickCapture/**`) · 달력(`Calendar/**`) · 메뉴바(`MenuBar/**`) ·
> 종이 위의 작은 뷰들(`HoverSensor`·`RowTrash`·`PaperGrip`·`WindowDragSurface`·`LineMarker`·`PhotoStrip`·`PlaceCards`) ·
> 폰의 `StackView`·`HomeView`·`NowBand`·`PenBar`·`MonthGridView`·`CalendarView`·`DateSheet`·`TutorialView`·`PhotoCards`·`PlaceCards`·`TrashView`.
> `Views/NoteView`·`MemoNSTextView`·`Windows/**`·`Theme.swift`·`Settings/**`·`LazyMemoAssistant*`·위젯은 **다른 세션이 잡고 있어 읽기만 했다** — §5 에 넘길 것을 적었다.
>
> 방법: 소유 구역의 `withAnimation`·`.animation(`·`NSAnimationContext`·`animator()`·`.transition(`·`.spring`·
> `.easeInOut`·`Timer`·`asyncAfter`·`.onHover`·`.contentShape`·`hitTarget` 을 전부 훑고, 계산 속성이 `body` 안에서
> 몇 번 읽히는지를 손으로 셌다. 앞선 감사(`convenience-audit-2026-09-17.md`)가 잡은 것은 되풀이하지 않는다.

## 0. 한 문장

**움직임은 느린 게 아니라 제각각이었고, 렉은 그림이 아니라 글자를 짓는 데서 났다.**
같은 뜻의 움직임이 화면마다 네 가지 속도로 있었고(0.14 · 0.18 · 0.28 · 0.6초 · `.snappy`),
맥의 달력은 줄을 끌 때마다 **날짜 서식을 한 프레임에 84번** 지었으며(폰이 2026-09-17 에 고친 바로 그 결함),
서랍은 **손이 줄에 스치기만 해도 판 전체가 애니메이션 갈래를 탔다.**
움직임을 줄이라고 한 사람에게는 달력·목록·칩이 그대로 움직였다.

---

## 1. 움직임 — 낱말이 없었다

| # | 자리 | 무엇이 잘못 | 어긋난 원칙 | 고친 것 |
|---|---|---|---|---|
| 1.1 | `Drawer/DrawerView.swift:57-63` `easeOut(0.14)` · `Calendar/CalendarView.swift:93-96` `Theme.reveal(0.18)`/`Theme.settle(0.28)` · `Views/PlaceCards.swift:55` `.snappy` · `ios/StackView.swift:135` `easeOut(0.6)` · `ios/MonthGridView.swift:80,235` `.smooth(0.3)`/`easeInOut(0.18)` · `ios/{PenBar,TutorialView,PhotoCards,PlaceCards}` `.snappy` | **같은 뜻의 움직임이 여섯 가지 속도.** 우연히 비슷했을 뿐 같은 값이 아니라, 한쪽을 고치는 사람은 다른 쪽이 있는 줄 몰랐다 (§14.5 가 `PaperEdge` 에서 배운 것과 같은 결함) | WWDC17 802 Consistency — *"representing similar design features in similar ways"* · HIG Motion — *"Add motion purposefully"* | **`Motion` 낱말 셋** — `quick`(0.18) · `settle`(0.30) · `fly`(0.30, 창과 같은 곡선). 맥 `QuickCapture/Motion.swift`, 폰 `ios/LazyMemo/Motion.swift`. 두 기기가 **같은 숫자**를 본다 |
| 1.2 | `Drawer/DrawerWindowController.swift:22,238` 와 `DrawerView.swift:58` 이 0.30 과 `(0.22,0.9,0.24,1)` 을 **각각** 적고 있었다 | 창의 프레임과 안의 내용이 우연히 같은 값이라 맞았다. 한쪽만 고치면 «내용이 먼저 나오고 창이 뒤따라 커지는» 한 프레임 잘림이 돌아온다 | — (주석이 스스로 「짝이다」 라고 적어 두고 값은 나눠 놨다) | 둘 다 `Motion.flyDuration`·`Motion.flyTiming` 한 곳을 본다 |
| 1.3 | `ios/StackView.swift:135` — 새 줄이 밝아지는 데 `easeOut(0.6)` | 밝아지는 데만 0.6초. `Reveal` 이 1.4초 뒤 끄므로 **절반을 켜지는 데** 썼다 — 「방금 적은 줄이 어디 갔나」 | HIG Motion — 자주 일어나는 조작의 움직임은 짧게 | `Motion.settle`(0.30) |
| 1.4 | `QuickCapture/QuickCaptureView.swift:66-75` — 루트에 `.animation` **열 겹** | 값마다 한 겹씩 쌓여 있었고, 그 하나가 `model.pointed`(손이 얹힌 줄)였다 → **목록 위로 포인터가 지나가기만 해도 적고 있는 글 상자를 포함한 말풍선 전체**가 애니메이션 갈래를 탔다 | HIG Motion — *"In apps, generally avoid adding motion to UI interactions that occur frequently"* | 값 아홉을 `BubbleKey` 하나로 묶어 **한 겹**. 손이 얹힌 표시는 그 줄 안에서 (`row` 의 `.animation(…, value: isPointed)`) |
| 1.5 | `Drawer/DrawerView.swift:84-91` — 루트에 `.animation` **여덟 겹**, 그중 `value: pointed` | 같은 결함. 스물몇 줄짜리 목록·찾기 상자·폴더 띠가 손이 스칠 때마다 함께 움직였다 | 같음 | `PanelKey` 하나 + `opening` 한 겹. 호버는 `DrawerRow` 안으로 |
| 1.6 | `QuickCaptureView.swift:845-855` — 골라진/얹힌 자국을 `if/else` 로 **도형을 갈아 끼웠다** | SwiftUI 에게 그 둘은 다른 뷰라 자국이 사라졌다 새로 생긴다 — 색이 이어지지 않는다 | WWDC21 Demystify SwiftUI (구조적 정체성) | 도형 하나에 색만 바꾼다 (`rowFill`) |
| 1.7 | `ios/DateSheet.swift:123-131` — 시각 칩이 `if on { .borderedProminent } else { .bordered }` | 같은 결함. 누를 때마다 단추가 통째로 갈리고, 켜진 칩이 **옮겨 가는 것**이 안 보였다. 게다가 폴더 칩(`StackView.folderChip`)과 만듦새가 달라 같은 물건이 두 가지로 있었다 | 같음 + WWDC17 802 Consistency | 폴더 칩과 **같은 만듦새**의 단추 하나, 색만 바뀐다 |
| 1.8 | `Views/PlaceCards.swift:55` · `ios/PlaceCards.swift:42` — 점 **하나하나**에 `.animation(.snappy, value: page)` | 같은 뜻의 움직임이 점 수만큼. 자리가 다섯이면 수식어가 다섯 | HIG Motion — 목적 없는 움직임 | 줄 하나로 모으고 `Motion.quick` |
| 1.9 | `ios/PenBar.swift:92` — 애니메이션이 **가는 길의 단계에만** | 「내일 3시」를 치는 순간 날짜 칩이 **툭** 나타나며 펜이 한 줄 자라고 그만큼 목록이 뛰었다. **적는 중에 가장 자주 보는 움직임이 가장 거친 움직임**이었다 | WWDC18 803 — *"Touch and content should stay together"* (여기서는 글자와 칩) | `PenKey` 로 칩·되물음·비움 단추·생각 중을 함께 `Motion.quick` |

## 2. 움직임을 줄이라고 한 사람 (`accessibilityReduceMotion`)

HIG Accessibility: *"Replacing transitions in x-, y-, and z-axes with fades"*.
**끄지 않고 바꾼다** — 아예 끄면 무엇이 새로 생겼는지 알 길이 사라진다.
`Motion.quick/settle/fly(_ reduced:)` 가 `crossFade`(0.12) 또는 `instant`(0.01) 로 떨어뜨린다.

| 자리 | 전 | 후 |
|---|---|---|
| `Calendar/CalendarView.swift:93-96` | **환경값을 읽지도 않았다** — 달력 전체가 그대로 움직였다 | `@Environment(\.accessibilityReduceMotion)` + `Motion.*(reduceMotion)` |
| `Views/RowTrash.swift:52` | 같음 (지우는 단추가 늘 부풀었다) | 같음 |
| `QuickCapture/HotkeyRecorder.swift:149` | 같음 | 같음 |
| `Views/PlaceCards.swift` · `ios/PlaceCards.swift` · `ios/TutorialView.swift` · `ios/PhotoCards.swift` | 같음 | 같음 |
| `ios/StackView.swift` 셋(밝히기·스크롤·「봤어요」) | 같음 | 같음 |
| `ios/DateSheet.swift` | 같음 | 같음 |
| `ios/PenBar.swift` | 같음 | 같음 |
| `Drawer/**` · `ios/MonthGridView.swift` | **이미 지키고 있었다** (2026-08-31 · 2026-09-17) | 낱말만 `Motion` 으로 |

## 3. 최적화 — 렉은 그림이 아니라 글자를 짓는 데서 났다

| # | 자리 | 무엇이 | 얼마나 | 고친 것 |
|---|---|---|---|---|
| **3.1** | `Calendar/CalendarView.swift` — `cell()` 이 `dayHelp(date)` 를 **둘씩**(`.help` + 소리 이름표) 부르고, `dayHelp` 는 `DateWords.monthDay` → **새 `Date.FormatStyle` 을 만들어 서식**한다 | 칸 42 × 2 = **한 `body` 에 84번**. 그리고 `carry(_:)` 의 `DragGesture.onChanged` 가 `grip` 을 `@State` 에 적으므로 **줄을 끄는 매 프레임** `body` 가 돈다 — 120Hz 의 8ms 예산을 서식만으로 먹는다. **폰이 2026-09-17 에 고친 바로 그 결함** (`20260917/Bugs/1913_bug_phone-calendar-swipe-jank.md`) | 격자를 `Equatable` 자식으로 뗐다 (**신규** `Calendar/CalendarGrid.swift` 의 `MonthPanel`). 값(달·판형·고른 날·오늘·놓을 자리·`inkVersion`)이 그대로면 `body` 를 건너뛴다. 이름표는 **판마다 한 벌**(42개)만 짓는다. 끄는 동안 실제로 다시 그려지는 것은 겨누는 칸 하나 |
| 3.2 | 같은 파일 — `monthInk` 가 42일을 훑어 `presence`·`stains` 를 만든다 | 위와 같은 매 프레임 | 3.1 과 함께 판 안으로. 판이 다시 그려질 때만 |
| **3.3** | `Drawer/DrawerRow.swift:40-57` — `snippet` 이 `rest` 를 부르는 계산 속성. `rest` 는 본문 전체를 `split` → `map` → `join` → `trim` | 줄을 한 번 그릴 때마다 본문을 **두 번** 쪼갠다. 그리고 호버가 `DrawerView` 의 `@State` 라 손이 스칠 때마다 스물몇 줄이 **전부** 다시 그려졌다 | `lines` 한 번에 짓고, `DrawerRow: Equatable` + `.equatable()`. 호버는 줄이 스스로 안다 → 손이 옮겨 가면 **떠난 줄과 닿은 줄 둘만** 다시 그려진다 |
| 3.4 | `Drawer/DrawerRow.swift:124,161` + `DrawerView.swift:565-566` — `MemoTimeLabel.text(for:)` 가 줄마다 **세 번** | `MemoTimeLabel` 은 부를 때마다 `Date()` 와 `Calendar.current` 를 새로 뜬다. 스무 줄이면 판 하나에 예순 번 | 부르는 쪽이 줄마다 **한 번** 짓고 `DrawerRow(time:)` 로 넘긴다 |
| **3.5** | `ios/StackView.swift:41-52` — `nowCards` 와 `listed` 가 계산 속성이고 `listed` 가 `nowCards` 를 부른다. `body` 안에서 `nowCards` 4번 · `listed` 6번 읽힌다 | `Recall.nowCards(store.memos…)` 와 `MemoFolders.filter` 가 **메모 전부를 열 번 넘게** 훑는다. 화면 한 번 그릴 때마다 | `body` 머리에서 **한 번만** 세어 지역 값으로 들고 다닌다 (`listed(excluding:)`) |
| 3.6 | `ios/CalendarView.swift:21-32` — `marks`·`today` 가 계산 속성 | 같은 `body` 에서 격자와 목록이 각각 읽어 일정 목록을 두 번 훑는다 | 같은 방법 |
| 3.7 | `ios/MonthGridView.swift:49` — `weekdays = DateWords.weekdayLetters()` 가 **인스턴스 속성** | 부모가 다시 그릴 때마다 `Calendar` 를 뜨고 일곱 자를 다시 서식. 말은 앱이 도는 동안 안 바뀐다 | `static let` |
| 3.8 | 타이머·되풀이 애니메이션 | `Timer`·`repeatForever`·`autoreverses` 는 **소유 구역에 하나도 없다.** `TimelineView(.animation)` 은 `ThinkingInk` 뿐이고 `phase == .thinking` 일 때만 붙는다 — 숨은 것이 도는 자리는 없다. `DayClock`·`DueClock`·`StackView` 의 시계는 `Task.sleep` 으로 **다음 경계까지** 자므로 유휴 CPU 0% 를 지킨다 (§11) | 고칠 것 없음 — 확인만 |
| 3.9 | `ScrollView` + 비-lazy `VStack` | 서랍 목록(`DrawerView.list`)·빠른 입력의 넓힌 목록 — 둘 다 상한이 있다(서랍은 창 높이로 잘리고 `plan.scrolls`, 빠른 입력은 20줄). `LazyVStack` 은 `scrollTo` 와 다투므로 **바꾸지 않는다** | — | 고칠 것 없음 — 근거를 남김 |
| 3.10 | `drawingGroup` | 후보는 격자의 얼룩 한 장(`InkBleedLayer`)뿐인데, 그 위에 **글자**(날짜 숫자)가 겹친다. `drawingGroup` 은 텍스트를 래스터화해 흐려지므로 **넣지 않는다** | — | 고칠 것 없음 — 근거를 남김 |

## 4. 조작의 걸림 — 과녁과 대답

| # | 자리 | 무엇이 | 어긋난 원칙 | 고친 것 |
|---|---|---|---|---|
| 4.1 | `ios/NowBand.swift:91-99` — 「봤어요」 알약이 `minHeight: 28`, 그리고 **카드 전체가 단추인 그 안에** 있다 | 과녁이 좁으면 「봤어요」를 누르려다 **메모가 열린다.** 되돌리는 값이 다른 두 조작이 3pt 사이에 있었다 | HIG Buttons — *"a button needs a hit region of at least 44x44 pt"* | 알약은 28 그대로, **누르는 자리만** 44×44. 늘어난 만큼은 카드 여백을 먹으므로 보이는 것은 그대로 |
| 4.2 | `Views/PlaceCards.swift` — 「가는 길」이 `.padding(.vertical, 3)` + `Theme.micro` → 과녁 **19pt** | 이 카드에서 누를 수 있는 것은 이것 하나인데 가장 작았다 | HIG Accessibility — 최소 28×28pt | `hitTarget(28)` |
| 4.3 | `ios/DateSheet.swift` — 시각 칩이 `.bordered` 캡슐 + `.subheadline` → **34pt 남짓** | 이 시트에서 가장 자주 누르는 것 | HIG Buttons 44×44 | `minHeight: 44` |
| 4.4 | `ios/CalendarView.swift` — 날을 눌렀을 때 대답이 **아래 목록이 바뀌는 것뿐** | 고른 날이 비어 있으면 「누른 것」과 「아무 일도 없는 것」이 똑같이 보인다 | HIG Feedback — *"confirm that a significant action or task has completed"* | `.sensoryFeedback(.selection, trigger: picked)` |
| 4.5 | `ios/MonthGridView.swift` — 달이 넘어가도 손끝에 아무것도 없다 | 판이 미끄러지는 데 0.3초가 걸리므로 눈보다 손이 먼저 알아야 한다. 튕겨 되돌아온 손짓과 실제로 넘어간 손짓이 **손에는 구별되지 않았다** | HIG Feedback — *"Feedback helps us to operate cars confidently and safely"* | `.sensoryFeedback(.selection, trigger: ordinal(grid))` — 정본이 바뀐 때만 울리므로 되돌아온 손짓에는 조용하다 |

### 확인만 하고 손대지 않은 것

- **호버 떨림(hover → 자리 바뀜 → 호버 잃음)은 없었다.** `DrawerRow` 의 조작은 시각 조각과 **같은 줄의 같은 끝**에서 바뀌고(제목이 안 밀린다), 달력의 줄 조작은 줄 **위에 겹쳐** 뜬다 (§14.4 가 이미 고쳐 둔 것 — 「앞선 판은 넷을 줄 안에 밀어 넣어 포인터가 오면 줄이 다시 짜였다」).
- **끌기 중 상태 갱신**: 달력의 `carry` 와 폰의 `MonthGridView` 둘 다 손가락을 그대로 따라간다(`@GestureState`/`@State`). 폰은 놓을 자리를 `predictedEndTranslation` 으로 판정해 **짧고 빠른 튕김**도 넘어간다 — WWDC18 803 그대로. 바꿀 것 없음.
- **포커스 되돌리기**: 서랍을 접을 때 `NSApp.deactivate()`, 빠른 입력도 같다 (§7.1 다섯째 규칙). 폰의 펜은 `focusRequest` 를 껐다 다음 턴에 켠다 (2026-09-16 의 「캐럿만 서고 키보드가 안 오르던 것」). 걸리는 자리 없음.
- **키보드 돌려주기**: 폰의 목록·달력 둘 다 `.scrollDismissesKeyboard(.immediately)`. 있음.

---

## 5. 남은 것

- **사람 눈·손이 필요한 것.** 아래 §6 의 검증은 빌드·테스트·시뮬레이터까지다. 「부드러워졌는가」는 실기기와 사람 눈이 답한다 — 특히 ① 맥 달력에서 줄을 격자로 끌 때의 프레임(시뮬레이터도 `Instruments` 도 이 저장소에 없다) ② 서랍을 펼치고 접을 때 창과 내용이 한 몸으로 가는지 ③ 폰에서 달 넘김의 햅틱이 과한지.
- **`Views/Theme.swift` 의 `reveal`·`settle` 이 남아 있다** (다른 세션이 잡고 있는 파일). 지금은 `Motion` 과 값이 **거의** 같지만(0.18 / 0.28 ↔ 0.30) 두 벌이다. 넘길 것 — §7.
- **`QuickCaptureView.swift` 1027줄 · `CalendarView.swift` 924줄.** 이번에 달력에서 105줄을 떼어 냈고(→ `CalendarGrid.swift`) 빠른 입력은 26줄만 늘었다(묶음 키). `{#split-large-files}` 는 그대로 남는다 — 빠른 입력의 결과 줄(`row`·`resultRows`·`overflowLine`)을 `CaptureResultRow.swift` 로 떼면 `model.pointed` 가 바뀔 때 말풍선 전체가 아니라 줄만 다시 그려진다. **이번에는 하지 않았다** — 접근성 식별자가 걸린 뷰라 시험을 함께 옮겨야 하고, 애니메이션 겹을 걷어낸 것만으로 눈에 보이는 문제는 사라졌다.
- **`model.pointed` 는 여전히 관찰 대상이라** 손이 목록 위를 지나면 `QuickCaptureView.body` 가 다시 돈다 (애니메이션은 안 탄다). 없애면 `CaptureHoverTests` 가 지키는 모델 계약(목록이 바뀌면 얹힌 것이 풀린다)이 깨지므로 남긴다. 위의 분리가 답이다.
- **`NoteWindowController` 의 애니메이션 다섯**(`riseBriefly`·`settle` 등)은 다른 세션 구역이라 읽기만 했다 — `Motion` 을 쓰면 종이가 앞으로 나왔다 내려앉는 몸짓과 서랍이 같은 속도가 된다. §7.

---

## 6. 검증 — 실제로 돌린 것과 나온 것

> **같은 워킹트리에서 다섯 세션이 동시에 일하는 날이었다.** 아래의 실패 중 내 구역의 것은
> 하나도 없고, 남의 미완성 코드가 내 검증을 막은 자리는 그렇게 적었다.

| 무엇 | 결과 |
|---|---|
| `swift build` | **통과.** 내 파일에서 오류·경고 0. (두 번 막혔다 — `LazyMemoCore/Theme/ThemeSpec.swift` 의 `ThemeCatalog` 미정의, `LazyMemoAssistant/Digest.swift` 의 `L` 미정의. 둘 다 다른 세션의 편집 중인 파일이라 고쳐질 때까지 기다렸다) |
| `./scripts/test.sh --filter LazyMemoUITests` | **377 tests in 56 suites, 15 issues.** 15 이슈는 전부 테마 시험 넷 — `ThemeContrastTests`(「기본 테마의 화면 색이 앞선 판 그대로다」·「글자 한 칸이…」)와 `PaperPaletteTests`(「링크는 여섯 색…」·「숯색 종이는…」). **내 구역의 스위트는 전부 초록**: 「서랍 — 고르기·폴더·되돌리기」·「빠른 입력 — 손이 얹힌 줄과 고른 줄」·「빠른 입력 — 목록에서 지우기」·「자리 — 꺼내 주는 것과 꺼내 두는 것」·「Esc — 종이를 치운다」·「빠른 입력 말풍선 자리」 외 |
| `LAZYMEMO_DERIVED=…/.build/ios-motion ./ios/scripts/uitest.sh` | **23 중 6 실패 — 전부 같은 한 가지 크래시.** §6.1 (두 번 돌렸고 두 번 다 같은 여섯) |
| `scripts/verify-drawer.sh` · `verify-drawer-mouse.sh` · `verify-capture.sh` · `verify-capture-dismiss.sh` | **전부 통과.** §6.2 |
| `scripts/verify-performance.sh` | **RSS 127.4MB — 예산 100MB 초과.** 내 변경 때문이 아님을 측정으로 갈랐다 (§6.3). idle CPU 0% ✓ |

### 6.1 폰 스모크의 여섯 실패는 **테마 세션의 크래시 하나**다

`testDateSheetShowsTheClock` · `testTwoPlacesMakeTwoCards` · `testRevisitWritesSurfaceAndNowBandShowsPinned` ·
`testFirstLaunchShowsTutorialThenThePen` · `testDateChipStaysWhenTurnedOff` · `DeepLinkTests.testWriteLinkRaisesThePen`.

임시 XCUITest 로 화면과 크래시 보고서를 떠서 원인을 찍었다 (확인 뒤 지웠다).
`~/Library/Logs/DiagnosticReports/LazyMemo-2026-09-18-19*.ips` 여섯 건이 **한 글자도 다르지 않은 같은 스택**이다:

```
EXC_BREAKPOINT (SIGTRAP)
libdispatch          _dispatch_assert_queue_fail
libswift_Concurrency _swift_task_checkIsolatedSwift
LazyMemo.debug       closure #1 in themedUIColor(_:)          ← ios/LazyMemo/Theme.swift (테마 세션의 새 파일)
UIKitCore            -[UIDynamicProviderColor _resolvedColorWithTraitCollection:]
SwiftUICore          PlatformColorProvider.resolveHDR(in:)
SwiftUICore          ShapeStyleResolver.updateValue()
SwiftUICore          ViewGraph.updateOutputsAsync(at:)        ← 메인 스레드가 아니다
```

**`themedUIColor` 의 `UIColor { traits in … }` 공급자가 `@MainActor` 인 `ThemeRuntime.shared` 를 읽는다.**
SwiftUI 는 `ShapeStyle` 을 **비동기로**(`updateOutputsAsync`) 풀 수 있고, 그때 그 공급자는 메인 큐가 아니다 →
Swift 6 격리 검사가 트랩을 건다. 색이 바뀌는 어떤 화면에서도 날 수 있다.

내 것인지 가르려고 `ios/LazyMemo/DateSheet.swift` **한 파일만** HEAD 판으로 되돌려 같은 시험을 돌렸다 —
통과했다. 내 판이 `.background(Theme.accent, in: Capsule())` 로 **`ShapeStyle` 경로**를 타서 그 크래시를
드러낸 것이고, 앞선 `.tint(...)` 판은 우연히 그 경로를 안 탔을 뿐이다. 값 자체는 같다.
**고칠 곳은 `themedUIColor` 다** (§7).

### 6.2 맥의 손 검증 — 전부 통과

`verify-drawer.sh`·`verify-capture*.sh` 는 첫 줄에서 `pkill -f "$BIN"` 을 한다. 검증을 시작할 때
`.build/out/Products/Debug/LazyMemo` 가 **다른 세션의 것으로 떠 있어서**(시작 55초 전) 그대로 돌리면
남의 앱을 죽인다. 내가 띄우지 않은 것은 죽이지 않는다 — 그 세션이 앱을 내릴 때까지 기다렸다 돌렸다.

```
✓ 서랍        모서리고정=true 제자리복귀=true 계획크기=true 앞으로=true 내려앉음=true 탭클릭=Surface
✓ 서랍 (마우스)  탭 잡아 끌기 Δ120,80 · 끌기 뒤에도 접힌 채 · 탭 누르기 → 펼침 440×344 ·
              머리 줄(글자 위) 잡아 끌기 Δ-100,-60 · × → 접힘 · 앞에 선 판의 머리 줄 끌기 · 다른 앱 클릭 → 접힘
✓ 다른 앱이 앞에 있어도 빠른 입력 상자가 화면에 올라왔습니다
✓ 안쪽 클릭은 놔두고, 앱 안의 바깥 클릭은 상자를 치웁니다
```

머리 줄 끌기와 탭 끌기가 살아 있다는 것이 이번 변경에서 가장 중요한 확인이다 — `DrawerRow` 가
제 호버를 갖게 되면서 누르기·끌기의 우선순위가 달라질 수 있는 자리였다.

### 6.3 `verify-performance.sh` — RSS 예산을 넘는다. **내 변경 때문이 아니다**

```
RSS       127.4 MB   (예산 100 MB)      ✗
idle CPU  0.0 %      (예산 0%)          ✓
```

설계문서 §11 의 실측은 **88.8MB** 였다. 내 것인지 가르려고 **내가 고친 맥 파일 아홉을 HEAD 판으로
되돌리고**(새 파일 둘은 치우고) 같은 스크립트를 다시 돌렸다:

```
RSS       126.9 MB   ← 내 변경이 하나도 없는 상태
RSS       127.4 MB   ← 내 변경이 든 상태
```

**차이 0.5MB — 잡음 범위다.** 오늘의 워킹트리(테마 여덟 벌·비서의 웹 답·종이 맞춤·위젯)가 이미
예산을 넘겨 놓았고, 이 창 열 개짜리 장면에는 내가 고친 화면(서랍·달력·빠른 입력)이 **하나도 서지
않는다.** 숫자를 다시 잡는 것은 그 변경들의 몫이라 여기 적어 넘긴다 (§7).

## 7. 내 구역 밖에 부탁할 것

| 어디 | 무엇 | 왜 |
|---|---|---|
| `Sources/LazyMemoUI/Views/Theme.swift:171-172` | `static let reveal`·`settle` 을 `Motion.quick`·`Motion.settle` 로 **위임**시키거나 지우기 | 움직임의 낱말이 두 벌이면 §14.5 가 `PaperEdge` 에서 배운 것을 그대로 되풀이한다. 값도 0.28 ↔ 0.30 으로 어긋나 있다 |
| `Sources/LazyMemoUI/Windows/NoteWindowController.swift` | `rise`/`riseBriefly`/`settle` 의 `NSAnimationContext` 를 `Motion.flyDuration`·`Motion.flyTiming` 으로 | 종이가 앞으로 나왔다 내려앉는 몸짓과 서랍이 펼쳐지는 몸짓은 **같은 종류의 움직임**이다 (§7.2 가 「달력이 같은 몸짓을 한다」고 적은 그것) |
| `ios/LazyMemo/Theme.swift` | 움직임 값을 새로 만들지 말고 `ios/LazyMemo/Motion.swift` 를 쓸 것 | 같은 이유 |
| `ios/LazyMemo/MemoRowView.swift` | 목록 줄이 `Equatable` 이면 `StackView` 의 `ForEach` 가 줄마다 다시 그리지 않는다 (지금은 `List` 가 막아 주지만 판이 커지면 드러난다) | 3.3 과 같은 종류 |
| **`ios/LazyMemo/Theme.swift` — `themedUIColor`** | **크래시다** (§6.1). `UIColor { traits in … }` 공급자 안에서 `@MainActor` 인 `ThemeRuntime.shared` 를 읽지 말 것 — SwiftUI 가 `ShapeStyle` 을 메인 밖에서 푼다. 값을 `nonisolated(unsafe)` 스냅숏(또는 `Mutex`/`OSAllocatedUnfairLock` 로 지킨 평범한 저장소)에 두고 공급자는 **그 스냅숏만** 읽게 하면 된다. 테마가 바뀌면 스냅숏을 갈고 `generation` 을 올려 다시 그리게 한다 | 폰 스모크 여섯 건이 이것 하나로 빨갛다 |
| `Sources/LazyMemoCore/Theme/**` · `Tests/LazyMemoCoreTests/Theme*` · `Tests/LazyMemoUITests/{ThemeContrast,PaperPalette}Tests` | 맥 시험 15 이슈 (§6) | 같은 세션의 진행 중인 작업 |
| **RSS 예산** (§6.3) | 88.8MB → **126.9MB**(내 변경 없이 잰 값). 설계문서 §11 의 표와 「창 24개 상한」이 이 숫자 위에 서 있다 — 오늘 들어온 변경들이 한 번 다시 재야 한다 | §7 창 24개 상한이 이 숫자를 지키는 장치다 (§11) |
