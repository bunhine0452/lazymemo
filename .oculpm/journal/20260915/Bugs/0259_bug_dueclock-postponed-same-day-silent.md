---
schema_version: 1
type: bug
slug: "dueclock-postponed-same-day-silent"
status: done
difficulty: low
created_at: "2026-09-15T02:59:26+09:00"
session_id: "20260915-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/DueClock.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DueClockTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
tags:
  - "recall"
  - "dueclock"
  - "mac"
  - "mcp-tool"
---
[x] 맥에서 같은 날 미룬 종이가 다시 안 나온다 — 꺼낸 것을 id 만으로 기억했다

## 발생 원인
`DueClock.announced` 가 `Set<ULID>` 였다. 한 번 꺼낸 메모는 그날 `surface` 를 「한 시간 뒤」로 미뤄도 이미 알린 것으로 걸러져 새 시각에 종이가 안 나왔다. 시스템 배너(`ReminderCenter`)는 예약을 새 시각으로 다시 걸므로 배너는 울리고 종이는 조용한 날이 생긴다 — 리뷰 지적 1번.

## 해결 방법
`announced: [ULID: Date]` — 꺼낼 때 그 순간의 `surfacesAt` 을 함께 적고, `isAnnounced` 는 지금 적힌 시각과 같을 때만 참. 시각이 바뀌면 다른 약속이라 다시 울린다. `dayChanged` 는 그대로 전부 비운다. DESIGN §9.3.2 에 한 줄.

## 검증
`DueClockTests.postponedSameDayRingsAgain` 추가(14:00 울림 → surface 15:00 → 15:01 fire → 두 번째 울림). 패키지 시험 775개 통과.