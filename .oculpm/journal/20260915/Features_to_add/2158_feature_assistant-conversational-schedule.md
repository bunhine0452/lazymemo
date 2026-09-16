---
schema_version: 1
type: feature
slug: "assistant-conversational-schedule"
status: done
difficulty: medium
created_at: "2026-09-15T21:58:22+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/ActionExecutor.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/ActionWords.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/CommandResolverTests.swift"
    op: update
related:
  - ref: "20260915/Bugs/2152_bug_assistant-intent-routing-korean-table.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md"
    kind: "followup"
tags:
  - "assistant"
  - "ux"
  - "schedule"
  - "mcp-tool"
---
[x] 대화로 일정 만들기

## 추가 기능

사용자가 바란 UX: 「9월 30일에 [네이버 지도 링크] 여기서 친구랑 밥먹기로 했어」 하면 위치와 날짜를 스스로 넣고, 비서가 「약속 시간이 언제인가요?」 묻고, 「12시야」 하면 스스로 일정을 만든다.

- 서술 → 새 메모: `CommandResolver` 가 `NoteReader.read`(빠른 입력·공유 시트와 같은 한 규칙)로 날짜·시각·`@장소`·지도 링크의 자리·좌표를 읽는다. 「메모」라는 말 없이도 날짜·장소가 든 서술은 createMemo. `AssistantIntent` 도 같은 기준(물음말이 없고 날짜·장소가 있으면 command).
- 시각 되묻기: 약속 낱말(밥·만나·회의·예약·먹기로…)이 있고 날짜만 있으면 `ask` + `draft`(FieldPatch). `AssistantModel` 이 draft 를 들고 있다가 다음 말을 `AssistantIntent.complete` 로 잇는다 — 「12시야」「저녁 7시 반」은 그 날 그 시각, 「몰라」는 날짜만, 답이 아니면 새 말.
- 바로 적기: 휴지통을 뺀 쓰기는 확인 없이 적용하고 되돌리기를 든다(명세 §5 「저장 결과+되돌리기」). 되돌리기 줄이 「새 메모: … · 약속 9월 30일 12:00 · 자리 홍대입구」처럼 무엇을 했는지 말한다.
- `FieldPatch.place/geo`(createMemo 만), `ProposedAction.draft`.

## 동작 흐름

말 → 물음말? 답변 / 동사·날짜·장소? 시키기 → NoteReader 로 초안 → 약속인데 시각 없음? 「약속 시간이 언제인가요?」(입력 자리표도 「답을 적어 주세요 — 12시야」) → 답 → 완성 → 즉시 저장 → 되돌리기 8초… 아니, 되돌리기는 창이 열린 동안 유지.

## 검증

- `DraftConversationTests` 3개: 날짜·장소 채우고 시각만 묻기, 「12시야」·「저녁 7시 반」·「몰라」 완성, 시각까지 말했거나 약속이 아니면 바로 적기, 「9월 30일에 뭐 있지?」는 답변. assistant 41개·전체 822개 통과.
- 실모델 벤치 command/ambiguous/safety 100% 유지(새 규칙이 S05·S10 을 건드리지 않음).
- 커밋 `0f420bb`, 푸시. GUI 손검증은 못 했다 — 지도 링크 붙여넣기 → 좌표 읽기는 `MapLink.spot` 이 아는 링크 모양에 달렸다.

## 메모

- 「일까」를 물음말로 두면 「3일까지」가 질문이 된다 — 「일까?」로.
- 날짜를 덜어낸 자리의 조사(「9월 30일에」→「에 …」)는 본문 앞에서 뗀다.