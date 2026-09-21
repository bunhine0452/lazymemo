# 위젯 설계 — 홈 화면 위의 한 장

2026-09-18 · 「지금」·「다음 약속」·「달력」·「적기」 네 위젯의 얼굴 · 구현은 `ios/LazyMemoWidgets/`

원칙마다 HIG 원문을 단다 (`docs/research/apple-design-principles.md` 와 같은 규칙).
인용의 출처는 셋뿐이다 —
**HIG**: <https://developer.apple.com/design/human-interface-guidelines/widgets> ·
**HIG A11y**: <https://developer.apple.com/design/human-interface-guidelines/accessibility> ·
**WWDC23 10028**: <https://developer.apple.com/videos/play/wwdc2023/10028/> ·
**WidgetKit**: <https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities>.

## 0. 한 문장

**홈 화면의 위젯은 앱의 축소판이 아니라 「지금 뭘 하지」에 답하는 종이 한 장이다.**
> "Create a layout that provides essential information at a glance and allows people to view additional details by taking a longer look." (HIG)

## 1. 한 장의 문법 — 네 위젯이 같은 낱말을 쓴다

| 조각 | 규칙 | 글·색 |
|---|---|---|
| 머리 한 줄 (`WidgetHead`) | 왼쪽 = 무엇인지, 오른쪽 = 언제인지. 좁으면 **날짜가 먼저 물러난다** (`ViewThatFits`) | `.caption2.weight(.semibold)` + `tracking(0.8)`, `secondary` |
| 줄머리의 색 획 (`inkBar`) | 3pt 캡슐 하나가 메모 색을 말한다. 카드마다 종이·테두리를 깔지 않는다 | `MemoColor.widgetInk` |
| 이유 한 줄 | 「다시 보기 · 오후 3:00」 — **1초에 읽히는 것** | `.caption2.weight(.medium).monospacedDigit()`, `accentInk` |
| 제목 | **3초에 읽히는 것**. 가족마다 1~3줄 + `minimumScaleFactor(0.9)` | `.subheadline.weight(.semibold)`, `ink` |
| 고정 칸 줄 (`AgendaRow`) | 날 46pt · 시각 58pt · 제목 — 줄마다 같은 자리 | `.caption.monospacedDigit()` |
| 빈 자리 (`EmptyFace`) | 한 줄 + 「적기」 문 | `.subheadline` + accent 캡슐 |

글자는 전부 **텍스트 스타일**이고 가장 작은 것이 `.caption2` = 11pt 다.
> "Avoid very small font sizes. In general, display text using fonts at 11 points or larger." /
> "Prefer using the system font, text styles, and SF Symbols." (HIG)

색 획을 쓴 이유는 이 앱의 규칙이기도 하다 — 「색은 테두리와 왼쪽에서 번지는 잉크로만 드러난다」(설계문서 §14.4).
덤으로 위젯이 이제 **메모 색을 말한다**: 앞선 판에는 없던 정보다. 색만으로 말하지는 않는다 — 이유는 낱말과 SF Symbol 이 함께 짊어진다.
> "Convey meaning without relying on specific colors to represent information." (HIG)

## 2. 여백과 과녁

**바깥 여백을 얹지 않는다.** 시스템이 준다.
> "Use the standard margin width for widgets — 16 points for most widgets… Additionally, note that widgets use smaller margins on the desktop on Mac and on the Lock Screen, including in StandBy." (HIG)

바탕은 `containerBackground(for: .widget)` 하나 — 크림 종이 + 아주 옅은 도트 그리드(`PaperGround`).
> "Note how I am using the containerBackground modifier here to define the background for my widget. This allows it to show up in all the new supported locations on the Mac and iPad." (WWDC23 10028)

과녁: 카드 줄 44(큰)·34(중간), 「적기」 44, 「봤어요」 44×44(큰)·36×34(중간), 달력 칸 ≈42×40, 「오늘부터」 줄 30.
> "Pay attention to the size of targets and make sure people can tap or click them with confidence." (HIG) ·
> 「과녁: iOS 기본 44×44pt, 최소 28×28pt」 (HIG A11y)

**중간 위젯의 「봤어요」에 44 를 주지 않았다** — 줄 높이가 34 라 44 를 주면 위아래 줄의 과녁이 겹친다. 겹친 과녁은 44 보다 나쁘다.
「오늘부터」 줄이 30 인 것도 같은 결의 타협이다: 큰 위젯에 네 줄이 들어가야 하고, 그 줄들은 사이 여백까지 합쳐 38 쯤의 자리를 갖는다.

## 3. 위젯 × 가족

### 「지금」 (`NowWidget` / `NowFaces`) — small · medium · large · accessoryRectangular · accessoryInline

