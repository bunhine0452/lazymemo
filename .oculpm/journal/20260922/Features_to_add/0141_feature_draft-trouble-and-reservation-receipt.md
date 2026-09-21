---
schema_version: 1
type: feature
slug: "draft-trouble-and-reservation-receipt"
status: done
difficulty: high
created_at: "2026-09-22T01:41:58+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/CaptureDraftStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/Agenda/ReservationReceipt.swift"
    op: create
  - path: "Sources/LazyMemoCore/Agenda/RecallSwitch.swift"
    op: create
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoReminders/ReminderCenter.swift"
    op: update
  - path: "Sources/LazyMemoReminders/SystemReminderQueue.swift"
    op: update
  - path: "Sources/LazyMemoReminders/RecallDrop.swift"
    op: create
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/AppIntents.swift"
    op: update
  - path: "ios/LazyMemoShare/ShareViewController.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/CaptureDraftStoreTests.swift"
    op: update
  - path: "Tests/LazyMemoRemindersTests/ReminderCenterTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureDraftTests.swift"
    op: update
related:
  - ref: "20260922/Bugs/0123_bug_tidy-overrode-user-intent.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
tags:
  - "capture"
  - "reminders"
  - "share-extension"
  - "app-intents"
  - "handoff-bundle-2"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 저장과 예약 상태를 믿을 수 있게 — 초안 실패가 보이고 재시도되며, 저장 뒤 알림 영수증은 이 기기에서 확인한 사실만 말한다 (묶음 2)

인계서 §5 묶음 2 (`#draft-save-status`, `#reservation-receipt`). 세 가지가 거짓말할 수 있었다: ① 초안 파일이 안 써져도 조용했다(`CaptureDraftStore.flush` 의 빈 catch) ② 맥 빠른 입력은 **비우고 닫은 뒤** 적어서 저장이 실패하면 글이 이미 없었다 ③ 알림이 걸렸는지는 어디에도 안 적혔고, 공유 시트·인텐트는 파일만 떨궈 앱을 열기 전엔 아무 알림도 없었다.

## 추가 기능

