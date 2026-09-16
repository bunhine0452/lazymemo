---
schema_version: 1
type: feature
slug: "assistant-contracts-coordinator"
status: done
difficulty: medium
created_at: "2026-09-15T15:03:58+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Provider.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Prompts.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/OutputValidator.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/EvidenceSource.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Prompts.swift"
    op: update
  - path: "spikes/SpikeKit/Sources/SpikeKit/Bench.swift"
    op: update
  - path: "spikes/LiteRTSpike/Sources/LiteRTSpike/LiteRTGenerator.swift"
    op: update
  - path: "spikes/README.md"
    op: update
  - path: "docs/research/local-model-benchmark-2026-09-15-schema.md"
    op: create
related:
  - ref: "20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md"
    kind: "followup"
tags:
  - "jarvis"
  - "assistant"
  - "contracts"
  - "coordinator"
  - "litert"
  - "mcp-tool"
---
[x] LazyMemoAssistant 타깃 — 요청·근거·제안된 변경·provider 계약과 Coordinator, mock provider 테스트 11개; schema 제약 디코딩은 구조만 잡고 뜻은 못 잡는다

## 추가 기능 (명세 §2~3 `#assistant-contracts`)

새 SwiftPM 타깃 `LazyMemoAssistant` — **LazyMemoCore 에만 의존**, 추론 엔진을 링크하지 않는다. Core·MCP·Share Extension 은 이 타깃도 모른다(Package.swift 의존 그래프로 보장).

- `Contracts.swift`: `AssistantRequest`(task/userText/selectedMemoID/now/timeZone/locale/예산), `Evidence`(memoID·본문 SHA256 `contentHash`·발췌·schedule·surface·folder·state), `FieldChange<T>`(keep/clear/set — MemoService 의 `T??` 로 옮기는 `doubleOptional`), `FieldPatch`, `ActionKind` allowlist(setRecall/reschedule/moveToFolder/createMemo/trash/ask/none), `ProposedAction`(expectedContentHash 포함), `AssistantEvent`, `AssistantFailure`, `TokenBudget`(4096 / 192·384·256).
- `Provider.swift`: `LocalModelProvider`(availability/prepare(profile)/stream(prompt)/cancel/unload), `ModelProfile`(idleUnload·peak 예산), `ModelAvailability`, `AssistantPrompt`(system/user/maxOutputTokens/jsonSchema).
- `Prompts.swift`: spike 와 **같은 문장**. 엔진에 따라 지시문을 바꾸지 않는다.
- `OutputValidator.swift`: JSON 추출(코드펜스 걷기), `id:` 접두어 제거, 인용 id 는 보여 준 근거만(없는 id 는 버리고 다 버려지면 답도 버림), brief 는 셋·active 만·중복 제거, action 은 allowlist·kind 별 필드만(`setRecall` 은 surface 만)·「이거」는 열린 메모만·보여 주지 않은 대상은 ask·빈 문자열 clear/없는 키 keep·파싱 실패는 통째로 실패.
- `EvidenceSource.swift`: 읽기 전용 프로토콜 + `MemoService` 기본 구현(search/get/today, Recall.eligible 필터). 질의 확장·문단 자르기·토큰 예산은 `#evidence-retrieval`.
- `Coordinator.swift`: actor. 세대 번호로 취소/새 요청 뒤 옛 이벤트 차단, 읽기 ≤4·모델 호출 ≤3, 구조 오류 1회 교정, tidy 만 delta 스트리밍(JSON 은 완결 뒤 검증), **실행은 하지 않고 `ProposedAction` 까지만**. 저장·CAS 는 `#action-executor`.

## 동작 흐름

`run(request)` → loading → availability 확인 → prepare → 열린 메모 get + 검색/오늘 후보 → `.evidence` → 생성 → 검증(실패 시 교정 1회) → `.proposedAction`/`.completed` 또는 `.failed`.

## schema 제약 디코딩 실험 (spike `--schema`, M4 참고)

kind 가 allowlist 밖으로 새는 일은 사라졌고 ambiguous 0→57%, brief 50→60%. 그러나 answer 62→46%(스키마 안에서 `found:false` 로 도망·`id:` 접두어), 상대 날짜 계산은 여전히 틀림. **구조는 잡고 뜻은 못 잡는다.** 다음: 날짜는 `NaturalDateParser` 로 넘기는 계약, Qwen3-4B 비교.

## 검증

- `scripts/test.sh --filter LazyMemoAssistantTests`: 11/11 통과 — 없는 id 버림, 근거 없는 found=true 거부, setRecall 이 at/due 를 keep, clear/keep 구분, allowlist 밖 kind 교정 1회 뒤 실패, 열린 메모 우선, 보여 주지 않은 대상 ask, brief 필터, 취소 뒤 완료 이벤트 없음, 모델 없음 상태, tidy 스트리밍·코드펜스 제거.
- `swift build` 전체 통과. 실모델 연결(LiteRT provider 어댑터)은 미구현 — spike 에서만 돈다.