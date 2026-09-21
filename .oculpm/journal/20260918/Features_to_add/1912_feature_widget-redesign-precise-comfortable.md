---
schema_version: 1
type: feature
slug: "widget-redesign-precise-comfortable"
status: done
difficulty: high
created_at: "2026-09-18T19:12:35+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoWidgets/WidgetPaper.swift"
    op: update
  - path: "ios/LazyMemoWidgets/WidgetChrome.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WidgetMarks.swift"
    op: create
  - path: "ios/LazyMemoWidgets/NowWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/NowFaces.swift"
    op: create
  - path: "ios/LazyMemoWidgets/SeenIntent.swift"
    op: create
  - path: "ios/LazyMemoWidgets/NextWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/CalendarWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/CalendarFaces.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WriteWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/WidgetWords.swift"
    op: update
  - path: "ios/LazyMemoWidgets/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoWidgetsCore/NowSeen.swift"
    op: update
  - path: "Tests/LazyMemoWidgetsCoreTests/WidgetAgendaTests.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/2319_feature_widgetkit-now-next-write.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1621_feature_calendar-widget-month-grid.md"
    kind: "followup"
  - ref: "20260918/Chores/1911_chore_widget-design-doc.md"
    kind: "blocked_by"
tags:
  - "widget"
  - "widgetkit"
  - "ios"
  - "mac"
  - "app-intent"
  - "theme"
  - "a11y"
  - "mcp-tool"
---
[x] 위젯 네 장 재설계 — 색 획 한 줄과 고정 칸, 흐르는 남은 시간, 손으로 그린 오늘, 홈 화면의 「봤어요」

## 추가 기능

`docs/WIDGET_DESIGN.md` 대로 「지금」·「다음 약속」·「달력」·「적기」의 얼굴을 다시 지었다. 공유 조각을 `WidgetChrome.swift` 로 뽑고 얼굴은 파일을 갈랐다 (`NowFaces` · `CalendarFaces`, 전부 240줄 이하).

- **색이 들어오는 문이 하나가 됐다** — `WidgetTheme`(surface/card/ink/secondary/accent/onAccent/accentInk/highlightInk/papery) 를 `@Environment(\.widgetTheme)` 로 내려 준다. 루트가 `WidgetRenderingMode` 를 보고 `paper`(크림·포레스트, `Shade` 네 벌)와 `mono`(계층색)를 고른다 — 잠금 화면 vibrant 와 iOS 18 틴트·선명에서 커스텀 색이 사라지고 도트 그리드·일/토 잉크가 접힌다.
- **카드는 종이가 아니라 획이다** — 줄마다 깔던 `Paper.card` 면 + 포레스트 테두리를 걷고, 글 덩이 왼쪽에 **3pt 색 획**(`inkBar`)을 겹쳐 둔다. 작은 위젯에서 네모가 글보다 먼저 보이던 것이 사라졌고, 그 획이 **메모 색**을 말한다 — 앞선 판에는 없던 정보다 (설계문서 §14.4 「색은 테두리와 왼쪽에서 번지는 잉크로만」).
- **머리 한 줄**(`WidgetHead`) — 왼쪽 「지금」/「다음」/「2026년 9월」, 오른쪽 「9월 18일 (금)」. `.caption2.semibold` + `tracking(0.8)`. 좁으면 `ViewThatFits` 가 날짜를 먼저 접는다.
- **「오늘부터」·「다음」 줄이 칸에 선다**(`AgendaRow`) — 날 46 · 시각 58 · 제목. 앞선 판은 「내일 · 오전 9:00」을 한 덩이로 붙여 줄마다 제목 시작점이 달랐다. 날 낱말도 칸에 맞게 줄였다(`WidgetWords.columnDay`: 오늘·내일·23일, 달이 넘어가면 10.2).
- **「다음 약속」의 마지막 줄이 스스로 흐른다** — `Text(_:style: .relative)`. 출발이 아직 오지 않았으면 「4시간 32분 뒤 출발」, 지났으면 약속까지. 그 위에 「14:34 출발 · 2호선」. 자리가 얕으면 `ViewThatFits` 가 출발 줄을 접고 남은 시간만 남긴다. **장면(timeline entry)을 하나도 더 쓰지 않는다.**
- **달력의 오늘이 펜 자국이 됐다**(`HandRing`) — 채운 원 대신 한 바퀴를 조금 넘겨 세 도막으로 가늘어지는 획. 맥 달력 `PenMarks` 와 같은 몸짓(설계문서 §10.3)이되 난수 없이 상수로, `Canvas` 하나. 숫자가 종이에 그대로 남는다. 숯색 종이에서는 획이 `accentInk`(밝은 세이지).
- **홈 화면에서 카드를 내려놓는다** — 카드 오른쪽의 체크(`SeenButton` → `SeenIntent` → `NowSeen.putDown`). 앱을 열지 않는다. **폰만** — 맥 확장에는 App Group entitlement 가 없어 `NowSeen` 이 확장 제 집의 defaults 로 떨어진다.
- **빈 위젯에 문이 생겼다**(`EmptyFace`) — 「펼칠 것이 없어요」 한 줄 + 「적기」 캡슐(보이는 것 30pt, 과녁 44).
- 제목에 `privacySensitive()` — 잠금 화면에서 제목만 가려지고 이유·시각은 남는다. 강조 조각(`이유 줄`·`시각`·`오늘 동그라미`·`적기`)에 `widgetAccentable()`.
- 가족마다 `#Preview` (빈 상태·잠금 화면 포함). 새 낱말 7개는 `en.lproj` 에 넣었다 — 코드 한국어 열쇠 40 · en 표 44 · 빠짐 0.

