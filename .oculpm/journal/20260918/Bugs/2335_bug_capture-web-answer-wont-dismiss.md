---
schema_version: 1
type: bug
slug: "capture-web-answer-wont-dismiss"
status: done
difficulty: medium
created_at: "2026-09-18T23:35:36+09:00"
session_id: "20260918-004"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureStateTests.swift"
    op: create
related:
  - ref: "20260917/Features_to_add/2002_feature_web-answer-follow-ups-results-list.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
tags:
  - "quick-capture"
  - "assistant"
  - "web-search"
  - "ux"
  - "mac"
  - "mcp-tool"
---
[x] 「정리하기」를 누른 뒤에도 검색 결과가 안 사라지던 것 — 끝난 카드는 물러나고, esc 는 한 겹씩 벗긴다

## 발생 원인

사용자: 「맥에서 다이어트 하는법 검색해줘 하고 결과를 받고 정리하기 버튼 누르고 난 뒤 검색 결과가 esc 눌러도 사라지지 않아서 이 결과를 사라지게 하는 방법이 필요할것같고 … 추가로 이런 비슷한 아이러니들을 찾고 고쳐줘」.

**치우는 길이 세 곳에서 동시에 막혀 있었다.**

1. `AssistantModel.settle` 은 답을 일부러 남겼다 — 어제(09-17) 「웹의 답 뒤 남기기·정리·붙이기」를 붙이며 「다음 말이 그 답에 대한 것일 수 있다」를 이유로 `answer`·`evidence`·`webQuestion` 을 지키게 했다. 그런데 그 이유는 **다음 손짓을 하기 전**까지만 참이다. 남기기가 끝난 뒤의 카드는 할 일이 없는 화면이다.
2. `QuickCaptureView` 의 esc 는 「읽는 중이면 그만, 아니면 상자 닫기」 둘뿐이었다. 답이 서 있어도 esc 는 상자만 닫았다 — 비서는 그대로 서 있는 채로.
3. `QuickCaptureController.close` 는 비서를 건드리지 않았다. 그래서 esc 로 닫고 다시 열면 그 카드가 **도로** 서 있었다. 결국 결과를 없애는 유일한 길은 「새 글을 치는 것」이었는데, 그것마저 웹의 답일 때는 `keepsWeb` 이 막고 있었다 (`QuickCaptureModel.query` didSet).

## 해결 방법

**끝난 것은 물러나고, esc 는 서랍과 같이 한 겹씩 벗긴다** (설계문서 §16.10).

- `AssistantModel.settle` — 적히고 **나서** 웹의 답을 내린다(`dismissWebAnswer`: answer·evidence·webQuestion·offersWeb·pendingAppend). 남는 것은 「메모로 남겼습니다 · 되돌리기」 한 줄이고 되돌리기는 그대로 산다. 못 적었으면(applyError) 답은 그대로 둔다 — 다시 눌러 볼 것이 없으면 답을 잃은 것이다. 폰 펜도 같은 모델을 쓰므로 그대로 따라온다.
- `AssistantModel.isStanding` — 답·제안·결과 줄·웹 권유·실패·붙일 메모 고르기 중 하나라도 서 있는가. esc(맥)와 ⊗(폰)가 「벗길 겹이 있는지」를 묻는 한 자리.
- `QuickCaptureModel.dismissAssistantResult()` — 서 있으면 `reset()` 하고 목록을 평소로 되돌린다(`refreshListing`). **친 글은 그대로 남는다.** 시각·가는 길의 되물음은 제 규칙(D12 「시각 없이 남기기」)이 있어 가로채지 않는다.
- `QuickCaptureView` — esc 는 이제 세 겹: 읽는 중 → 그만 · 답·결과 → 치우기 · 그 외 → 닫기. 힌트 줄도 그 자리에서 「esc 결과 치우기」로 바뀐다 (en 표에 두 열쇠 추가).
- `QuickCaptureController.close` — 어떤 길로 닫히든(esc·바깥 클릭·단축키 토글·⌘⏎) 비서를 `reset()` 한다. 읽던 중이면 reset 이 먼저 cancel 한다.

**함께 찾은 아이러니** — `applyError` 가 글을 고쳐도 안 물러나던 것(didSet 조건에 추가), 되물음의 답(`accept`)이 `webQuestion`·`offersWeb` 를 들고 있어 나중에 **아무도 안 한 검색**을 부를 수 있던 것, `reset()` 이 `lastCommand`·`task` 를 안 놓아 다음에 고른 후보가 아까 한 말을 다시 하던 것. 붙일 메모 고르기(`pendingAppend`)·후보 목록은 `isStanding` 에 들어가 이제 esc 한 번에 풀린다.

## 검증

- `swift build` 초록(기존 CLGeocoder 경고만). `./scripts/test.sh` 전체 1057건 초록, 새 `CaptureStateTests` 4건 포함 — 남기기 뒤 답·카드·follow-up 이 사라지고 결과 줄만 남는지, esc 가 답을 치우고 친 글은 남기는지, 벗길 것이 없거나 되물음 중이면 안 가로채는지, 닫으면 다음 열림에 지난 답이 없는지.
- `scripts/verify-capture.sh` → 「✓ 다른 앱이 앞에 있어도 빠른 입력 상자가 화면에 올라왔습니다」, `scripts/verify-capture-dismiss.sh` → 「감시=2 열림=true 안쪽클릭뒤열림=true 바깥클릭뒤열림=false ✓」. 사용자의 /Applications 판(pid 12634)은 건드리지 않았다 — 스크립트는 `.build` 의 이진과 임시 vault 로 돈다.
- 새 열쇠 둘은 en.lproj 에 바이트 그대로 있다(코드의 `L("…")` 49개 중 빠짐 없음). `check-l10n.sh` 전체는 안 돌렸다 — 그 스크립트가 `Sources/**` 를 전부 `touch` 해서 공유 `.build` 를 쓰는 다른 세션의 빌드를 통째로 다시 짓게 만든다.

## 메모

- 실모델의 「정리해서 남기기」는 이번에도 손검증 전이다(모델 다운로드 없음). `tidyAndKeep` 도 끝에서 같은 `settle` 을 지나므로 길은 하나다.
- **폰(PenModel/PenBar)은 읽기만 했다.** 남기기 뒤 카드가 물러나는 것은 공용 모델이라 그대로 따라오지만, 두 줄이 더 필요하다: (1) `finishLeaving` 이 `assistant?.reset()` 을 안 해서 새 메모를 남겨도 웹 카드가 선다(맥은 `commit` 의 `.create` 에서 지운다), (2) 펜의 ⊗ 는 `text` 가 비면 아예 안 떠서 **빈 펜에 선 카드를 치울 손짓이 없다** — 조건에 `assistant?.isStanding == true` 를 더하고 그 자리에서 `assistant?.reset()` 을 부르면 맥의 esc 와 같은 한 겹이 된다. 겸사겸사 `text` didSet 의 물러남 조건에도 `applyError` 가 빠져 있다.