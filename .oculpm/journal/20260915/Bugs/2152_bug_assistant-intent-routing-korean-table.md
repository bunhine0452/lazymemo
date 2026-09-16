---
schema_version: 1
type: bug
slug: "assistant-intent-routing-korean-table"
status: done
difficulty: low
created_at: "2026-09-15T21:52:24+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Prompts.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/Resources/ko.lproj/Localizable.strings"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CommandResolverTests.swift"
    op: update
related:
  - ref: "20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md"
    kind: "followup"
  - ref: "20260915/Bugs/1339_bug_korean-app-english-plurals-words-locale.md"
    kind: "followup"
tags:
  - "assistant"
  - "l10n"
  - "ux"
  - "mcp-tool"
---
[x] 비서 창에서 질문이 막히고 영어 UI 가 섰다

## 발생 원인

사용자 화면(2026-09-15 21:35, 맥): 「Do」 칸에 「모두의 창업 마감일이 언제야?」를 넣자 「무엇을 할지 모르겠다」와 후보 칩만 떴고, 창의 말이 «Ask · Do · Send · Gemma 4 E2B is on this device» 였다.

1. 묻기/시키기를 사람이 고르게 했다. 질문을 시키기로 보내면 해석기가 동사를 못 찾아 되묻는다.
2. 되물음의 문장이 모델의 것이었다 — 모델이 지시문의 gloss 「ask(무엇을 할지 모르겠다)」를 question 에 그대로 옮겨 적었다.
3. `LazyMemoAssistantUI/Resources` 에 `ko.lproj` 가 없었다. Foundation 은 ko 표가 없으면 개발 언어(영어) 표로 건너뛴다 — Core/UI 는 거의 빈 ko 표를 두어 이것을 막고 있었다(1339 일지와 같은 뿌리).

## 해결 방법

- `AssistantIntent.classify`: 동사(알려줘·미뤄·폴더로·지워·메모 만들어)나 「…8시로」가 있으면 command, 아니면 answer. `AssistantModel.send` 가 이것으로 가르고, 화면의 고르는 칸은 없앴다.
- 모델의 question 은 물음표(또는 「요」)로 끝나는 4~60자일 때만 쓴다. 지시문의 gloss 는 「되묻기」로, 되물음은 「물음표로 끝나는 한 문장」으로.
- `ko.lproj/Localizable.strings` 를 (주석만 있는 채로) 둔다.

## 검증

- `IntentTests`: 질문 둘은 answer, 동사·「…시로」·폴더·중단어는 command. assistant 테스트 38개 통과, `swift build` 통과.
- 커밋 `d73ca86`, 푸시. 화면은 사용자가 앱을 다시 띄워 봐야 한다 — 한국어 표는 Core/UI 와 같은 장치라 같은 결과를 기대한다.