---
schema_version: 1
type: feature
slug: "ios-pen-assistant-one-place"
status: done
difficulty: medium
created_at: "2026-09-16T15:05:06+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
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
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: delete
  - path: "Sources/LazyMemoAssistantUI/ModelPanel.swift"
    op: delete
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260915/Features_to_add/2315_feature_ios-pen-assistant-merged.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
tags:
  - "ios"
  - "assistant"
  - "ux"
  - "mcp-tool"
---
[x] 폰의 비서 자리를 펜 하나로

## 추가 기능

사용자: 「모바일 UI 도 mac 처럼 바로 AI와 융합된 형태로 바꿔줘」. 어제 c28d54b 가 펜에 묻기·시키기를 얹었지만 TestFlight(22:48, b3cc4e7)에는 안 실렸고, 편집 화면에는 옛 `AssistantView` 시트(보내기·오늘·ModelPanel)가 남아 있었다. 맥의 상자와 남은 차이를 전부 없앴다.

- **편집 화면 ✦ → 펜.** 시트 대신 `dismiss()` 하고 `onDisappear` 에서 `pen.adopt(target:)`. 펜 위에 「열린 메모 · 치과 예약 ×」 칩(D10), 자리표 「내일로 미뤄줘」, 묻는 말이 아니면 동사가 없어도 그 메모에게 `command(selected:)`, 묻는 말은 `ask(selected:)`. 답·결과가 오면 칩이 내려간다. 달력 탭에서 왔어도 메모 탭으로 (`HomeView.onChange(of: pen.target)`). 단추는 「시키기」— 맥의 「「제목」에 적용」은 폰 단추에서 두 줄로 꺾였다.
- **치는 동안의 목록.** 묻는 말·시키는 말은 `MemoRanker` 낱말 랭킹(맥 `find` 와 같다); 시키는 말에 걸리는 낱말이 없으면 목록을 비우지 않는다. 여러 낱말 구 검색 실패 시 랭킹으로 한 번 더. 묻거나 시키는 말에는 날짜·자리 칩을 세우지 않는다. 빈 목록 한 줄이 `saying` 에 따라 갈린다 (남기면 새 메모예요 / 물으면 메모를 읽고 답합니다 / 시키면 어느 메모인지 묻습니다).
- **읽는 동안 목록 그대로.** `handOff` 가 펜을 비우되 `found` 를 `shown`(`.reading`) 으로 세워 둔다 — 머리글 「「치과 언제였지?」 · 이 중에서 읽는 중」. 답 카드 첫 줄에 물은 말(`asked`). `cancelReading` 이 내린다.
- **「어느 메모?」에 후보가 비면** 지금 목록이 곧 후보 (`AssistantIntent.asksWhichMemo` 추가) — 줄을 누르면 `pick`. 같은 물음을 알림 줄로 한 번 더 세우지 않는다.
- 답·결과·모델 받기 줄은 「지금」 띠보다 위. 첫 실행 안내 첫 장에 「물으면 답하고, 시키면 합니다」 한 줄. `AssistantView`·`ModelPanel` 삭제(맥·폰 어디서도 안 쓴다 — 「오늘」 브리핑 단추와 모델 지우기 UI 도 함께 사라졌다).

## 동작 흐름

시뮬레이터(iPhone 17, iOS 26.5)에서 임시 XCUITest 로 아홉 장면을 찍어 봤다. 그러다 잡은 것 둘:

1. **비서의 `onSettled` 가 죽은 펜으로 갔다.** `HomeView.init` 이 두 번 돌아(`assistant set on` 로그 두 번) 두 번째 `PenModel` 이 콜백을 가져갔다 — `@State(initialValue:)` 의 버려진 인스턴스. 그래서 답이 와도 목록이 안 바뀌었다 (c28d54b 는 시뮬레이터를 못 띄워 이걸 못 봤다). `pen.assistant = session.assistant` 를 `onAppear` 로 옮겼다.
2. **편집 화면에 다녀온 뒤 `@FocusState` 는 켜진 채, 키보드는 내려가 있다** — 같은 값을 다시 넣어도 안 오른다. `PenBar` 가 껐다 50ms 뒤 켠다.

## 검증

- `swift build --product LazyMemo` 성공(맥, `AssistantView`·`ModelPanel` 삭제 뒤). `xcodebuild -scheme LazyMemo-iOS` 시뮬레이터 빌드 성공.
- 임시 UI 시험으로 묻기(모델 없음 → 받기 줄)·시키기(어느 메모? → 줄 누르면 적용 → 결과 줄+되돌리기)·편집 ✦ → 칩 → 시키기 → 결과 줄까지 화면으로 확인. 시뮬레이터는 프로그램 포커스에 소프트 키보드를 안 올린다(켤 때의 포커스도 같다 — 캐럿만 선다) — ✦ 뒤 키보드가 오르는지는 실기기에서 봐야 한다.
- `SmokeTests` 전체 실행: `testSeenPutsTheCardDownIntoTheRest`·`testTypingFiltersTheStack` 둘이 실패하나 씨앗 날짜(09-15)가 오늘(09-16)과 어긋나 「지금」 띠에 오르는 것 때문 — 이 변경 밖(다른 세션이 어제 손대던 시험). HEAD 는 다른 세션의 미커밋 Core 변경 없이는 안 빌드돼 대조 실행은 못 했다.