---
schema_version: 1
type: bug
slug: "resolver-ignores-request-timezone"
status: done
difficulty: low
created_at: "2026-09-16T18:17:22+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: update
  - path: "Tests/LazyMemoSpotlightTests/SpotlightCenterTests.swift"
    op: update
related:
  - ref: "20260916/Features_to_add/1522_feature_ci-on-push-and-pr.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2158_feature_assistant-conversational-schedule.md"
    kind: "followup"
tags:
  - "assistant"
  - "timezone"
  - "ci"
  - "note-reader"
  - "command-resolver"
  - "mcp-tool"
---
[x] 비서의 새 메모 경로가 요청의 시간대를 무시했다

## 발생 원인

`ci.yml` 의 첫 실제 실행(macOS 26.6.2 · Swift 6.3.3 · **UTC** 러너)에서 837개 중 3개가 빨갔다 — 전부 `CommandResolverTests` 의 새 메모 만들기: 「9월 30일 12시에 친구랑 밥」이 03:00Z(KST 정오)여야 하는데 12:00Z 가 나왔다. `CommandResolver.resolve` 는 `request.timeZone` 으로 `calendar` 를 만들지만, 새 메모 본문·날짜를 읽는 `NoteReader.read(text, now:)` 에 그것을 넘기지 않았고, `NoteReader` 는 `NaturalDateParser.parse(_, now:)` 를 `.current` 로 불렀다. 앱에서는 요청의 시간대가 곧 기계의 시간대라 사용자가 볼 일은 없었고, 기계가 다 KST 라 아무도 못 봤다 — CI 가 처음 다른 시간대에서 돌린 것이다.

같이 잡힌 것: `SpotlightCenterTests` 「지문은 UserDefaults 에 남아…」가 로컬에서 한 번 빨갔다. 첫 center 를 살려 둔 채 둘째를 만들어 저장소 변경에 둘이 함께 올렸다(순서 따라 통과/실패). 첫 center 를 `nil` 로 놓아 관찰을 멎게 했다.

## 해결 방법

`NoteReader.read(_:place:now:calendar:)` 에 `calendar: Calendar = .current` 를 뚫고 `NaturalDateParser.parse` 에 넘긴다. `CommandResolver` 의 두 호출(`body(text:model:now:calendar:)`·`let note = NoteReader.read(text, now:, calendar:)`)이 요청의 calendar 를 준다. 다른 호출자(빠른 입력·공유·MCP)는 기본값이라 그대로다.

## 검증

- `TZ=UTC ./scripts/test.sh` 전체 **837 통과**, `TZ=Asia/Seoul` 도 통과. 고치기 전 UTC 에서는 CommandResolver 3건 실패 재현.
- Spotlight 시험은 다섯 번 연속 통과.