---
schema_version: 1
type: feature
slug: "thinking-ink-assistant-progress"
status: done
difficulty: medium
created_at: "2026-09-17T22:11:42+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/ThinkingInk.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/CoordinatorTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260917/Features_to_add/1228_feature_assistant-web-search-ddg.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1505_feature_ios-pen-assistant-one-place.md"
    kind: "followup"
tags:
  - "assistant"
  - "ux"
  - "mac"
  - "ios"
  - "feedback"
  - "mcp-tool"
---
[x] 비서가 도는 동안의 잉크 — 획·단계의 말·숨 쉬는 테두리 (맥 상자·폰 펜)

사용자: 「'검색해줘, 찾아줘' 등 AI 를 쓰고 있다면 AI 가 실행되고 있구나를 예술적으로 표현해줘. 지금은 기다리는데 아무것도 안 뜨다가 갑자기 팍 하고 뜨는 느낌」. 작은 바퀴 + 「읽는 중」 한 줄이 전부였고, 그 사이의 일(검색 → 근거 도착 → 모델 로딩 몇 초 → 글자 생성)은 화면에 없었다.

## 추가 기능

- **단계는 실제 사건이다** (`AssistantModel.Stage`): `searching`(뒤지는 중) → `found(n)`(근거 도착) → `waking`(모델 올리는 중 — 새 `AssistantEvent.preparing`) → `writing(tokens)`(글자 조각마다). 지어낸 진행률은 없다. `stageLabel` 이 일마다 제 말을 한다 — 「메모를 뒤지는 중」「6장 골라 읽는 중」「6장 골랐어요 · 비서를 깨우는 중」「답을 적는 중」, 웹은 「웹에서 찾는 중」「5줄 골라 읽는 중」, 다듬기·시키기·브리핑도 각각.
- `Coordinator` 가 모든 일의 `textDelta` 를 흘린다 — 다듬기 글은 그대로, JSON 조각은 화면이 **세기만** 한다(내용은 안 보임). 취소 시험은 `[loading, evidence, preparing]` 셋으로.
- **`ThinkingInk`** (LazyMemoAssistantUI, 맥·폰 공용, 색은 `ThinkingInkStyle` 로 받음): ① `InkStroke` — 펜이 긋는 짧은 물결(`WaveShape`, 자로 잰 사인파가 아닌 조금 기운 것). 왼쪽에서 그어 오른쪽으로 빠져나가고 꼬리가 마르듯 지워진 뒤 다시 시작(두 토막이 동시에 안 보이게), 머리에 펜촉 방울. 스스로 흐르되 조각 하나마다 1/12 획만큼 더 나아간다 — 움직임이 실제 생성에 묶여 있다. ② `ShimmerText` — 흐린 잉크 위로 진한 잉크 띠가 지나간다(애플 인텔리전스의 생각하는 글자). ③ `ThinkingGlow` — 테두리가 강조색으로 2초 주기로 숨 쉰다(Siri 가장자리 빛의 자리, 훨씬 옅게 — 재질은 종이 하나). 시계는 테두리에만 걸어 상자 내용이 매 프레임 다시 그려지지 않게. 「동작 줄이기」면 셋 다 멈춰 선다.
- 맥 상자: 힌트 줄 오른쪽의 바퀴 자리에 획+말, 상자 테두리가 숨 쉼. 폰 펜: 「읽는 중」 단추 안에 획+말, 글 칸 유리 테두리가 숨 쉼.
- 렌더 장면 `capture-thinking` 추가.

## 동작 흐름

「엄마 선물 뭐 사기로 했지?」 ⌘↵ → 테두리가 숨 쉬기 시작, 「메모를 뒤지는 중」 → 근거 6장 → 「6장 골라 읽는 중」 → (콜드면) 「6장 골랐어요 · 비서를 깨우는 중」 → 첫 조각부터 「답을 적는 중」, 조각마다 획이 앞으로 → 답이 서면 셋 다 물러난다.

## 검증

- Swift 시험 전체 초록(Assistant 36 포함). 맥 `render-ui.sh` → `capture-thinking.png` 라이트·다크에서 획·말·테두리 확인(확인 뒤 PNG 삭제).
- 폰 시뮬레이터 임시 XCUITest 로 「웹에서 서울 내일 날씨 검색해줘」 → 찾는 동안 스크린샷: 펜 글 칸 테두리 강조색, 단추에 획 + 「웹에서 찾는 중」 확인(시험·PNG 삭제). 두 번째 시도는 DDG 가 빨라 잡지 못했다 — 접속 시간에 걸린 시험이라 남기지 않는다.
- 실모델(콜드 로딩 몇 초)에서 「비서를 깨우는 중」과 조각마다 나아가는 획은 실기기 손검증으로 남긴다.

## 메모

- `textDelta` 를 모든 일에 흘리게 되어 `AssistantModel` 이외의 소비자가 생기면 JSON 조각임을 알아야 한다 — Contracts 의 주석에 적었다.
- 「비서를 깨우는 중」은 엔진이 이미 올라와 있으면 한 프레임만 스친다 — 라벨 전환은 0.25초 페이드라 눈에 걸리지 않는다.