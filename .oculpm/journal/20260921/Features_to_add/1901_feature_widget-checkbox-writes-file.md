---
schema_version: 1
type: feature
slug: "widget-checkbox-writes-file"
status: done
difficulty: high
created_at: "2026-09-21T19:01:29+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Checklist.swift"
    op: create
  - path: "Sources/LazyMemoWidgetsCore/WidgetChecklist.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/ChecklistTests.swift"
    op: create
  - path: "Tests/LazyMemoWidgetsCoreTests/WidgetChecklistTests.swift"
    op: create
  - path: "ios/LazyMemoWidgets/CheckIntent.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WidgetVault.swift"
    op: update
  - path: "ios/LazyMemoWidgets/NowWidget.swift"
    op: update
  - path: "ios/LazyMemoWidgets/NowFaces.swift"
    op: update
  - path: "ios/LazyMemoWidgets/en.lproj/Localizable.strings"
    op: update
  - path: "docs/WIDGET_DESIGN.md"
    op: update
  - path: "README.md"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
related:
  - ref: "20260918/Features_to_add/1912_feature_widget-redesign-precise-comfortable.md"
    kind: "followup"
  - ref: "20260918/Chores/1911_chore_widget-design-doc.md"
    kind: "followup"
  - ref: "20260917/Chores/1311_chore_convenience-audit-research-note.md"
    kind: "followup"
tags:
  - "widget"
  - "app-intents"
  - "checklist"
  - "ios"
  - "mac"
  - "file-write"
  - "comfort"
  - "mcp-tool"
---
[x] 「지금」 큰 위젯의 체크상자 — 홈 화면에서 누르면 파일의 괄호 안 한 글자가 바뀐다, 앱을 열지 않고

## 추가 기능

편의성 감사 §3.4 그대로: 체크리스트 한 칸을 끄려고 앱을 열어 종이를 찾으면 셋, 위젯에서 누르면 하나.

- **Core `Checklist`** — 체크상자 줄을 **글로** 다룬다. `lines(in:)` 은 줄 차례대로 (글, 체크 여부), `toggle(_:done:in:)` 은 그 글을 든 첫 줄의 괄호 안 한 글자를 뒤집는 `ListEditing.Edit`(없으면 nil — 이미 체크됐거나 글이 바뀌었거나 줄이 지워졌다), `applying` 이 글에 가한다. 자리가 아니라 글로 찾는 이유: 위젯은 그려진 뒤 한참 있다 눌리고 그 사이 다른 기기가 메모를 고쳤을 수 있다 — 엉뚱한 줄을 뒤집는 것보다 아무것도 안 하는 편이 낫다.
- **WidgetsCore `WidgetChecklist`** — `openItems(of: cards, limit: 3, perCard: 3)` 이 앞 카드부터 안 한 칸을 고르고(같은 글 두 줄이면 하나), `check(_:of:in:)` 이 `MemoVault.load` → `Checklist.toggle` → `vault.modify(expectedHash: memo.contentHash)` 로 **본문과 `updated` 만** 바꿔 파일에 쓴다. 그 사이 파일이 바뀌었으면(`Failure.changed`) 손대지 않고 `false`.
- **위젯 `CheckIntent`** (폰·맥 둘 다 — App Group 이 필요 없고 읽은 자리에 쓴다) → `WidgetVault.paths()`(읽기와 쓰기가 같은 자리) → `WidgetChecklist.check`. `perform()` 이 돌아오면 시스템이 시간표를 다시 부른다.
- **얼굴** — 큰 가족만. `NowEntry.checks` 를 `make` 에서 세고, 「다음」 줄은 `4 - checks.count` 로 줄인다(칸 하나가 줄 하나를 쓴다 — 오늘 할 칸이 내일 뒤의 일정보다 앞). 카드 밑에 `CheckRow` = `Toggle(isOn: false, intent:)` + `WidgetCheckStyle`(16pt 네모, 채우면 강조 잉크의 체크), 과녁은 줄 전체 28pt·전폭. 접근성 「체크할 것: 우유」·「이 칸을 체크합니다 — 메모 파일에 적힙니다」. 중간·작은·잠금 화면 가족에는 없다.
- **줄의 정체는 글이다** — `.id(item.id)` + `.transition(.opacity)`. 없으면 체크된 줄이 빠지며 아래 줄이 올라올 때 시스템이 자리로 짝을 지어 「계란」 줄이 체크된 채 0.5초쯤 보였다(첫 실기 시험에서 봤다). 못 박으니 누른 직후부터 최종 모양이다.
- 위젯 설계 문서 §4 를 「「봤어요」와 체크상자, 둘뿐」으로 고쳐 쓰고 「하루 미루기」는 여전히 안 넣는 선(되풀이·알림·달력이 같이 움직여야 하는 일)을 적었다. README 위젯 표·문단, 소개 페이지 위젯 절 한 문장(ko·en).

