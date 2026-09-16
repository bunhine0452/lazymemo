---
schema_version: 1
type: error
slug: "ci-route-summary-race"
status: done
difficulty: low
created_at: "2026-09-16T21:17:22+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/RoutePlannerTests.swift"
    op: update
related:
  - ref: "20260916/Chores/2004_chore_release-0-6-0-route-demo.md"
    kind: "followup"
tags:
  - "ci"
  - "release"
  - "route"
  - "flaky"
  - "mcp-tool"
---
[x] v0.6.0 첫 릴리스가 CI 시험 하나로 멈췄다 — 되물음 요약이 다른 Task 에서 서는 경쟁

## 발생 원인

release 워크플로(macos-26)에서 `RoutePlannerTests.fullConversation` 이 `planner.summary` 에 자리 이름이 서기 전에 읽었다. `begin` 이 자리 찾기 Task 와 **별도의** Task 로 요약을 적었고, 시험은 파일에 좌표가 적힌 것(`store.memo.geo != nil`)만 기다렸다 — 그 뒤 요약 Task 가 언제 도는지는 정해져 있지 않았다. 맥에서는 늘 늦게 읽혀 통과했고 CI 에서만 빨갛게 나왔다. 릴리스는 만들어지지 않은 채였다(자산 없음).

## 해결 방법

자리 찾기 Task 안에서 파일에 적은 **직후** 요약도 적는다 — `await store.update` 가 돌아온 뒤 다음 줄까지 멈춤이 없어 차례가 정해진다. 시험도 요약이 서기를 기다린다(세 번 돌려 통과). 릴리스가 안 나간 태그라 `v0.6.0` 을 지우고 고친 커밋에 다시 달아 밀었다 → 워크플로 성공, `lazymemo-0.6.0.zip`·sha256. 서명 단계는 시크릿이 없어 skipped(ad-hoc, 0.5.0 과 같다).

## 검증

- 로컬 `RoutePlannerTests` 3회 연속 통과. release run 35094483000 success, `gh release view v0.6.0` 에 자산 둘.

## 메모

- 아이폰·맥 TestFlight 업로드는 각각 성공. 아이폰 첫 업로드는 「Couldn't communicate with a helper application」(일시적)로 끊겨 같은 아카이브로 다시 걸어 성공했다. CLiteRTLM dSYM 경고는 전부터 있던 것.
- 태그를 옮기는 것은 릴리스가 안 만들어졌을 때만 — 나간 판의 바이트는 안 바꾼다(README 「배포」).