## 동작 흐름

1. 루트(`NowRoot`/`NextRoot`/`CalendarRoot`/`WriteRoot`)가 `widgetFamily` 와 `widgetRenderingMode` 를 읽어 `.widgetPaper(.resolved(mode))` 한 줄로 **환경 색 + `containerBackground`** 를 건다. 얼굴은 여전히 크기를 손으로 받는다 (`NowView(entry:family:)`) — 렌더 검증이 그렇게 부른다.
2. 「봤어요」를 누르면 `SeenIntent.perform()` 이 `NowSeen.putDown(id, stamp:)` 를 부르고, 돌아오면 **시스템이 그 위젯의 시간표를 다시 부른다** — 우리가 `WidgetCenter` 를 부르지 않는 이유. 앱은 앞으로 나올 때 `NowSeen.load()` 를 다시 읽으므로(`StackView` 의 `didBecomeActive`) 띠에서도 내려간다.
3. `NowSeen.putDown` 은 **읽고-고치고-쓰기를 한 걸음으로 묶는다.** 앱과 위젯이 각자 들고 있던 표를 통째로 덮어쓰면 한쪽이 방금 내려놓은 것이 조용히 되살아난다.
4. 큰 「지금」의 아래 절을 여섯 줄 → **넉 줄**로 줄였다 — 카드가 획으로 가벼워지면서 줄 높이가 달라졌고, 넉 줄이 350pt 안에 드는 마지막 수다.

## 검증

- `xcodebuild build -target LazyMemoWidgets` **iphonesimulator·macosx 둘 다 BUILD SUCCEEDED** (`-arch arm64`, 자체 SYMROOT/OBJROOT, `CODE_SIGNING_ALLOWED=NO`). `LazyMemoWidgets` **스킴은 없다** — 타깃으로 부르거나 앱 스킴이 품는다. `LazyMemo-iOS` 스킴 빌드는 다른 세션의 미완성 `Sources/LazyMemoAssistant/Digest.swift`(`cannot find 'L' in scope`) 때문에 한 번 실패했다 — 위젯과 무관.
- `./scripts/test.sh --filter LazyMemoWidgetsCoreTests` → **20 tests / 3 suites 통과** (`NowSeen.putDown` 시험 둘 추가: 먼저 내려놓은 것이 남는가 · 같은 메모는 이름표만 바뀌는가).
- **눈으로 봤다** — 스크래치패드의 임시 SwiftPM 패키지에 얼굴 파일을 복사하고 `Link`·`widgetURL`·`#Preview` 를 벗겨 `ImageRenderer` 로 21장을 찍었다 (시스템 여백 16 을 손으로 얹고, 다크는 `NSAppearance.performAsCurrentDrawingAppearance` 로 갈아야 `Shade` 가 다크 벌을 고른다). 여기서 **진짜 결함 하나**를 잡았다: `InkBar` 를 `HStack` 에 나란히 세웠더니 `Capsule` 이 두 방향 모두 유연해 큰 위젯의 카드 셋이 화면을 나눠 가지며 글 사이가 벌어졌다 — 글 덩이의 `overlay` 로 옮겨 키를 글이 정하게 했다. 다크에서 오늘 동그라미가 포레스트라 거의 안 보이던 것도 그때 `accentInk` 로 바꿨다.
- 못 본 것: 실제 홈 화면·잠금 화면 배치, 맥 알림 센터, 틴트·StandBy 의 실제 렌더, 「봤어요」의 실제 왕복(맥 하네스에는 `Button(intent:)` 이 없어 자리·크기만 흉내 냈다).
- `.build/ios-widgets`(710MB) 와 스크래치 PNG·패키지는 지웠다.

## 메모

- **오케스트레이터가 테마를 꽂을 자리는 `WidgetPaper.swift` 의 `WidgetTheme.paper` 하나다** — `static let paper` 를 `static func paper(_ choice: ThemeChoice)` 로 바꾸고 `resolved(_:)` 가 그것을 부르게 하면 네 위젯이 함께 바뀐다. 얼굴 파일은 색을 직접 알지 않는다.
- HIG 원문은 `WebFetch` 로 못 읽는다(자바스크립트). `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/widgets.json` 이 같은 글의 JSON 이고 그쪽은 그대로 읽힌다.
- 「하루 미루기」는 넣지 않았다 — `at`·`due` 를 고쳐 파일에 되쓰는 일이고, 확장은 파일만 읽는다(`WidgetVault`). 첨부·되풀이(`Tidy.rolled`)·인덱스·되돌리기와 맥의 `VaultBookmark` 는 앱이 든다.
- 「지금」 중간 위젯의 「봤어요」 과녁은 36×34 다. 줄이 34 라 44 를 주면 위아래 줄의 과녁이 겹친다 — 겹친 과녁은 44 보다 나쁘다. 큰 가족에서는 44×44.