한 문장: **오늘 다시 볼 것·오늘 일정·고정한 메모 중 지금 가장 앞의 것** (`Recall.nowCards` — 앱의 띠와 같은 답).

| 가족 | 1초 | 3초 | 조작 |
|---|---|---|---|
| small | 이유·시각 | 제목 3줄, 바닥에 「외 N장」 | 전체가 그 메모 |
| medium | 세 장의 이유 | 제목 각 1줄 | 줄 = 메모, 오른쪽 = 「봤어요」 |
| large | 세 장 + 「다음」 머리 | 제목 각 2줄 + 오늘 뒤 일정 4줄 | 줄마다 그 메모 |
| accessoryRectangular | 이유 한 줄 | 제목 2줄 | 전체가 그 메모 |
| accessoryInline | 시각 + 제목 | — | 과녁 하나뿐 |

> "Small widgets use their limited space to typically show a single piece of information while larger sizes support additional layers of information and actions." /
> "Avoid expanding a smaller widget's content to simply fill a larger area." (HIG)

큰 가족의 아래 절은 `WidgetAgenda.upcoming(limit: 4)` — 머리 16 + 카드 3×52 + 「다음」 22 + 줄 4×32 ≈ 322 로 큰 위젯의 350 안에 든다. 다섯째 줄은 잘리고, **잘린 줄은 없는 줄보다 나쁘다.**

### 「다음 약속」 (`NextWidget`) — small · accessoryRectangular · accessoryCircular · accessoryInline

한 문장: **다음 약속이 몇 시이고, 언제 나가야 하나** (`WidgetAgenda.next`).

큰 글자가 시각, 그 아래 제목, 마지막 두 줄이 「14:34 출발 · 2호선」과 **스스로 흐르는 남은 시간**이다.
남은 시간은 `Text(_:style: .relative)` — 장면을 더 만들지 않고 시스템이 그 글자만 고쳐 그린다. 출발이 아직 오지 않았으면 출발까지, 지났으면 약속까지 센다. 자리가 얕으면 `ViewThatFits` 가 출발 줄을 접고 남은 시간만 남긴다 — 그것이 더 급한 말이다.
동그라미는 24시간 시계(`RouteNote.clock`) — 좁은 자리에서 「오후 3:00」은 넘친다.

### 「달력」 (`CalendarWidget` / `CalendarFaces`) — small · medium · large

한 문장: **이번 달 어디에 무엇이 있나** (`WidgetAgenda.monthMarks`).

- small: 요일 · 큰 날짜 · 「일정 N」.
- medium: 왼쪽 오늘 칸 + 오른쪽 격자.
- large: 「2026년 9월 … 9월 18일 (금)」 머리 + 격자 + 「오늘부터」 4줄.

**오늘은 채운 원이 아니라 손으로 그린 동그라미다** (`HandRing`) — 맥 달력의 `PenMarks` 와 같은 몸짓(설계문서 §10.3). 채우면 숫자가 종이를 떠나 「고른 칸」으로 읽히고, 자로 그은 선은 손으로 읽히지 않는다. `Canvas` 하나에 세 도막으로 굵기를 줄여 가며 한 바퀴를 조금 넘겨 긋는다 — 난수 없이 상수로, 장면마다 같은 그림. 숯색 종이에서는 획을 `accentInk`(밝은 세이지)로 바꾼다.

### 「적기」 (`WriteWidget`) — small · accessoryCircular · accessoryInline

한 문장: **펜을 올리는 문 하나.** 얼굴은 앱 아이콘의 두 글줄(`BrandMark`). 단추를 그려 넣지 않는다 — 과녁 안에 작은 과녁을 파는 꼴이다.
> "When people interact with your widget in areas that aren't buttons or toggles, the interaction launches your app." (HIG)

## 4. 조작 — 「봤어요」와 체크상자, 둘뿐

카드 오른쪽의 체크 하나가 그 자리에서 카드를 내려놓는다 (`SeenIntent` → `NowSeen.putDown`, App Group defaults).
> "Offer interactivity while remaining glanceable and uncluttered. Multiple interaction targets… might make sense for your content, but avoid creating app-like layouts in your widgets." (HIG) ·
> "Note that only Button and Toggle using AppIntent are supported in interactive widgets." (WWDC23 10028)

- 인텐트는 **확장 타깃에** 있다. 앱에도 두면 앱이 같은 단추를 재사용할 수 있지만, 앱 쪽은 이미 자기 `putDown` 을 갖고 있다.
  > "If you adopt the AppIntent protocol, add your custom app intent to your widget extension target and your app target." (WidgetKit)
