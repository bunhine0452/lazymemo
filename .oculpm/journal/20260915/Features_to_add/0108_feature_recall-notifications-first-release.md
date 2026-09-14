---
schema_version: 1
type: feature
slug: "recall-notifications-first-release"
status: done
difficulty: high
created_at: "2026-09-15T01:08:08+09:00"
session_id: "mcp-20260915-010808"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: create
  - path: "Sources/LazyMemoReminders/ReminderCenter.swift"
    op: create
  - path: "Sources/LazyMemoReminders/SystemReminderQueue.swift"
    op: create
  - path: "Sources/LazyMemoReminders/RecallViews.swift"
    op: create
  - path: "Sources/LazyMemoReminders/RecallWindow.swift"
    op: create
  - path: "Sources/LazyMemoReminders/Words.swift"
    op: create
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/DueClock.swift"
    op: update
  - path: "ios/LazyMemo/NowBand.swift"
    op: create
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/LazyMemoApp.swift"
    op: update
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/ShotTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecallTests.swift"
    op: create
  - path: "Tests/LazyMemoRemindersTests/ReminderCenterTests.swift"
    op: create
  - path: "scripts/check-l10n.sh"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
  - path: ".oculpm/discussion/lazymemo-recall/discussion.md"
    op: create
related:
  - ref: "20260914/Chores/2209_chore_recall-product-plan.md"
    kind: "followup"
  - ref: "20260829/Features_to_add/1751_feature_due-time-surfaces-the-paper.md"
    kind: "followup"
tags:
  - "recall"
  - "notifications"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] 다시 보기 첫 출시 — 기기별 로컬 알림, 메모별 다시 볼 시각, 폰의 「지금」 세 장

Codex 가 중단한 자리(계획서·미검증 초안)를 이어받아 `docs/RECALL_PLAN.md` 의 첫 출시 범위를 완성했다. Codex 의 lease 는 만료 전이었으나 사용자 지시로 중단된 세션이라 그대로 이어받았다.

## 추가 기능

- **`Recall`(Core)** — 알림·「지금」이 같이 보는 규칙. `eligible`(지운 것·치워 둔 것·다 체크한 목록 제외), `reservations`(미래의 `surfacesAt` 만, 가까운 순·같은 시각은 id 순, 한도 60), `nowCards`(오늘 다시 보기 → 오늘 일정 → 고정, 최대 셋, `moment` 로 이유에 붙는 시각). 날짜만 있는 메모에는 시각을 지어내지 않는다.
- **`LazyMemoReminders` 패키지** — `ReminderCenter` 는 OS 큐를 `ReminderQueue` 프로토콜 뒤에 두고, 저장소가 바뀔 때마다 있어야 할 예약 집합과 큐를 **대조**한다(메모 id = 예약 id). OS 를 읽는 `await` 사이에 저장소가 바뀌면 `dirty` 로 낡은 집합을 버리고 다시 센다. 켜짐은 `UserDefaults`(기기별, 파일로 번지지 않음). 권한 거절 시 켜 둔 뜻은 남고, 설정에서 허용하면 다음 대조가 건다. 끄면 예약과 알림 센터의 것을 전부 뺀다. 걸지 못한 것은 `trouble` 로 남기고 「다시 시도」. `SystemReminderQueue` 는 앱 번들 안에서만 만들어 bare `swift run`/`swift test` 에서 `UNUserNotificationCenter.current()` 를 건드리지 않는다. 알림 탭은 `onOpen`(맥) 또는 `opened`(폰, 꺼진 채 눌렀을 때)로 전달.
- **화면** — `ReminderSettingsView`(잠금 화면 제목 표시·기기별·다른 기기 반영 시점·양쪽 울림·집중 모드 경계를 켜기 전에 적음, 걸어 둔 수·한도 초과·오류·다시 시도), `RecallEditor`(현재 시각·일정 시각 표시, 날짜 시각 고르기, 한 시간 뒤·내일 아침 9시, 해제 시 「일정 시각에는 알려드려요」). 맥은 종이 우클릭 「다시 보기…」와 설정 「알림…」(`RecallWindow`), 폰은 편집 위 오른쪽 종(정해 두면 `bell.badge.fill`)과 More → 「알림」 시트. 알림을 누르면 맥은 `reveal(keepingPlace:)`, 폰은 어느 탭에서든 편집 시트.
- **폰 「지금」 띠**(`NowBand`) — 폴더 띠 아래 최대 세 장, 이유와 시각(「오늘 일정 · 15:00 지남」 등)이 제목보다 먼저. 찾는 중·폴더 고름에는 숨김. 분마다·앞으로 올 때·시계 점프 때 다시 잰다. 아래에 `NoticeRow` — 저장소 `trouble` 과 알림 `trouble` 을 폰에서도 보인다.
- 로컬라이제이션은 기존 규칙대로: 패키지는 `L()` + `Resources/en.lproj`, 폰은 `String(localized:)` + `ios/LazyMemo/en.lproj`. Codex 초안의 임시 `R(ko,en)` 은 제거. `check-l10n.sh` 에 Reminders 모듈 추가(빠짐 0).
- 문서: README(다시 보기 절·프라이버시 표·권한 다섯), DESIGN §9.3.2·surface 절, MOBILE_DESIGN §4 「지금」·§5 종·More 알림, `DueClock` 주석, discussion 문서(`lazymemo-recall`, resolved).

## 동작 흐름

폰에서 메모를 열고 종 → 시각 고르기 → 「이때 다시 보기」 → 파일 `surface:` 에 적힘 → 저장소 관찰이 `ReminderCenter.refresh()` → 켜져 있고 허용됐으면 `recall.<ulid>` 로 예약 → 시각에 배너 → 누르면 그 메모가 시트로 열림. 맥은 같은 `surfacesAt` 으로 `DueClock` 이 종이를 꺼내고, 켜 두었으면 배너도 온다.

## 검증

- `./scripts/test.sh` 765개 통과 — 새로 `RecallTests` 12개, `ReminderCenterTests` 12개(첫 실행에 묻지 않음, 켜면 묻고 미래만 걸기, 거절→재허용, 끄기, 시각 변경 재예약, 같은 것 유지, 삭제·체크 완료 제거, 해제 시 일정 시각, 60개 한도·초과 수, 실패 표시·재시도, OS 읽는 동안의 변경 폐기, 탭 전달).
- iOS 시뮬레이터 빌드 성공, XCUITest 2개 통과(`testRevisitWritesSurfaceAndNowBandShowsPinned`, `testRemindersSheetOpensFromMore`), `uitest.sh --shots` 로 목록·다시 보기 시트 화면 눈으로 확인. `check-l10n.sh` 패키지 넷 빠짐 0.
- 하지 못한 것: 맥 앱 번들 실행과 App Store용 `LazyMemo-macOS` Xcode 타깃 빌드(사용자가 중단), 실기기의 잠금·앱 종료 알림·거절→재허용·맥 왕복 손검증. 시뮬레이터에서 권한 창을 켜는 흐름은 시험하지 않았다.

## 메모

커밋하지 않았다 — 요청이 없었다. 작업 트리에는 다른 세션이 고친 `.oculpm/planner/lazymemo-app-store.md`·`lazymemo-ios-icloud.md` 와 미추적 `_template.md.bak`·`lazymemo-on-device-llm/` 이 함께 있으니 명시 경로로만 stage 할 것.