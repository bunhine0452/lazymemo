---
schema_version: 1
type: feature
slug: "ios-pen-assistant-merged"
status: done
difficulty: medium
created_at: "2026-09-15T23:15:09+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
tags:
  - "ios"
  - "assistant"
  - "ux"
  - "mcp-tool"
---
[x] 폰의 펜이 비서를 겸한다

## 추가 기능

사용자: 「폰 입력에도 똑같이 융합해줘」. 맥의 빠른 입력 규칙(quick-capture-assistant D1–D14)을 펜에 그대로 얹었다.

- `PenModel.leave()` 갈래: 되물음의 답(`AssistantIntent.complete`) → 시키는 말(`assistant.command`, 대상 없으면 비서가 되묻고 목록이 후보) → 물음(`assistant.ask`) → 약속인데 시각 없음(`AssistantIntent.compose` 가 ask+draft 를 주면 `pending`) → 기존 남기기. 라벨은 답하기·시키기·메모에게 묻기·달력에 남기기·메모 남기기. `assistant.onSettled` → `reflectAssistant` 가 목록을 근거·관련·후보로 갈아 끼우고(`shown`), 글을 고치면 `assistant.reset()`.
- `PenBar`: 칩 줄 자리에 되묻기 블록(초안 요약·질문·선택 칩 12시/점심/저녁 7시/시각 없이), 자리표 「12시야」, ⊗ 는 「시각 없이」(초안을 날짜만으로 적는다), 읽는 중이면 단추가 「읽는 중」(누르면 그만).
- `StackView`: 답 카드(문장+원문 인용)·결과 줄+되돌리기·휴지통 되묻기·「모델을 받으면 답합니다 · 받기」+진행이 목록 위에. 머리글 「근거 N장」·「관련 메모」·「어느 메모? 누르면 그 메모에게 합니다」. 후보 줄은 열지 않고 `pen.pick`. 툴바 ✦ 와 `AssistantView` 시트 삭제. 열린 메모에게 시키기는 편집 화면의 ✦ 시트가 그대로 맡는다.
- `HomeView` 가 `pen.assistant = session.assistant`. 영어 표 추가. MOBILE_DESIGN §3 에 한 절.

## 동작 흐름

펜에 「9월 30일에 @홍대입구 친구랑 밥 먹기로 했어」 → 「달력에 남기기」 → 펜이 남아 「약속 시간이 언제인가요?」 → 「12시야」 또는 칩 → 남기고 목록 맨 위로. 「치과 언제였지?」 → 「메모에게 묻기」 → 읽는 중 → 답 카드 + 근거 목록. 「금요일 10시에 다시 알려줘」 → 「시키기」 → 후보 목록 → 줄을 누르면 그 메모에게 → 결과 줄 + 되돌리기.

## 검증

- `xcodebuild -scheme LazyMemo-iOS -destination generic/platform=iOS` BUILD SUCCEEDED. 시뮬레이터는 Xcode 27 의 CoreSimulator 구판 때문에 못 띄워 화면 손검증은 못 했다 — 사용자가 TestFlight 에서 봐야 한다.
- 커밋 `c28d54b`, 푸시. TestFlight 는 아직.