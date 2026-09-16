---
schema_version: 1
type: feature
slug: "capture-assistant-merged"
status: done
difficulty: high
created_at: "2026-09-15T22:25:34+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Assistant/AssistantWindow.swift"
    op: delete
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/CommandResolver.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/ActionWords.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/CapturePrompt.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureAssistTests.swift"
    op: create
  - path: "docs/research/quick-capture-assistant-2026-09-15.md"
    op: create
  - path: "docs/research/apple-design-principles.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260915/Features_to_add/2158_feature_assistant-conversational-schedule.md"
    kind: "followup"
  - ref: "20260915/Bugs/2152_bug_assistant-intent-routing-korean-table.md"
    kind: "followup"
tags:
  - "assistant"
  - "capture"
  - "ux"
  - "design"
  - "mcp-tool"
---
[x] 빠른 입력 상자가 비서를 겸한다

## 추가 기능

사용자: 「메모에게 묻기가 아니라, 메모입력에 UI를 이제 융합해줘」. 설계는 fork 세션이 애플 원문(HIG popovers·search fields·text fields·feedback·undo·entering data)을 읽고 D1–D14 로 잠갔다(`docs/research/quick-capture-assistant-2026-09-15.md`, 캔버스 「빠른 입력 비서」). 구현은 그 문서를 따랐다.

- **모드 없음**: `QuickCaptureModel.commit()` 이 되물음의 답 → 고른 줄(시키는 말이면 그 줄에 적용, 후보 목록이면 「그 메모에게」) → 시키는 말 → 물음 → 날짜·자리 든 서술(`AssistantIntent.compose`) → 그냥 글 순으로 가른다. `intent` 가 같은 갈래를 부작용 없이 내고 ⌘↵ 라벨이 그것을 말한다.
- **되묻기**(D6·D12): 약속인데 시각이 없으면 상자가 남고 초안 요약 줄·질문·칩(12시·점심·저녁 7시·시각 없이)·자리표 「12시야」. 답이 오면 기존 길(`store.create` + announce)로 닫힌다. esc 는 「시각 없이」로 적는다.
- **답**(D9): `AssistantModel.onSettled` 로 목록을 근거·관련·후보로 갈아 끼운다(`showMemos`). 답 한 문장 + 인용 줄, 머리글 「근거 N장」. 글을 고치면 `assistant.reset()`.
- **시키기 결과**(D8): 결과 줄 + 되돌리기(지운 줄과 같은 자리). 휴지통만 되묻는다. 대상이 없으면 「어느 메모? ↓ 로 고르고 ⌘↵」.
- **자리 칩**·「열린 메모 · 제목 ×」 칩. 종이 우클릭 「이 메모에게 시키기…」→ `menuBar.showCapture(target:)`. 물음은 `MemoRanker` 로 찾고, 시키는 말은 목록을 비우지 않는다(대상을 ↓ 로 고를 수 있게).
- **모델 없음**(D11): 묻기만 「모델을 받으면 답합니다 · 받기」 줄 + 진행 막대.
- `AssistantWindow` 와 메뉴 「메모에게 묻기…」 삭제. 폰의 시트는 그대로(후속).

## 동작 흐름

⌥⌘N → 치는 동안 파서·랭커만(칩·목록) → ⌘↵ → 라벨의 일. 물음이면 「메모를 읽는 중 · esc 그만」 → 답+근거. 서술이면 적고 닫힘, 시각이 빠진 약속이면 질문 하나. 시키기면 결과 줄 + 되돌리기.

## 검증

- `CaptureAssistTests`·`CaptureIntentTests` 7개(갈래·라벨·후보 고르기·esc 초안·되물음 답). 전체 829개 통과.
- `scripts/render-ui.sh` 로 capture-asking·answer·applied·candidates 를 PNG 로 렌더해 눈으로 봤다 — 결과 줄이 한 줄에서 잘려 제목을 14자로 줄이고 줄바꿈을 허용했고, 시각 표기를 날짜 칩과 같은 꼴로 맞췄다.
- 사람 손 검증(클릭·키·포커스·모델 실답)은 아직 — 사용자가 앱을 다시 띄워 봐야 한다.
- 커밋 `4f4fb12`, 푸시. MenuBarController 의 다른 세션 hunk(스토어 판 개발 메뉴 가드)는 남겨 두었다.