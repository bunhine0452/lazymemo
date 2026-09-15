---
schema_version: 1
type: feature
slug: "assistant-command-without-model-ios"
status: done
difficulty: low
created_at: "2026-09-15T21:20:56+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: update
related:
  - ref: "20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md"
    kind: "followup"
tags:
  - "assistant"
  - "ios"
  - "llm"
  - "mcp-tool"
---
[x] 모델 없이도 시키기 — 폰·맥 공통

## 추가 기능

사용자가 「모바일은?」 하고 물었다. 폰은 `LazyMemoAssistantUI` 를 SPM 으로 그대로 쓰므로 검색·해석·인용 개선이 전부 적용되지만, 폰에서 2.4GB 를 받는 것은 큰 부탁이다. 시키기의 흔한 말(동사+시각+열린 메모)은 `CommandResolver` 가 모델 없이 끝내므로, 모델 유무 가드를 그 뒤로 옮겼다.

- `Coordinator.perform`: 시키기는 먼저 말만으로 해석하고, 모델이 필요할 때만 `ready` 를 요구한다. 묻기·다듬기·브리핑은 전처럼 모델 필수.
- `AssistantView`: 모델이 없어도 입력 줄이 보이고 모드는 시키기로 고정, 묻기 토글·「오늘」은 비활성. 받기 패널은 그대로 위에.
- 맥 종이 우클릭 「이 메모에게 시키기…」는 모델 유무와 무관하게 늘 선다.
- 모델 없음 메시지에 「시각·할 일을 분명히 말하면 모델 없이도 됩니다」를 덧붙였다.

## 동작 흐름

폰 편집 화면 ✦ → 시트 → 「금요일 오전 10시에 다시 알려줘」 → 앱이 읽어 즉시 제안 → 적용/되돌리기. 낯선 말(「이거 없던 걸로」)은 모델이 필요하고, 없으면 명시 실패.

## 검증

- `CoordinatorTests.commandWithoutModel`: ready=false 에서 분명한 말은 setRecall 제안, 낯선 말은 modelUnavailable. assistant 테스트 37개 통과.
- `xcodebuild -scheme LazyMemo-iOS -destination 'iPhone 17 Pro'` BUILD SUCCEEDED. 실기기·시뮬레이터 손검증은 안 했다.