---
schema_version: 1
type: feature
slug: "phone-app-intents-write-today-pen"
status: done
difficulty: medium
created_at: "2026-09-21T18:47:06+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/AppIntents.swift"
    op: create
  - path: "ios/LazyMemo/en.lproj/AppShortcuts.strings"
    op: create
  - path: "ios/LazyMemo/ko.lproj/AppShortcuts.strings"
    op: create
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoReminders/RouteAskDrop.swift"
    op: create
  - path: "README.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "site/privacy/index.html"
    op: update
  - path: "docs/STORE_LISTING.md"
    op: update
related:
  - ref: "20260913/Features_to_add/0246_feature_share-extension-and-app-group.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md"
    kind: "followup"
  - ref: "20260917/Chores/1311_chore_convenience-audit-research-note.md"
    kind: "followup"
tags:
  - "ios"
  - "app-intents"
  - "siri"
  - "shortcuts"
  - "inbound"
  - "privacy"
  - "mcp-tool"
---
[x] 폰의 App Intents — Siri·단축어·액션 버튼의 「lazymemo 에 적기」·「오늘 뭐 있어」·「펜」

## 추가 기능

지금까지 폰에서 앱을 열지 않는 길은 iCloud 폴더에 `.md` 를 떨구는 단축어 우회로뿐이었다. `ios/LazyMemo/AppIntents.swift` 에 인텐트 셋과 `AppShortcutsProvider` — 앱을 깔면 등록 없이 선다.

- **`WriteMemoIntent` 「lazymemo 에 적기」** (배경, `openAppWhenRun = false`) — `@Parameter text`, 글이 없으면 시스템이 「무엇을 적을까요?」 하고 묻는다. 공유 시트와 같은 문 `InboundNote.make` → `InboxDrop.drop` 이라 날짜·자리를 펜과 똑같이 읽는다. 답은 공유 시트의 칩과 같은 말 「적었어요 · 9월 22일 15:00 · 달력으로 · @강남역」. 파일 한 장만 떨구고 `WidgetRefresher.reloadNow()` — 인덱스는 앱이 앞으로 나올 때 `reconcile` 한다(Siri 가 앞에 있는 동안 앱은 `.inactive`→`.active` 를 지나므로 그때도 대조된다). 자리가 있는 약속이면 `RouteAskDrop.leave` 로 「어디서 출발하시나요?」 알림과 앱 그룹 표를 남긴다.
- **`TodayIntent` 「오늘 뭐 있어」** (배경) — `MemoVault.loadAll` → `WidgetAgenda.nowCards`(「봤어요」 반영) 를 `NowBand.reasonText` 와 제목으로 읽어 준다.
- **`OpenPenIntent` 「펜」** (전경) — `AppLinks.shared.requestWrite()`, 펜에 키보드. 말보다 손으로 적고 싶을 때의 액션 버튼.
- 말은 코드에 한국어(`\(.applicationName)에 적기` 등 7개), `en.lproj/AppShortcuts.strings` 가 영어. `ko.lproj` 에는 항등 표 — `Localizable.strings` 와 같은 이유(없으면 개발 언어 표로 건너뛴다).
- `RouteAskDrop` 은 `LazyMemoReminders` 에 새로 — 공유 확장의 것과 한 벌 더다. Core 에 못 두는 이유는 Package.swift 가 적어 둔 대로(MCP 서버·테스트까지 UserNotifications 를 들지 않게), 공유 확장은 메모리 한도로 Reminders 를 들지 않는다. 두 벌이라는 사실을 양쪽 주석에 적었다.
- 프라이버시 표에 「Siri 로 적기」 한 줄(README·PRIVACY.md ko/en·site/privacy) — 말한 글 한 줄은 애플의 Siri 가 받아 적는 동안 애플의 설정을 따른다, 단축어에 글을 직접 넣으면 아무것도 안 나간다. STORE_LISTING 설명에 Siri·위젯 두 줄, README 에 「Siri·단축어·액션 버튼」 절, MOBILE_DESIGN §8 에 인텐트 소절.

## 동작 흐름

1. 「시리야, lazymemo 에 적기」 → 「무엇을 적을까요?」 → 「내일 3시 치과 @강남역」 → 파일 한 장, 위젯 갱신, 답 「적었어요 · 9월 22일 15:00 · 달력으로 · @강남역」, 알림 「어디서 출발하시나요?」(알림을 켠 기기만). 앱은 열리지 않는다.
2. 액션 버튼 → 단축어 「lazymemo 에 적기」 — 같은 길. 「펜」을 매달면 앱이 열리고 키보드가 선다.
3. 「lazymemo 오늘 뭐 있어」 → 「고정 — 장보기 / 오늘 일정 · 15:00 — 치과 …」.

## 검증

- `xcodebuild build`(LazyMemo-iOS, 시뮬레이터) 성공. `Metadata.appintents/extract.actionsdata` 에 세 인텐트와 일곱 phrase(`${applicationName}…`)가 들어 있는 것을 확인. `swift test` 전체 초록(526+87 tests), 폰 스모크 셋(적기·봤어요·체크상자) 초록.
- 처음엔 세 군데서 컴파일이 깨졌다 — `@Parameter` 의 인자 차례(`inputOptions` 가 `requestValueDialog` 앞), `Summary("\(\.$text) 적기")` 의 키패스 추론(뺐다 — 기본 요약이 제목+인자로 선다), `WidgetRefresher.reloadNow()` 가 MainActor 라 `perform()` 을 `@MainActor` 로.
- **사람이 볼 것**: 시뮬레이터에는 Siri 가 없다. 실기기(TestFlight)에서 ① 「시리야, lazymemo 에 적기」의 되물음과 답 ② 단축어 앱의 타일 셋 ③ 액션 버튼에 매단 뒤 앱이 안 열리는 것.

## 메모

- 맥에는 없다 — GitHub 판(SwiftPM 번들)은 App Intents 메타데이터를 못 뽑는다(감사 §3.1). 맥 스토어 판의 Spotlight 액션·quick key 「lm」은 다음 판 — 플랜 `#app-intents` 는 그래서 진행중으로 둔다.
- `parameterSummary` 없이도 단축어 편집기에 「글」 칸이 선다. 필요하면 나중에.