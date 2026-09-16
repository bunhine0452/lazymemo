---
schema_version: 1
type: feature
slug: "share-sheet-route-ask-notification"
status: done
difficulty: medium
created_at: "2026-09-16T22:48:26+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/RouteAsk.swift"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "Sources/LazyMemoReminders/ReminderCenter.swift"
    op: update
  - path: "Sources/LazyMemoReminders/SystemReminderQueue.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/InboundDoor.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemoShare/ShareViewController.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RouteAskTests.swift"
    op: create
  - path: "Tests/LazyMemoRemindersTests/ReminderCenterTests.swift"
    op: update
  - path: "Tests/LazyMemoSpotlightTests/SpotlightCenterTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
  - ref: "20260916/Bugs/2158_bug_naver-share-glued-and-bare-day.md"
    kind: "followup"
tags:
  - "route"
  - "share-extension"
  - "notification"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] 공유 시트로 적은 약속도 가는 길을 묻는다 — 알림 「어디서 출발하시나요?」와 앱 그룹의 표

## 추가 기능

사용자: 지도 앱의 공유 → 「lazymemo 에 적기」로 약속(자리 + 「22일 오후 8시까지」)을 남겼는데, 「이렇게 메모하면 알림으로 AI 가 답장하라는 식으로 말하게 해줄 수 있어?」

공유 시트는 파일 한 장만 떨구고 나온다(`InboxDrop`) — 펜도 비서도 없다. 그래서:
- **Core `RouteAsk`**: 물을 만한가(`applies` — 앞으로 올 `at`, 자리(좌표·이름·지도 링크), 아직 길 없음; `RoutePlanner.applies` 가 이것을 쓴다) · 알림 id 머리 `route-ask.` 와 `userInfo` 열쇠 `ask=route` · 앱 그룹의 표 `route-ask.json`(`remember`/`takePending`). `AppPaths.sharedContainer` 에 시험용 `LAZYMEMO_GROUP` 덮어쓰기.
- **공유 확장**: 떨군 메모가 물을 만하면 표에 적고, 앱이 알림 권한을 받아 둔 기기면 2초 뒤 알림 — 제목은 메모 제목, 본문 「어디서 출발하시나요? 눌러서 답하면 가는 길을 찾아 적어 둘게요.」 확장은 권한을 못 묻는다.
- **폰**: `SystemReminderQueue` 가 `ask=route` 알림의 누름을 `onAskRoute` 로 → `ReminderCenter.askedRoute` → `HomeView.askRoute(for:)`: 저장소를 한 번 대조하고(파일은 확장이 떨군 것), 그 메모의 알림을 거두고(`clearRouteAsk`), 메모 탭으로 가 펜에 `RoutePlanner.begin`. 앱을 열 때(`onAppear`·`didBecomeActive`)도 표를 거둬 같은 길 — 알림을 안 눌렀어도, 권한이 없어도 묻는다. 이미 묻는 중이면 끼어들지 않는다.
- **맥**: 서비스 메뉴·URL 로 들어온 약속(`InboundDoor`)에 자리가 있으면 상자가 열리며 바로 묻는다(`QuickCaptureController.askRoute`).
- 다시 보기 알림의 대조(`ReminderCenter.reconcile`)는 `recall.` 머리만 다루므로 `route-ask.` 알림을 건드리지 않는다.

## 동작 흐름

공유 시트 「달력에 남기기」 → 파일 + 표 + (권한 있으면) 알림 → 배너 누름 or 앱 열기 → 대조 → 펜 「어디서 출발하시나요?」 → 이후는 상자에서 적었을 때와 같다.

## 검증

- `RouteAskTests`(물을 조건 6가지, 표 적기/거두기/중복/그룹 없음). Reminders 시험의 가짜 큐에 `onAskRoute`. 전체 Swift 시험 통과.
- 폰 XCUITest `testShareLeftQuestionIsAskedOnLaunch`: 자리 있는 약속 파일과 `LAZYMEMO_GROUP` 의 표를 심고 켜면 펜이 「어디서 출발하시나요?」와 약속 한 줄을 세우고 표가 비워진다 — 통과. (처음엔 `Date.formatted(.iso8601…time…)` 이 시각만 내놓아 `at` 이 안 읽혔다 — DateFormatter 로.)
- 알림 누름 경로는 배선만이라 시뮬레이터 `simctl push` 로는 안 돌렸다 — 시연 스크립트의 배너 장면과 같은 배선(`userInfo.memo`)에 `ask` 열쇠 하나 더.

## 메모

- 덤: `LazyMemoSpotlightTests.remembersFingerprints` 가 셋 중 하나꼴로 빨갰다 — 첫 center 를 `made` 튜플이 붙들고 있어 `center = nil` 로 놓이지 않았고, 둘이 함께 올렸다. 닫힌 `do` 범위로 첫 실행을 감싸니 8/8 통과. 릴리스 워크플로가 이것으로 멈추던 위험이 사라졌다.
- 사용자 요청으로 시뮬레이터는 시험이 끝나면 `simctl shutdown all` + Simulator 종료.