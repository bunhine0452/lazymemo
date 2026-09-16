---
schema_version: 1
type: chore
slug: "release-readiness-tests-privacy-store-copy"
status: done
difficulty: medium
created_at: "2026-09-15T13:39:41+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tests/LazyMemoRemindersTests/ReminderCenterTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "site/privacy/index.html"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/STORE_LISTING.md"
    op: update
  - path: "docs/APP_STORE_READINESS.md"
    op: update
related:
  - ref: "20260915/Bugs/1339_bug_korean-app-english-plurals-words-locale.md"
    kind: "followup"
  - ref: "20260915/Chores/0308_chore_testflight-upload-recall-polish.md"
    kind: "followup"
tags:
  - "release"
  - "app-store"
  - "privacy"
  - "tests"
  - "mac"
  - "ios"
  - "mcp-tool"
---
[x] 정식 출시 점검 — 시험 위생·스토어 판 메뉴·개인정보 처리방침·스토어 원고·출시 날 할 일

기계로 돌릴 수 있는 것을 전부 돌렸다: 패키지 시험 776 · `verify-*.sh` 12개 · `verify-mcp.sh` · XCUITest 15 · 맥 스토어 타깃 xcodebuild. 언어 버그(관련 일지)를 빼고 남은 것들.

- **시험이 `~/Library/Preferences` 에 plist 를 남긴다.** `ReminderCenterTests` 가 실행마다 `UserDefaults(suiteName: "lazymemo-reminders-<UUID>")` 를 만들고 지우지 않아 96개가 쌓여 있었다. 임시 폴더와 같은 이름의 도메인을 쓰고 `cleanUp` 이 도메인을 비운 뒤 cfprefsd 가 남기는 빈 plist 까지 지운다. 쌓인 것은 치웠다.
- **소개 영상이 시뮬레이터에 상태를 남긴다.** `DemoTests` 가 알림을 켜 두고 가면 `testRemindersSheetOpensFromMore` 가 「첫 실행」이 아니라 빨갛다. 시험 실행 인자에 `-recall.notifications.enabled NO`.
- **스토어 판 메뉴의 개발용 항목.** ⌥ 를 누른 채 메뉴를 열면 「바탕화면 창 스파이크」가 나왔다 — 심사자가 볼 수 있다. `updater.source.isAppStore` 면 항목을 만들지 않는다. `.build` 밖에 복사한 스토어 타깃 빌드로 메뉴에 Claude·업데이트·스파이크 줄이 없는 것을 확인.
- **개인정보 처리방침이 코드보다 적게 말했다.** 「알림 — 요구하지 않는다」(다시 보기가 켤 때 묻는다), 자리 카드·가는 길이 폰 것으로만(맥 종이 머리에도 있다). `docs/PRIVACY.md`·`site/privacy/`(ko·en)·README 표를 맞추고 날짜를 09-15 로.
- **스토어 원고.** 설명에 「다시 보기」 한 줄, 심사 메모에 알림 권한 문단 — ASC 에 옮겨 적을 것.
- `docs/APP_STORE_READINESS.md` 에 찾은 것 표와 「출시 날 할 일」 여섯 단계. 첫째가 **새 빌드 업로드** — ASC 의 빌드에 「1 photos」가 들어 있다.

## 검증
- 시험 776·XCUITest 15·verify 12+MCP 전부 초록. `ReminderCenterTests` 뒤 `~/Library/Preferences` 에 `lazymemo-reminders-*` 0개.
- `site/` 외부 요청 검사(pages.yml 의 grep) 통과.