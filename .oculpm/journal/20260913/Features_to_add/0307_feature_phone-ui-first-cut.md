---
schema_version: 1
type: feature
slug: "phone-ui-first-cut"
status: done
difficulty: high
created_at: "2026-09-13T03:07:16+09:00"
session_id: "20260913-002"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/PenModel.swift"
    op: create
  - path: "ios/LazyMemo/PenBar.swift"
    op: create
  - path: "ios/LazyMemo/StackView.swift"
    op: create
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: create
  - path: "ios/LazyMemo/FolderModel.swift"
    op: create
  - path: "ios/LazyMemo/Undo.swift"
    op: create
  - path: "ios/LazyMemo/HomeView.swift"
    op: create
  - path: "ios/LazyMemo/RootView.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: create
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: create
  - path: "ios/LazyMemo/DateSheet.swift"
    op: create
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: create
  - path: "ios/LazyMemo/CalendarView.swift"
    op: create
  - path: "ios/LazyMemo/TrashView.swift"
    op: create
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/CapturePrompt.swift"
    op: rename
  - path: "Sources/LazyMemoCore/Model/MemoTimeLabel.swift"
    op: update
related:
  - ref: "20260913/Chores/0245_chore_mobile-design-spec.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0246_feature_share-extension-and-app-group.md"
    kind: "followup"
tags:
  - "ios"
  - "ui"
  - "swiftui"
  - "uitest"
  - "mcp-tool"
---
[x] 폰 화면 1차 — 펜·무더기·편집·달력·휴지통이 설계 §3~§7 대로 서고 XCUITest 다섯 벌이 손을 대신한다

## 추가 기능

`docs/MOBILE_DESIGN.md` 를 그대로 옮긴 첫 판. 사용자가 확정한 셋(펜 위로 쌓기 · 칩을 눌러 읽지 않기 · 편집 열 때 키보드 안 올림)이 들어 있다.

- **펜** (`PenModel`·`PenBar`) — 켜면 포커스. `NoteReader` 로 읽은 것을 칩(날짜·되풀이·장소)으로 보이고 누르면 끈다(글은 그대로). 단추는 「메모 남기기 / 달력에 남기기」. 치면 무더기가 걸러진다 — `MemoFilter.read` + 첫소리는 메모리, 아니면 인덱스 (`QuickCaptureModel.find` 와 같은 두 걸음). 초안은 `CaptureDraftStore`. 안내 문구는 `CapturePrompt` — 맥에서 Core 로 올렸다.
- **무더기** (`StackView`·`MemoRowView`·`FolderModel`) — 첫째가 펜에 가장 가깝다(고정 → 최근순). **목록을 세로로 뒤집고 줄마다 도로 뒤집어** 몇 장 안 될 때도 줄이 펜 바로 위에 앉는다; 안전 영역은 `GeometryReader` 로 읽어 손으로 준다. 폴더 띠는 머리에 고정, 고른 폴더에서 적으면 그 폴더로. 왼쪽 밀기 지우기(끝까지 밀면 바로), 오른쪽 밀기 고정, 길게 눌러 메뉴(미리보기는 바로 선 종이). 줄은 `MemoAge.presence` 로 바랜다. 줄에 › 를 달지 않으려고 `NavigationLink` 대신 `Button` + `navigationDestination(item:)`.
- **되돌리기 띠** (`UndoModel`) — 펜 바로 위 8초. 「지웠습니다」·「N월 N일로 옮겼습니다」·「날짜를 뗐습니다」.
- **편집** (`MemoEditorView`·`PaperTextView`·`DateSheet`) — 화면 전체가 종이 + 꼬리 한 줄(날짜·장소·폴더·색·고정 | 지우기). `UITextView` 를 감싼 이유는 `MemoTextSync` 세 규칙(조합 중 되밀지 않기·같으면 대입 않기·커서 되돌리기) 때문. 600ms 디바운스, 뒤로 갈 때 즉시. 날짜 시트는 같은 달 격자 + 「없음·09:00·14:00·직접…」 + 「날짜 떼기」.
- **달력** (`CalendarView`·`MonthGridView`) — 위에 달(오늘은 포레스트 원, 고른 날 밑줄, 일정은 번진 잉크), 아래에 그 날(`DayAgenda.rows`). 오른쪽 밀기 미루기(`postponed(notBefore:)`), 왼쪽 날짜 떼기·지우기, 길게 눌러 「다른 날로」는 **들고 기다리기**(격자가 「놓을 날을 누르세요」). 「이 날에 적기」는 펜에 날짜를 물리고 올린다(`QuickSchedule.make`).
- **휴지통** (`TrashView`) — 되돌리기 단추·밀기, 「N일 전 지움」(`MemoTimeLabel.elapsed` 를 public 으로), 비우기 없음.
- **⋯ 메뉴** — 저장 자리 한 줄 · 휴지통 (N) · 치워 둔 N장 도로 꺼내기.

## 동작 흐름

- **`tabViewBottomAccessory` 대신 `safeAreaInset(edge: .bottom)`.** 액세서리는 탭바가 접힐 때 한 줄로 눌리고 키보드 위로 오르는지 확인할 수 없었다. 펜은 하나여야 해서 **고른 탭에만** 앉힌다 — 두 탭에 다 두면 보이지 않는 쪽도 살아 있어 접근성 요소가 둘이 된다(시험이 이것을 잡았다).
- **뒤집힌 목록에 유리 바의 가장자리 번짐이 잘못 얹혀** 줄 전체가 바래 보이다가(soft) 아예 안 보였다(hard). `scrollEdgeEffectHidden(true, for: .all)` 로 껐다.
- 시험 픽스처의 ULID 는 **시각과 폴더가 맞아야** 한다 — 앱이 id 의 시각으로 자리를 정하므로, 2025년 시각의 id 를 2026/09 에 두면 고친 뒤 파일이 다른 달로 간다. 시험이 Crockford 로 직접 만든다.
- 되돌리기 띠를 `accessibilityElement(children: .combine)` 으로 묶었더니 단추가 아니라 띠 가운데를 눌렀다. 풀었다.

## 검증

- `xcodebuild test -scheme LazyMemo-iOS` → **5 tests passed**: 적으면 파일·칩·「달력에 남기기」·줄, 첫소리(ㅊㄱ)로 거르기, 밀어 지우기 + 되돌리기, 편집이 파일을 바꿈, 달력 15일 칸에 둘이 서고 펜에 날짜가 물림.
- 시뮬레이터 스크린샷으로 배치를 눈으로 봤다(폴더 띠·줄·시각·고정이 펜 옆·로컬 띠·펜 줄).
- **사용자가 「애플의 디자인 철학을 샅샅이 공부하고 디자인을 다시해」라고 했다** — 이 판은 1차이고, 재설계가 오면 화면이 바뀐다. 배선(모델·저장·시험)은 그대로 쓴다.