---
schema_version: 1
type: feature
slug: "action-executor-conditional-modify"
status: done
difficulty: medium
created_at: "2026-09-15T15:11:56+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/ContentHash.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/ActionExecutor.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/ActionExecutorTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoServiceModifyTests.swift"
    op: create
related:
  - ref: "20260915/Features_to_add/1503_feature_assistant-contracts-coordinator.md"
    kind: "followup"
tags:
  - "jarvis"
  - "assistant"
  - "executor"
  - "memoservice"
  - "cas"
  - "mcp-tool"
---
[x] ActionExecutor — vault 안 조건부 변경(본문 hash 대조)·요청당 쓰기 하나·휴지통 확인·되돌리기, Core 에 Memo.contentHash 와 MemoService.modify

## 추가 기능 (명세 §5 `#action-executor`)

**Core**
- `Memo.contentHash` — 본문 SHA-256. `updated` 는 초 단위라 버전 토큰이 못 되므로 이것으로 「내가 본 그 글인가」를 대조한다.
- `MemoVault.modify(id, expectedHash:, change)` — 읽기·대조·쓰기를 **actor 한 호출 안**에서 한다. 사이에 `await` 가 없어 재진입이 끼지 못한다. 다르면 `Failure.changed`, 파일은 그대로. `moveToTrash` 도 `expectedHash` 를 받는다.
- `MemoService.modify` — vault.modify 위에 `update` 와 같은 후처리(folder 정규화·`updated`·`tidied=nil`)와 인덱스 갱신. `delete(id, expectedHash:)` 추가. 기존 `update`/`delete` 호출은 그대로 동작(기본값 nil).

**Assistant**
- `ActionExecutor`(actor): `ProposedAction` → 조건부 변경. 요청 ID 당 쓰기 하나(같은 요청 재실행은 저장 없이 영수증 반환), `trash` 는 `confirmedTrash` 필수, `ask`/`none` 은 `nothingToExecute`. `FieldPatch` 의 keep/clear/set 을 그대로 적용.
- `ActionReceipt`(before/after 스냅샷) + `undo` — `after` 의 hash 를 대조해 그 뒤 사용자가 고쳤으면 `undoStale`, 덮어쓰지 않음. createMemo 되돌리기는 휴지통 이동, trash 되돌리기는 복원.

## 동작 흐름

Coordinator `.proposedAction` → (UI 가 시각·되돌리기 표시, trash 는 확인) → `executor.execute` → `MemoService.modify(expectedHash)` → 영수증 → 되돌리기 버튼은 `executor.undo(receipt)`.

## 검증

- `MemoServiceModifyTests` 4개: hash 일치 변경·인덱스 반영, 불일치 시 `changed` 와 파일 보존, nil 은 대조 생략, 휴지통도 대조.
- `ActionExecutorTests` 7개(실제 임시 vault): setRecall 이 due/at 보존, hash 불일치 거부, 같은 요청 두 번은 메모 하나, clear/keep, 휴지통 확인·되돌리기, 그 뒤 고친 메모는 되돌리지 않음, ask 는 실행 없음.
- Coordinator 취소 테스트를 provider 훅으로 결정적으로 고쳤다(이전 것은 경쟁 조건). 전체 스위트는 회귀 확인 중.