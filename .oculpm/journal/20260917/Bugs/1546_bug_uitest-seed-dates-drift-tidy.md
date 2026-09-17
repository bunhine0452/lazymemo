---
schema_version: 1
type: bug
slug: "uitest-seed-dates-drift-tidy"
status: done
difficulty: low
created_at: "2026-09-17T15:46:57+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
related:
  - ref: "20260917/Features_to_add/1537_feature_banner-actions-snooze-chips-login-postpone.md"
    kind: "followup"
  - ref: "20260915/Bugs/1342_bug_ios-uitest-now-seen-state-second-run.md"
    kind: "followup"
tags:
  - "ios"
  - "uitest"
  - "tidy"
  - "mcp-tool"
---
[x] `testSeenPutsTheCardDownIntoTheRest` 가 「나머지 5장」 대신 「2장」으로 빨갛던 것

## 발생 원인

`SmokeTests.seed()` 의 일정이 2026-09-14(장보기 due)·09-15(치과 at 15:00·회의 due)에 박혀 있었다. `Tidy.pastGrace`(지난 일정은 그 다음 날이 끝나면 물러난다)에 따라 09-17 부터 셋이 `store.active` 에서 빠졌고 — 띠에 오른 것도, 목록에 선 것도 줄어 「나머지」 수가 어긋났다. 같은 씨앗을 읽는 `testDateSheetShowsTheClock`(치과 줄을 연다)·`testCalendarShowsTheDay`(15일 칸)도 같은 길을 가고 있었다(달력은 10월이 되면 깨진다).

## 해결 방법

- `seed()` 가 일정을 **오늘 기준으로 날마다 다시 만든다**: 장보기 = 어제, 치과 = 오늘 15:00(tz offset 포함), 회의 = 오늘. id·created 는 2026-09 그대로(폴더·ULID 시각이 맞아야 한다).
- `testCalendarShowsTheDay` 는 「15일」 대신 오늘 칸을 누른다.
- 어제 쓴 `testPostponeFromTheListMovesTheDate` 의 주석을 맞췄다(치과가 오늘 것이라 띠에 오르므로 내일 15시 약속을 따로 심는다).

## 검증

- 시뮬레이터(iPhone 17) `SmokeTests` 전체 18개 통과(라이브 경로 시험은 env 없으면 건너뜀). `testHerePinAttachesAPlace` 는 `uitest.sh` 가 주는 위치 권한 없이 직접 돌리면 빨갛다 — 스크립트로 다시 돌려 통과.

## 메모

- `DemoTests.seed()` 는 처음부터 `today` 로 적고 있었다 — 그쪽을 따라간 것.