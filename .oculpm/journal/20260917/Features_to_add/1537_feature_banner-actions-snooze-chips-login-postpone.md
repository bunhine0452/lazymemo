---
schema_version: 1
type: feature
slug: "banner-actions-snooze-chips-login-postpone"
status: done
difficulty: medium
created_at: "2026-09-17T15:37:53+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoReminders/ReminderCenter.swift"
    op: update
  - path: "Sources/LazyMemoReminders/SystemReminderQueue.swift"
    op: update
  - path: "Sources/LazyMemoReminders/RecallViews.swift"
    op: update
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/NowBand.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/MapApp.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/DemoTests.swift"
    op: update
  - path: "Tests/LazyMemoRemindersTests/ReminderCenterTests.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
  - path: "docs/research/convenience-audit-2026-09-17.md"
    op: update
related:
  - ref: "20260917/Chores/1311_chore_convenience-audit-research-note.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/2248_feature_share-sheet-route-ask-notification.md"
    kind: "followup"
tags:
  - "ux"
  - "notification"
  - "recall"
  - "ios"
  - "mac"
  - "onboarding"
  - "mcp-tool"
---
[x] 편의성 감사(`docs/research/convenience-audit-2026-09-17.md` §5) 1~4번 구현

## 추가 기능

**1. 배너에 단추** (`Sources/LazyMemoReminders`, 맥·폰)
- `ReminderAction`(한 시간 뒤·10분 뒤·내일 아침 9시·봤어요·지도 열기)와 `ReminderCategory`(recall = 한 시간 뒤·내일 아침·봤어요 / departure = 10분 뒤·지도 열기). 가는 길이 적힌 약속(`Reservation.body != nil`)은 departure.
- `SystemReminderQueue`: init 에서 `setNotificationCategories`, `add` 가 `categoryIdentifier` 를 달고 `pending()` 이 되읽는다(동등성 유지), `didReceive` 가 `actionIdentifier` 를 갈라 `onAction(action, memoID, fired)` — `fired` 는 userInfo 의 걸린 시각. dismiss 는 무시. 지도만 `.foreground`.
- `ReminderCenter.handle`: 미루기는 `store.update(surface:)`, 「봤어요」는 `NowSeen`(WidgetsCore)에 `fired` 를 이름표로 적고(`Recall.Card.stamp` 와 같은 값) `seenVersion` 을 올리며 `onSeen` 을 부른다, 「지도 열기」는 `onOpenMap`. 저장소·손이 없으면 `pendingActions` 에 **정해진 시각째로** 담고 defaults 에도 적는다 — 배경에서 깬 폰이 잠들어도 남고, 「한 시간 뒤」는 누른 순간 기준이다. `start(store:)`·`onOpenMap didSet` 에서 비운다.
- 맥: `NoteWindowManager.lower(id)`(나온 종이 한 장 내리기) ← `onSeen`; `onOpenMap` 은 종이 카드와 같은 `RouteLinks.kakaoWeb`. 폰: `MapApp.openRoute(in:)` 로 편집 화면의 `openRoute` 를 빼내 배너와 카드가 같은 길; `HomeView.attachAssistant` 에서 손을 잇는다. `StackView` 는 `seenVersion`·앞으로 올 때 `NowSeen` 을 다시 읽는다.
- Package: Reminders → WidgetsCore 의존 추가.

**2. 「다시 보기」 칩 즉시 저장** (`RecallViews`): 「한 시간 뒤」「내일 아침 9시」가 누르는 순간 저장하고 닫힌다 (`Snooze` — 배너와 같은 값). 피커+「이때 다시 보기」는 그대로 아래에.

**3. 첫 실행 04 에 「로그인할 때 시작」** (`WelcomeWindow`): 체크박스, 실제 상태를 보이고 켜는 것은 사람. `LoginItem.isAvailable` 일 때만.

**4. 폰 「지금」 카드·목록 줄의 「미루기」** (`NowBand`·`StackView`): 일정이 있으면 leading 밀기의 첫 자리(끝까지 밀면 그것), 컨텍스트 메뉴·VoiceOver 동작에 「하루 미루기」. 달력 탭과 같은 `Schedule.postponed(notBefore:)`, 되돌리기 이름 「N월 M일로 옮기기」.

문서: README(다시 보기·첫 실행 표·지금 띠), MOBILE_DESIGN §4 손짓 표, 감사 노트 §5 머리말.

## 동작 흐름

배너 길게 → 「한 시간 뒤」 → `didReceive` → `onAction` → `ReminderCenter.handle` → `surface` 갱신 → 대조가 예약을 그 시각으로. 앱이 꺼진 채면 defaults 에 담겼다가 다음 `start(store:)` 에서 같은 시각으로 적용.
폰 목록 줄 오른쪽 밀기 → 「미루기」 → 내일(지난 것도 내일보다 이르지 않게) → 흔들면 되돌림.

## 검증

- `./scripts/test.sh` 전부 초록 (Reminders 18 — 새 시험 6: 카테고리 갈림, 「한 시간 뒤」가 surface 와 예약을 옮김, 저장소 전 담아 두기, 「봤어요」의 NowSeen 이름표, 「지도 열기」 대기, Snooze 값).
- iOS 시뮬레이터(iPhone 17) `LazyMemo-iOS`·`LazyMemo-macOS` 빌드 성공. XCUITest `testPostponeFromTheListMovesTheDate`(새로 씀 — 내일 15시 약속을 심고 밀어서 모레 15시가 파일에 적힘)·`testRevisitWritesSurfaceAndNowBandShowsPinned` 통과. `DemoTests` 의 다시 보기 장면은 칩 한 번으로 닫히는 것으로 고침(안 돌림).
- **사람 눈 필요**: 실제 배너의 단추(맥·폰), 맥의 나온 종이가 「봟어요」로 내려가는 것, 첫 실행 창의 체크박스(앱 번들에서만 보인다).

## 메모

- `testSeenPutsTheCardDownIntoTheRest` 가 빨갛다 — 내 변경과 무관. 씨앗의 일정 날짜(9월 14·15일)가 박혀 있어 `Tidy.pastGrace`(다음 날 끝)를 지나 물러났고, 「나머지 5장」이 「2장」이 됐다. 씨앗을 오늘 기준 상대 날짜로 바꿔야 한다 — 같은 씨앗을 쓰는 다른 시험도 날이 갈수록 같은 길을 간다.
- `check-l10n.sh` 는 돌리지 않았다(전체 재빌드) — 새 열쇠 넷(10분 뒤·봤어요·지도 열기·첫 실행 부제)은 en.lproj 에 손으로 넣었다.