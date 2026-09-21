---
schema_version: 1
type: feature
slug: "capture-always-saves-followups-optional"
status: done
difficulty: high
created_at: "2026-09-22T02:30:19+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureAssistTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureStateTests.swift"
    op: update
related:
  - ref: "20260922/Features_to_add/0141_feature_draft-trouble-and-reservation-receipt.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
tags:
  - "capture"
  - "pen"
  - "assistant"
  - "route"
  - "first-run"
  - "handoff-bundle-3"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 입력과 첫 경험을 단순하게 — 기본 확정은 적기, 비서는 ⌥⌘⏎/✦ 로만, 길찾기·시각은 결과 카드의 선택 행동, 첫 실행은 안내 대신 첫 메모 (묶음 3)

인계서 §5 묶음 3 (`#capture-always-saves` · `#nonblocking-followups` · `#first-real-note`). 기존 quick-capture-assistant D5/D9/D10(「모드 없이 글이 무엇인지 앱이 가린다」)을 **의도적으로** 뒤집었다 — 「왜 고객이 이탈할까?」「알림 문구 아이디어」「폴더 구조 초안」이 메모가 되지 않고 비서·되물음으로 갔고, 모델 없는 기계에서는 아무것도 남지 않았다.

## 추가 기능

- **⌘⏎ / 「남기기」는 늘 적는다.** `QuickCaptureModel.commit()`·`PenModel.leave()` 에서 `isQuestion`·`hasCommandVerb`·`wantsWeb` 분기와 `askTime` 되물음을 뺐다. 예외는 사람이 이미 비서와 이야기 중인 것뿐 — 「이 메모에게」로 연 상자(`target`), 웹의 답 뒤의 「메모해」(`webFollowUp`), 못 찾은 뒤의 빈 ⌘⏎(`offersWeb`), 결과 카드에서 직접 연 되물음. ↑↓ 로 고른 줄은 명시적이라 그대로 연다.
- **비서에게는 따로** — 맥 ✦ 단추 + ⌥⌘⏎(`MemoNSTextView.onOptionCommandReturn` → `commitAsk`/`askIntent`), 폰 ✦ 단추(`PenModel.ask`/`askSaying`). 물음이면 메모가 답하고, 동사면 시키고, 「웹에서 …」면 웹. 비서가 없으면 단추도 없다.
- **결과 카드** (`QuickCaptureModel.Left` / `PenModel.Left`) — 적힌 뒤 「적었어요 · 친구랑 밥 · 9월 30일 (수) · 자리 홍대입구」와 권할 것: 날짜만 있는 약속엔 「시각 정하기」, 자리 있는 앞으로 올 약속엔 「가는 길 (찾기)」. 폰은 알림 영수증(묶음 2)도 이 줄에 붙는다. **상자·펜은 비어 다음 글을 받는다** — 첫 글자에 카드는 물러난다. 누르면 그때 되물음이 서고(`offerTime` → `pending` with `memo`, 답은 `.setTime(id, at)` 으로 **그 메모**에 적힌다 / `offerRoute` → `planner.begin`), esc·⊗ 는 새 메모를 만들지 않는다. 약속인데 시각이 없으면 묻지 않고 날짜만으로 적는다(`compose` 의 `.ask` 초안을 그대로 저장).
- 밖에서 온 약속(공유 시트·인텐트·비서의 결과)도 `askRoute` 가 묻는 대신 **권한다** (`offerRoute(for:)`). 권할 것이 없으면 맥 상자는 예전처럼 닫힌다.
- **첫 실행** — 맥은 다섯 단계 창 대신 빠른 입력 상자를 띄우고(`AppDelegate`), 폰은 다섯 장 안내 시트를 띄우지 않는다(`HomeView`). 첫 메모가 적히면 카드에 한 줄만: 맥 「종이가 바탕화면에 섰어요 · 다시 적을 땐 ⌥⌘N · 나머지는 메뉴바 아이콘 → 시작하기 및 사용 안내」(`FirstNote`, defaults), 폰 「다시 찾을 땐 같은 칸에 치세요 · 줄을 밀면 고정·지우기 · 나머지는 더 보기 → 사용법」(`Tutorial.markSeen`, 실행 인자가 덮는 시험을 위해 이번 실행의 표도 든다). 다섯 장/다섯 단계 안내는 메뉴·더 보기에 그대로.

## 동작 흐름

맥: 글 → ⌘⏎ → 적힘 → (권할 것 있으면) 카드 + 빈 상자 / (없으면) 닫힘 → 다음 글은 새 메모. ✦/⌥⌘⏎ → 비서. 카드 「시각 정하기」 → 「약속 시간이 언제인가요?」 + 칩 → 답 → 그 메모에 `at`. 폰: 「남기기」 → 진동 → 결과 줄(영수증·칩) → 「가는 길」 → 「어디서 출발하시나요?」 → 「됐어」/답.

## 검증

- `./scripts/test.sh` 전체 **1,127개 통과** — `CaptureAssistTests` 를 새 계약으로 다시 씀: 30개 회귀 문장(한국어/영어/물음표/명령형/인용문/긴 글) 전부 `.create`/`.compose` 이고 되묻지 않음, 비서 없이도 적힘, `commitAsk` 갈래, 결과 카드의 권함·「시각 정하기」→`.setTime`·「시각 없이」·딴 말은 새 메모, esc 는 새 메모 없음.
- 폰 시뮬레이터(iPhone 17) 스모크 **26개 전부 통과** — `testAppointmentWithMapLinkOffersTheWay`(권함 → 누르면 질문 → 됐어)·`testShareLeftQuestionIsOfferedOnLaunch`·`testFirstLaunchStartsWithThePenAndHintsOnce`(안내 없이 펜 → 첫 메모 → 한 줄 → 둘째 메모엔 없음 → 더 보기의 사용법)를 새 계약으로 고쳐 씀. 찍은 화면(`/tmp/lazymemo-route-question.png`·`first-note.png`)으로 카드·질문·펜 상태 확인.
- 맥 렌더 `capture-left`(결과 카드 + 첫 메모 한 줄 + 「시각 정하기」)·`capture-ask`(「메모 남기기 ⌘↵」 옆 「✦ 묻기 ⌥⌘↵」) 밝은/어두운 판 확인 — 카드의 × 가 상자의 × 와 겹쳐 뺐고, 라벨은 「묻기/웹 찾기/시키기」로 줄였다. 확인 뒤 `build/ui` 삭제.
- 안 한 것: 한글 조합 중 ⌥⌘⏎·실기기 키보드, 맥 실제 앱에서 첫 실행 상자가 뜨는 장면(설정 `greeted` 를 지운 실행은 안 돌림).

## 메모

- `SmokeTests.swift` 는 다른 세션의 미커밋 변경(+46줄)이 있는 파일 — 세 시험 함수만 겨냥해 고쳤다.
- SwiftUI 묶음에 `accessibilityIdentifier` 를 달면 안의 칩이 그 이름을 물려받아 `offer-route` 가 안 잡혔다 — 묶음의 이름표는 뺐다.