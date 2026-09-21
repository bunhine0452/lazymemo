---
schema_version: 1
type: bug
slug: "capture-parks-instead-of-closing-with-answer"
status: done
difficulty: medium
created_at: "2026-09-21T19:55:09+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureDismissTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureStateTests.swift"
    op: update
  - path: "scripts/verify-capture-dismiss.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260918/Bugs/2335_bug_capture-web-answer-wont-dismiss.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
tags:
  - "quick-capture"
  - "assistant"
  - "web-search"
  - "ux"
  - "mac"
  - "focus"
  - "mcp-tool"
---
[x] 「달러 환율 얼마야?」를 묻고 다른 곳을 누르면 상자가 사라지던 것 — 들고 있는 것이 있으면 바깥 클릭에 비켜 설 뿐 닫히지 않는다

사용자: 「mac 에서 사용자가 "달러 환율 얼마야?" 또는 간단한 질문들을 치고 다른 곳을 클릭하거나 이동하면 화면이 사라지는데 이 UX를 제대로 고쳐줘」.

## 발생 원인

빠른 입력 상자는 바깥 클릭 감시 둘(다른 앱 = 전역, 우리 창 = 지역)이 걸리면 **무조건** `close(returningFocus: false)` 했다. `close` 는 9/18 이후 비서를 `reset()` 하므로(다음 열림에 지난 답이 서 있지 않게), 웹을 읽는 중이면 그 일이 **취소**되고 답이 서 있으면 **버려졌다**. 적던 글은 상자가 기억하지만 답·결과·되물음은 기억할 길이 없었다. 「달러 환율 얼마야?」는 웹 검색 + 세 쪽 읽기 + 모델 생성이라 몇 초가 걸리고, 그 사이 브라우저를 한 번 누르는 것은 게으른 사람의 당연한 손이다 — 답이 올 때까지 상자만 바라보고 있어야 했다. Space 이동·⌘Tab 은 닫지 않는다(`hidesOnDeactivate=false`, `canJoinAllSpaces`) — 사라지게 하는 것은 클릭이었다.

## 해결 방법

**바깥 클릭은 들고 있는 것이 없을 때만 치운다.**

- `QuickCaptureModel.holdsWork` — 읽는 중(`assistant.isBusy`) · 답·결과·권유가 서 있음(`isStanding`) · 시각·가는 길을 되묻는 중(`isAsking`, `planner.isBusy`). `parked` — 바깥을 눌러 손을 내준 채 남은 상태.
- `QuickCaptureController.outsideClicked` — 상자 안 클릭은 `parked` 를 푼다. 바깥 클릭은 `dismissesCapture`(순수 판정, `holding:` 인자 추가)가 참이고 `holdsWork` 면 **비켜 선다**(`parked = true`, 상자는 그 자리에, 손은 누른 곳으로), 아니면 전과 같이 `close`. 감시는 상자가 닫힐 때까지 그대로라 비켜 선 뒤의 안쪽 클릭·바깥 클릭도 이 길을 탄다.
- `toggle()` — 비켜 선 상자(`isParked = isOpen && model.parked`)에 단축키·메뉴바 아이콘·메뉴 「빠른 입력」은 닫기가 아니라 **돌아오기**(`refocus`: 활성화·키·커서). 키 윈도 여부는 보지 않는다 — 활성화가 비동기라 그 값은 순간마다 다르고, 사람이 한 일(바깥 클릭)만이 믿을 수 있는 기준이다. 닫는 길은 그 안에서 esc(한 겹씩)·× 로 — 사람이 한 일로만.
- 힌트 줄 — 비켜 선 동안 「여기 남아 있어요 · 상자를 누르거나 단축키로 돌아오기 · × 닫기」(en 표 추가). `show()` 는 `parked` 를 푼다.
- 문서: DESIGN §8 에 규칙 한 줄, README 「쓰는 법」에 「상자 바깥을 누르기」 행.

## 검증

- `swift test --filter "CaptureDismissTests|CaptureStateTests"` 10건 초록 — 새 시험 둘: `holding: true` 면 다른 앱이든 우리 창이든 치우지 않는다; 답을 세우면 `holdsWork`, esc 로 벗기면 아니다.
- `scripts/verify-capture-dismiss.sh` — 진단(`dismissReach`)에 둘째 판을 더했다: 비서에 웹 답을 세우고 우리 창을 누른 뒤 `열림=true 비켜섬=true`, `toggle()` 로 `단축키로돌아옴=true`(답이 그대로 선 채). 「감시=2 열림=true 안쪽클릭뒤열림=true 바깥클릭뒤열림=false 답들고바깥클릭뒤열림=true 비켜섬=true 단축키로돌아옴=true」 ✓. 비서가 없는 빌드는 건너뛴다.
- `scripts/verify-capture.sh` ✓ (첫 번은 Finder 활성화 타이밍으로 빨갰다 — 다시 돌리니 초록, 코드와 무관).
- 사람이 볼 것: 실제 브라우저를 눌렀을 때 상자가 그 위에 남아 보이는지(떠 있는 창), 답이 온 뒤 단축키로 돌아왔을 때 커서와 답.

## 메모

- 되묻는 중(「어디서 출발하시나요?」·시각)에도 같은 규칙이다 — 주소를 복사하러 브라우저에 갔다 와도 질문이 남는다. 그때 닫으면 전과 같이 「됐어」·「시각 없이」.
- 비켜 선 상자는 `.floating` 이라 다른 앱 위에 계속 보인다 — 그것이 뜻이다(답이 오면 거기 있다). 거슬리면 × 한 번.