- **초안 실패 표시·재시도** — `CaptureDraftStore` 가 `@Observable` 이 되고 `trouble`(기계의 말)·`retry()` 를 든다. 맥 상자와 폰 펜이 「초안을 기기에 남기지 못했어요 — 이번 실행 동안만 들고 있어요 · 다시 시도」 한 줄을 적는다.
- **저장 실패는 글을 지우지 않는다** — `QuickCaptureModel.save(_:)` 가 결과를 들고 오고, 컨트롤러는 `.create`/`.compose` 에서 **적힌 뒤에** `clear()`·`close()` 한다. 실패하면 `saveTrouble`(`MemoStore.trouble` 재사용) 이 상자에 서고 글은 그대로, 다음 타자에 걷힌다. 폰 펜은 원래 실패 시 글을 두었고 `StackView` 의 `NoticeRow` 가 `store.trouble` 을 적으므로 그대로.
- **알림 영수증** `ReservationReceipt`(Core) — `scheduled(Date)`·`noTime`·`dateOnly`·`passed`·`notWanted`·`off`·`denied`·`unavailable`·`overflow`·`failed`·`pending`·`needsApp`. `line()` 이 「이 기기에 알림 예약됨 · 9월 25일 9:00」「날짜만 적혀 알림 없음 — 시각을 적으면 걸려요」「알림 꺼짐 — …」「알림 예약 실패 · 다시 시도」를, `mark` 가 달력 꼬리의 짧은 말을 낸다. Core 에 둔 이유: 공유 확장이 Reminders 패키지를 안 들어서 — 어디서 적었든 한 말.
- `ReminderCenter.receipt(for:)` — 대조가 메모마다 낸 결과(`outcomes`)로 답한다. 대조 전엔 `.pending` 이라 **앞 메모의 결과를 새 메모에 붙일 수 없다**(id 로 찾는다).
- 폰 펜: 남긴 뒤 `receiptFor`(HomeView 가 `settle()` 뒤 `receipt(for:)` 로 잇는다) → `receiptRow` 한 줄(종·×), 다음 글자에 물러남. 그냥 글은 조용하다. 손끝 진동(저장)과 이 줄(알림)을 한 「됐다」로 뭉치지 않는다.
- 맥 달력 줄 꼬리: `· 알림` / `· 알림 꺼짐` / `· 알림 실패`(주황) + 도움말에 전체 문장. 적은 직후 달력이 잠깐 앞으로 나올 때 보인다. 번들 밖(렌더·시험)이면 꼬리 없음.
- **공유 시트·인텐트가 그 자리에서 건다** — `Recall` 에 예약 이름·`userInfo` 열쇠·종류 이름·기본 둘째 줄을 상수로 올리고(`notificationPrefix`·`memoKey`·`dateKey`·`recallCategory`·`departureCategory`), `RecallDrop`(Reminders, 인텐트용)과 확장 안의 한 벌이 **앱과 같은 id `recall.<ulid>`·같은 내용**으로 하나를 건다. 앱의 대조는 그것을 자기 것으로 알아보고 두 번 걸지 않는다(같은 id 는 OS 가 갈아 끼운다). 「이 기기에서 알림 받기」 켜짐은 `RecallSwitch` 가 앱 그룹 폴더에 표 파일로 한 벌 더 적어(`ReminderCenter` 가 켜고 끌 때·기동 때) 확장이 읽는다 — 폴더를 모르면 `needsApp`(「알림은 앱을 열면 걸려요」), 꺼짐과 다르다.
- 공유 시트는 영수증을 1.4초 보여 주고 닫는다(그냥 글은 바로). 인텐트 대답에 영수증 문장이 붙는다.

## 동작 흐름

맥 ⌘⏎ → `model.save { store.create }` → 성공: reset·clear·close·announce(달력이 뜨며 줄 꼬리에 `· 알림`) / 실패: 상자 열린 채 글 그대로 + 주황 줄. 폰 「남기기」 → `finishLeaving` → 진동 → `receiptFor` 가 대조를 기다렸다 영수증 줄. 공유 시트 「남기기」 → 파일 떨굼 → `RecallDrop.leave` → 영수증 줄 → 닫힘.

## 검증

- `./scripts/test.sh` 전체 **1,125개 통과** (새 시험: `CaptureDraftStoreTests` 실패·재시도 1, `ReminderCenterTests` 영수증 3 + 이름 공유·그룹 표 2, `CaptureDraftTests` 저장 실패 글 보존·초안 실패 2). 묶음 5(병렬 세션)의 변경과 합쳐진 상태로 돌렸다.
- `scripts/render-ui.sh` 의 새 `capture-trouble` 렌더 — 밝은/어두운 판 모두 「메모를 저장하지 못했습니다」「초안을 기기에 남기지 못했어요 … 다시 시도」 두 줄이 글·칩 아래 섰다. 확인 뒤 `build/ui` 삭제.
- 폰 앱·공유 확장·위젯: `xcodebuild build`(iPhone 17 시뮬레이터, `.build/ios`) **BUILD SUCCEEDED** — 컴파일만. 시뮬레이터 조작·실기기 알림 도착·공유 시트에서 실제로 걸린 알림이 앱 대조와 만나는 장면은 **확인하지 않았다** (`lazymemo-recall#recall-device`).

## 메모

- 폰 잠금/종료 전달·양 기기 중복 알림은 이 묶음의 범위 밖(인계서 §4 마지막 줄).
- 날짜만 있는 메모의 「기본 시간 고르기」는 안 만들었다 — 영수증이 「시각을 적으면 걸려요」라고만 말한다. 묶음 4 의 행동 설계와 함께.