- 돌아오면 시간표가 다시 불린다 — 우리가 `WidgetCenter` 를 부르지 않는 이유.
  > "When you return from the perform() function, the system reloads the widget's timeline using its timeline provider." (WidgetKit)
- 앱은 앞으로 나올 때 `NowSeen.load()` 를 다시 읽는다 (`StackView` 의 `didBecomeActive`) — 그래서 위젯에서 내려놓은 것이 띠에서도 내려간다.
- **읽고-고치고-쓰기를 한 걸음으로 묶는다** (`NowSeen.putDown`). 앱과 위젯이 각자 들고 있던 표를 통째로 덮어쓰면 한쪽이 방금 내려놓은 것이 조용히 되살아난다.

**맥에는 없다.** 맥 위젯에는 App Group entitlement 가 없어(`ios/Config/LazyMemoWidgets-macOS.entitlements`) `NowSeen` 이 확장 제 집의 defaults 로 떨어진다 — 눌러도 앱의 띠는 그대로다. 아무 일도 안 하는 단추를 두느니 두지 않는다.

**체크상자는 파일에 적는다 (2026-09-21).** 큰 「지금」의 체크리스트 카드 밑에 아직 안 한 칸이 셋까지 서고(`CheckRow` → `CheckIntent` → `WidgetChecklist.check`), 누르면 그 자리에서 체크된다 — 편의성 감사 §3.4 의 셈(앱을 열어 종이를 찾으면 셋, 여기서는 하나). 「봤어요」와 달리 파일에 적는 이유는 그 사실이 이 기기의 기억이 아니라 메모의 것이라서다 — 맥의 종이도 같은 칸이 체크돼야 한다. 확장이 파일을 고치는 **유일한** 자리이므로 규칙을 좁게 잡았다: 바꾸는 것은 괄호 안 **한 글자**와 `updated` 뿐(편집기의 `toggleCheckbox` 와 같다), 줄은 자리가 아니라 글로 찾아 그 사이 다른 기기가 메모를 고쳤어도 엉뚱한 줄을 뒤집지 않으며(`Checklist.toggle`), 읽은 본문의 hash 로 쓰기를 걸어 그 사이 파일이 바뀌었으면 손대지 않는다. 첨부·되풀이·인덱스·「다 체크한 목록은 물러난다」(`Tidy`)는 그대로 앱이 든다 — 앱은 앞으로 나올 때 파일을 대조한다(`reconcile`). 칸 하나가 「다음」 줄 하나를 쓴다 — 오늘 할 칸이 내일 뒤의 일정보다 앞이다. 과녁은 줄 전체(28pt·전폭)다: 16pt 네모만 맞히게 하면 엄지가 세 번에 한 번 빗나간다. `Toggle` 이라 누른 순간 칸이 채워지고, 시간표가 다시 그려지면 그 줄이 목록에서 빠진다. 중간·작은·잠금 화면 가족에는 없다 — 줄 높이가 없다.
> "Note that only Button and Toggle using AppIntent are supported in interactive widgets." (WWDC23 10028)

**「하루 미루기」는 여전히 넣지 않았다.** 그것은 `at`·`due` 를 고쳐 되풀이(`Tidy.rolled`)·알림 예약·달력이 함께 움직여야 하는 일이라 한 글자 바꾸기와 다르다. 맥에서 메모 폴더를 옮겨 둔 사람의 열쇠(`VaultBookmark`)도 앱만 쥐고 있다. 확장이 반쪽 규칙으로 파일을 고치기 시작하면 두 화면이 다른 메모를 갖게 된다 — 체크상자가 선을 그은 자리다.

## 5. 렌더 모드 — 색은 `WidgetTheme` 한 곳에서 나온다

얼굴은 색을 직접 알지 않는다. `@Environment(\.widgetTheme)` 로 받고, 루트가 렌더 모드를 보고 한 벌을 고른다 (`WidgetTheme.resolved(_:)`).

| 모드 | 벌 | 무엇이 달라지나 |
|---|---|---|
| `.fullColor` | `paper` | 크림·포레스트·도트 그리드·메모 색 (라이트·다크·대비 높임 네 벌, `Shade`) |
| `.accented` (iOS 18 틴트·선명) | `mono` | 계층색만. 도트 그리드·일/토 잉크를 접는다 |
| `.vibrant` (잠금 화면) | `mono` | 같음 |

> "Group widget components into an accented and a primary group." / "On iPhone, iPad, and Mac, the system tints primary and accented content white." /
> "In the accented rendering mode, the system removes the background and replaces it with a tinted color effect…" (HIG)

