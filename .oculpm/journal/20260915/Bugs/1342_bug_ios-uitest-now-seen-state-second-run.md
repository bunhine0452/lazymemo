---
schema_version: 1
type: bug
slug: "ios-uitest-now-seen-state-second-run"
status: done
difficulty: low
created_at: "2026-09-15T13:42:52+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/APP_STORE_READINESS.md"
    op: update
related:
  - ref: "20260915/Chores/1339_chore_release-readiness-tests-privacy-store-copy.md"
    kind: "followup"
tags:
  - "ios"
  - "uitest"
  - "flaky"
  - "simulator"
  - "mcp-tool"
---
[x] 아이폰 UI 시험이 둘째 실행부터 빨갛다 — 「봤어요」가 시뮬레이터에 남아 고정 카드가 안 선다

## 발생 원인

전체 XCUITest 를 두 번 연달아 돌리니 첫 번은 15 통과, 둘째는 `testRevisitWritesSurfaceAndNowBandShowsPinned`·`testSeenPutsTheCardDownIntoTheRest` 둘이 「고정한 메모가 카드로 서야 한다」로 빨갛다. `NowSeen` 은 「봤어요」를 `UserDefaults.standard["now-seen"]` 에 그날의 이름표로 적는데(설계대로 — 기기별 기억), 씨앗의 메모 id 가 고정이라 앞 실행의 `testSeen…` 이 내려놓은 카드가 같은 날의 다음 실행에서도 내려간 채다. 앱 컨테이너의 defaults 는 `LAZYMEMO_VAULT` 를 새로 줘도 그대로다. 알림 켜짐(`recall.notifications.enabled`)이 같은 결로 `testRemindersSheetOpensFromMore` 를 빨갛게 하던 것과 한 뿌리.

## 해결 방법

`launch()` 의 실행 인자에 `-now-seen {}` 을 더했다 (`-recall.notifications.enabled NO` 옆). 인자 도메인이 저장된 값을 가리므로 매 실행이 첫 실행이고, 시험 안에서 「봤어요」를 누르면 `@State` 가 바뀌어 화면은 그대로 검증된다.

## 검증
- Revisit → Seen → Revisit 순으로 셋 연달아 돌려 전부 통과 (둘째 Revisit 이 앞의 Seen 을 안 본다).
- 전체 15개는 앞 실행에서 통과, 이 인자로 상태가 갈리는 두 시험만 다시 돌렸다.