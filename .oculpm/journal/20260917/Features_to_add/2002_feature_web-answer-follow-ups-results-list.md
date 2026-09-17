---
schema_version: 1
type: feature
slug: "web-answer-follow-ups-results-list"
status: done
difficulty: high
created_at: "2026-09-17T20:02:14+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/WebFollowUp.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/ActionExecutor.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/OutputValidator.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/ActionWords.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoAssistantTests/WebFollowUpTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureAssistTests.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260917/Features_to_add/1228_feature_assistant-web-search-ddg.md"
    kind: "followup"
tags:
  - "assistant"
  - "web-search"
  - "ux"
  - "mac"
  - "ios"
  - "mcp-tool"
---
[x] 웹의 답 뒤 「이걸 어떻게 할까요?」— 남기기·정리해서 남기기·기존 메모에 붙이기, 그리고 결과 전부가 보이는 카드 (맥·폰)

## 추가 기능

사용자: 「웹 검색 이후 사용자가 메모해, 정리해줘, 어디 메모에 추가해줘 등 같은 다음 액션들을 예상해서 AI 가 물어보도록」 + 「검색 결과가 제대로 안 보이는데 좀 "잘" 보이게」.

**결과가 보인다.** 12:28 판은 답이 인용한 한두 줄만 작은 글자(두 줄 잘림)로 세웠다 — 모델이 다섯 중 하나를 고르면 나머지 넷은 있었는지도 몰랐다. 지금은 `AssistantModel.webResults` — 근거 목록(`evidence`) 전부를 **인용한 것이 앞**(점이 찍힌다)으로 카드에 한 칸씩: 제목·출처(host)·발췌 세 줄, 칸 전체가 단추(브라우저로), 머리에 「🌐 웹에서 찾음 · 물음」. 맥은 `webAnswer`/`webResultRow`, 폰은 `StackView.answerRow`/`webResultRow`. 렌더·시험처럼 근거 목록이 없으면 답의 출처로 그린다.

**AI 가 묻는다.** 답 밑에 「이걸 어떻게 할까요?」와 칩 셋 — `WebFollowUp`:
- `.keep` **메모로 남기기** — 답 한 줄(답 문장이 없으면 물음), 인용한 출처마다 제목·발췌·주소, 끝에 「「물음」 웹에서 찾음 · 9월 17일」. `createMemo` 로 바로 적고 되돌리기 줄.
- `.tidy` **정리해서 남기기**(모델이 있을 때만) — 답·발췌(주소 뺀 것)를 `tidy` 태스크로 다듬고 앱이 출처·꼬리를 도로 단다. 코디네이터의 tidy 가 `selectedMemoID` 없이 `userText` 도 받게 됐다. 다듬는 동안 「정리하는 중」.
- `.append(hint:)` **기존 메모에 붙이기** — 새 `ActionKind.appendToMemo`(실행기: 끝에 한 줄 띄우고 잇기, 되돌리기는 before 본문, hash 대조). **앱만 만든다** — 모델 스키마·`normalizeKind` 에 없고 `CommandResolver` 는 unsupported 로 되묻는다. 이름을 댔으면(「치과」) `MemoServiceEvidenceSource.search` 로 찾아 한 장이면 바로, 여럿이면 후보, 없으면 요즘 메모 20장이 후보 — 「어느 메모에 붙일까요?」(`asksWhichMemo` 가 이 물음도 안다 → 목록이 후보, 줄을 고르면 `pick` 이 붙인다).

**말로 해도 같다.** `WebFollowUp.read` — 「메모해」「저장」「이거 메모로 남겨줘」→ keep · 「정리해줘」「요약해서 남겨」→ tidy · 「치과 메모에 추가해줘」「장보기에 넣어줘」→ append(hint) · 「기존/어디 메모에 추가」→ append(nil). 다른 내용이 든 말(「내일 우산 챙기기 메모해」)·물음표·새 검색은 아니다. **웹의 답이 서 있을 때만** — 그래서 맥 상자와 폰 펜은 글을 쳐도 웹의 답을 지우지 않는다(D9 의 예외, `keepsWeb`); 새 메모·열기로 끝나면 그때 물러난다. ⌘⏎ 라벨/단추가 「메모로 남기기」「「치과」에 붙이기」로 바뀐다.

## 동작 흐름

「웹에서 서울 내일 날씨」→ 카드(답 한 문장 + 결과 5칸, 인용 2칸 앞) → 「이걸 어떻게 할까요?」 [메모로 남기기] [정리해서 남기기] [기존 메모에 붙이기] → 「치과 메모에 추가해줘」 치면 라벨 「「치과」에 붙이기」→ ⌘⏎ → 「「치과 예약」 끝에 덧붙입니다 · 되돌리기」, 파일 끝에 답·출처·주소·꼬리.

## 검증

- `./scripts/test.sh` 전체 939 초록. 새 시험: `WebFollowUpTests` 9건(말 읽기 세 갈래·가리킨 메모 없음·다른 말은 아님·본문 짓기·모델 없는 답·다듬기 초안/출처 붙이기·붙이기 실행+되돌리기·후보 물음·모델 스키마에 없음), `CoordinatorTests.tidiesLooseText`, `CaptureAssistTests.webFollowUpRouting`(답 없을 땐 시키기, 있으면 followUp, 치는 동안 답 유지).
- `scripts/render-ui.sh` 로 `capture-web-answer`(결과 5칸 + 칩) 라이트·다크 확인 뒤 삭제. `check-l10n.sh` 새 열쇠 빠짐 없음(남은 빠짐은 기존 PreviewRenderer 표본·`약속 시간이 언제인가요?`·`지하철`).
- 시뮬레이터(iPhone 17, 모델 없음) 임시 XCUITest: 실제 DDG → 카드(결과 5칸, 인용 3) → 펜에 「치과 메모에 추가해줘」→ 단추 「「치과」에 붙이기」→ 「「치과 예약 강남역 3번 출구」 끝에 덧붙입니다 · 되돌리기」→ 파일에 출처 주소가 붙음을 확인 뒤 시험 파일·PNG 삭제.
- 실모델의 「정리해서 남기기」는 아직 손검증 전(`LAZYMEMO_MODEL_PATH` 시험은 이번에 안 돌림).

## 메모

- `ActionWords.describe(.createMemo)` 는 여러 줄 본문이면 첫 줄만 — 웹 메모의 결과 줄이 본문을 통째로 되읽던 것.
- 붙일 메모를 고르는 동안은 답 카드를 내린다(`chooseWhereToAppend` 가 `answer = nil`) — 맥 `reflectAssistant` 가 웹 답을 먼저 보고 목록을 비워 후보가 안 서기 때문. 붙인 뒤에는 결과 줄만 남는다.
- 다른 세션의 미커밋 변경이 같은 파일(`StackView.swift`·`README.md`·UI `Localizable.strings`)에 있다 — 커밋할 때 hunk 를 갈라 stage 할 것.