## 동작 흐름

1. 큰 「지금」에 고정된 「장보기」 카드 → 그 밑에 `☐ 우유` `☐ 계란` (체크된 두부는 없다).
2. `☐ 우유` 를 누른다 → `CheckIntent.perform` → 파일 `- [x] 우유`, `updated` 갱신 → 시간표 다시 → 위젯에는 `☐ 계란` 만.
3. 앱은 다음에 앞으로 나올 때 `reconcile` 로 인덱스를 맞추고, 다 체크되면 `Tidy` 가 사흘 뒤 물러나게 한다 — 규칙은 전부 앱에 그대로. 맥의 종이는 파일 감시로 같은 칸이 체크된다.

## 검증

- `swift test` 전체 초록(526+87) — `ChecklistTests` 넷(차례·글로 찾기·없는 것 거절·중복은 첫 줄), `WidgetChecklistTests` 둘(고르기, 임시 vault 에 실제로 쓰고 두 번째는 아무 일도 없음).
- `xcodebuild build`(LazyMemo-iOS) 성공, 확장의 `Metadata.appintents` 에 `CheckIntent` 포함. 폰 스모크 셋(적기·봤어요·종이의 체크상자) 초록.
- **시뮬레이터 홈 화면 실기 (iPhone 17·iOS 26)**: 임시 XCUITest 로 편집 → 위젯 추가 → 검색 「lazymemo」 → 셋째 페이지(큰 「지금」) → 추가 → 완료. App Group vault 에 심은 고정 체크리스트가 카드 밑 두 칸으로 섰고, `☐ 우유` 를 누르자 파일이 `- [x] 우유` 로 바뀌고 5초 뒤 위젯에 `☐ 계란` 만 남았다(스크린샷으로 확인, 확인 뒤 지움). 시험 파일은 지웠다.
- 못 본 것: 맥 위젯(알림 센터)의 체크 — 코드 경로는 같고 컴파일은 되지만 실기로 안 봤다. 다크·틴트 렌더의 네모.

## 메모

- SpringBoard 의 접근성 트리는 위젯 갤러리에서 스냅샷이 몇 분씩 걸려 XCUITest 의 요소 질의가 멈춘다 — 좌표 탭과 스크린샷만으로 해야 한다. 위젯이 파일을 새로 읽게 하려면 앱을 `simctl launch` 했다 끄면 된다(`WidgetRefresher.start` 가 다시 그린다). 심는 메모의 ULID 는 **26자**여야 한다(25자를 심어 한 번 「펼칠 것이 없어요」를 봤다).
- 두 번째 시험에서 「계란」이 체크된 것은 결함이 아니라 옛 시간표(우유가 이미 빠진)를 누른 것 — 파일을 되돌린 뒤 앱을 띄워 위젯을 새로 그리지 않았다.
- 확장이 파일을 고치는 유일한 자리다. `{#file-coordinator}`(iCloud 쓰기 조정)는 여전히 앱과 같은 defer 위에 있다 — 원자적 쓰기 + hash 대조로 막고 있다.