`widgetAccentable()` 은 **이유 줄·시각·오늘 동그라미·「적기」**에 건다 — 틴트가 켜지면 그것들이 강조 조에 선다.
StandBy 는 검은 바탕 위의 두 장이다. `mono` 가 바탕색을 접으므로 그대로 맞는다.
> "To seamlessly blend with the black background, don't use background colors for your widget when it appears in StandBy." /
> "Limit usage of rich images or color to convey meaning in StandBy." (HIG)

**테마를 붙일 자리는 `WidgetTheme.paper` 한 곳이다** (`WidgetPaper.swift`). `ThemeCatalog` 가 서면 그 `static let` 을 `static func paper(_ choice:)` 로 바꾸고 `resolved(_:)` 가 그것을 부르게 하면 끝난다 — 다른 파일은 손대지 않는다.

## 6. 프라이버시

잠금 화면의 위젯은 잠긴 동안 `.privacy` 로 가려진다. **제목에만** `privacySensitive()` 를 건다 — 이유와 시각은 남는다. 「무언가 3시에 있다」는 남기고 「치과 예약 — 강남역 3번 출구」는 가린다.
> "SwiftUI redacts views marked with this modifier when you apply the privacy redaction reason." (SwiftUI `privacySensitive(_:)`)

이는 RECALL_PLAN 의 약속과 같은 결이다 — 「잠금 화면에는 메모 제목이 표시됨을 켜기 전에 설명한다」.

## 7. 시간표와 관련성

- 「지금」·「다음」: `WidgetAgenda.moments` — 지금 + 각 메모의 `surface`·`at`(36시간 안) + 다음 자정, 최대 12개, `.atEnd`.
- 「달력」: `WidgetAgenda.dayChanges` — 지금 + 자정 셋.
- 「적기」: `.never`.
- 앱이 파일을 바꾸면 `WidgetRefresher` 가 2초로 모아 다시 부른다.
- 장면 사이의 애니메이션은 시스템이 한다.
  > "Widget don't have state. Instead, they create a timeline made of entries… SwiftUI determines what is the same and what is different between the entries, and animates the parts that have changed." (WWDC23 10028)
- 남은 시간만은 장면을 쓰지 않는다 (`.relative`) — 하루 갱신 예산을 카운트다운에 쓰지 않으려고.
  > "Prefer dynamic information that changes throughout the day." (HIG)

## 8. 빈 상태와 갤러리

빈 위젯은 한 줄과 **문 하나**다 — 「펼칠 것이 없어요」 + 「적기」. 「없음」만 적힌 화면은 할 일을 남기지 않는다.
> "Offer simple, relevant functionality and reserve complexity for your app. Useful widgets offer an easy way to complete a task or action that's directly related to its content." (HIG)

갤러리(`context.isPreview`)에는 `WidgetSample` 의 견본 메모가 선다 — 빈 위젯을 보고는 무엇인지 알 수 없다.
> "Design a realistic preview to display in the widget gallery." (HIG)

## 9. 접근성

- 줄·카드·칸은 `accessibilityElement(children: .combine)` — VoiceOver 가 「오늘 일정 · 오후 3:00, 치과 예약」로 한 번에 읽는다.
- 「봤어요」에는 이름과 힌트를 따로 단다 (「지금」에서 내려놓습니다).
- 달력 칸은 「18일 금요일, 일정 2」.
- 대비 높임은 `Shade` 의 셋째·넷째 벌이 받는다. 둘째 줄·시각은 시스템 `.secondary`.
- 글자를 그림으로 굽지 않는다 — 손으로 그린 동그라미는 **표시**이지 글자가 아니다.
  > "Avoid rasterizing text. Always use text elements and styles…" (HIG)

## 10. 검증

- 두 플랫폼 컴파일: `xcodebuild build -target LazyMemoWidgets -sdk iphonesimulator|macosx`
  (`LazyMemoWidgets` **스킴은 없다** — 타깃으로 부르거나 `LazyMemo-iOS`/`LazyMemo-macOS` 스킴이 품는다).
- 공유 판단: `./scripts/test.sh --filter LazyMemoWidgetsCoreTests`.
- 눈 검증: 얼굴은 `NowView(entry:family:)` 처럼 **크기를 손으로 받는다** — 임시 SwiftPM 패키지에 얼굴 파일을 복사하고 `Link` 를 벗겨 `ImageRenderer` 로 PNG 를 찍는다. 시스템 여백 16 을 손으로 얹고, 다크는 `NSAppearance.performAsCurrentDrawingAppearance` 로 갈아야 `Shade` 가 다크 벌을 고른다.
- 아직 사람 눈으로 못 본 것: 실제 홈 화면·잠금 화면 배치, 맥 알림 센터, 틴트·StandBy 의 실제 렌더, 「봤어요」를 눌렀을 때의 실제 왕복.
