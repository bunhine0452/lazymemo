---
schema_version: 1
type: feature
slug: "assistant-retrieval-resolver-quality"
status: done
difficulty: high
created_at: "2026-09-15T21:17:38+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/Retrieval.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/OutputValidator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Prompts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/EvidenceSource.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/NaturalDateParser.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/ActionWords.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/Words.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoAssistantBench/main.swift"
    op: create
  - path: "Package.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/RetrievalTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CommandResolverTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/AnswerValidatorTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/Fixtures.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: update
  - path: "docs/research/local-model-benchmark-2026-09-15-app.md"
    op: create
  - path: "docs/research/local-model-benchmark-2026-09-15-app-retrieval.md"
    op: create
  - path: "spikes/README.md"
    op: update
related:
  - ref: "20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md"
    kind: "followup"
tags:
  - "assistant"
  - "llm"
  - "retrieval"
  - "bench"
  - "mcp-tool"
---
[x] 로컬 비서를 쓸 만하게 — 낱말 검색·앱이 정하는 날짜/대상/동사·원문 인용·앱 파이프라인 벤치

## 추가 기능

사용자 평: 「LLM 기능이 전혀 이 앱에 도움이 되지 않는다」. 원인 셋 — ① `MemoService.search` 가 질문 문장을 FTS 구(phrase)로 통째로 던져 「치과 언제였지?」가 아무것도 못 찾음(실제 앱에서 묻기가 거의 항상 「찾지 못했습니다」), ② 날짜 계산·대상 선택·동사 판단을 2B 모델에 맡겨 spike 벤치 command 30%·ambiguous 0%·safety 44%, ③ 모델이 answer 를 비우거나 「: 」만 적어도 그대로 실패.

- `Retrieval.swift`: `QueryTerms`(조사·어미·물음말 제거, 동의어 표, 개념 단위)·`MemoRanker`(메모리 점수 랭킹, 어간 부분 일치, 최근성 미세 가산). `MemoServiceEvidenceSource.search` 가 이것을 쓴다.
- `CommandResolver.swift`: 동사 낱말표(알려줘/띄워→setRecall, 지워→trash, 폴더→moveToFolder, 미뤄/옮겨→reschedule, 메모 만들어→createMemo), 중단어·전부·흐린 시각(주말·나중) 처리, 시각은 `NaturalDateParser` + 열린 메모 기준 상대 표현(한 시간 전·전날 아침 9시·30일 전) + 「다음 주 X요일」주간 계산 + 「20일로」 + 「다음 달 5일」, 대상은 열린 메모만(없으면 후보를 들고 ask). 셋이 갖춰지면 Coordinator 가 모델을 올리지도 부르지도 않는다.
- `OutputValidator`: 짝 맞는 첫 JSON 객체만, id 접두어·객체 인용 허용, 답 밑에 근거 원문 인용(`AssistantAnswer.quotes`), answer 비었어도 근거를 맞게 댔으면 원문이 답, 질문 개념 ≥2 담은 메모는 모델이 못 찾아도 답, 질문과 안 겹치는 인용은 버림, 동점 메모는 함께, 브리핑 잘린 JSON 건지기·오늘 시각 메모 우선.
- `Prompts`: 답변은 자유 생성(제약 디코딩 해제 — answer 비움·p95 3.3s→1.0s), 명령 프롬프트는 날짜 계산 금지, 다듬기에 금액·URL·첨부 이름 보존, `[메모 ID]` 렌더링.
- UI: ask 후보 칩(누르면 그 메모에게 같은 말), 못 찾았을 때 관련 메모, 인용 줄 표시; 맥 종이 우클릭 「이 메모에게 시키기…」(모델 있을 때만).
- `lazymemo-assistant-bench` 실행 타깃: 80문항을 Coordinator→검증→해석까지 태워 사용자가 받는 결과를 채점. `--retrieval`(앱 검색), `--retrieval-only`, `LAZYMEMO_ASSISTANT_TRACE=1`.

## 동작 흐름

묻기: 질문 → 낱말 → 전 메모 점수 랭킹 상위 6 → 모델(자유 생성) → 인용 검증·원문 줄 → 화면(답+인용+근거 칩; 못 찾으면 관련 메모).
시키기: 말 → 중단어? → 동사·시각·대상 해석 → 다 있으면 즉시 제안(모델 0회) / 비면 한 가지 질문(+후보) / 낯선 말이면 모델에게 kind·폴더·본문만 묻고 다시 해석 → 적용/되돌리기는 기존 executor.

## 검증

- `./scripts/test.sh` 817개 통과(assistant 36개: Recall@6 fixture 21/22, 해석기·검증기 결정적 테스트).
- 앱 파이프라인 벤치(M4 Pro, 참고용) fixture 후보: answer 95%·command 100%(모델 0회)·tidy 100%·brief 100%·ambiguous 100%·safety 100%. 앱 검색 모드: answer 87%(A10·X05·X06), 나머지 100%. spike 대비 command 30→100, ambiguous 0→100, safety 44→100, answer 62→95.
- 실기기·GUI 손검증은 못 했다(모델 symlink 는 앱 support 에 앉혀 둠).

## 메모

- `DayParser` 의 「다음 주 X요일」은 「다음 X요일 + 7일」이라 화요일에 말한 「다음 주 월요일」이 13일 뒤가 된다. 빠른 입력의 기존 결정이라 Core 는 두고 비서만 주간 계산으로 갈랐다 — 재검토 후보.
- 남은 answer 실패: 두 메모 종합(A10), 근거 없는 질문에 낱말 하나 겹치는 메모를 댐(X05), 충돌 메모 하나 누락(X06).