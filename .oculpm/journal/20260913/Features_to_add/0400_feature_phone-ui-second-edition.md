---
schema_version: 1
type: feature
slug: "phone-ui-second-edition"
status: done
difficulty: high
created_at: "2026-09-13T04:00:31+09:00"
session_id: "20260913-002"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "ios/LazyMemo/Undo.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/TrashView.swift"
    op: update
  - path: "ios/LazyMemo/Theme.swift"
    op: update
  - path: "ios/LazyMemo/HereFix.swift"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/ShotTests.swift"
    op: create
  - path: "ios/scripts/uitest.sh"
    op: update
related:
  - ref: "20260913/Chores/0335_chore_apple-principles-redesign.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0307_feature_phone-ui-first-cut.md"
    kind: "followup"
tags:
  - "ios"
  - "ui"
  - "swiftui"
  - "design"
  - "uitest"
  - "mcp-tool"
---
[x] 폰 화면 2판 — 층을 돌려놓고(유리 펜·종이 목록), 되돌리기는 시스템, 꼬리는 툴바, 옮기기는 끌기

## 추가 기능

`docs/MOBILE_DESIGN.md` 2판(애플 원칙 노트에 비추어 다시 쓴 것)을 코드로 옮겼다. §14 의 바뀐 결정 표를 그대로 따랐다.

- **목록은 위에서 아래로** — 뒤집기(`scaleEffect`·`GeometryReader` 인셋·`scrollEdgeEffectHidden`) 전부 제거, 보통 `List`. 고정 → 최근순은 `store.active` 차례 그대로. 새로 남긴 줄은 맨 위에 생기고 `ScrollViewReader` 가 그리로 가며 1.4초 밝아진다 (`Reveal`). 찾는 중에는 「N장 중 M장 / N장 중 없다」 범위 줄.
- **큰 제목 「메모」 + 부제**(`navigationSubtitle`: 「iCloud · N장」 / 「이 기기에만 · iCloud 꺼짐」). 툴바는 휴지통 단추 + More(치워 둔 N장 · iCloud 설정 열기 · 새 폴더). 상시 띠는 없다.
- **펜은 유리** — 시스템 `LocationButton` · 유리 캡슐 글 칸(`.body`, ⊗ 지우기) · `glassProminent` 「남기기」(이 화면의 유일한 틴트). 종이색·윗변 선 없음. 칩은 켜짐(바탕+글)/꺼짐(테두리)이 눌리게 생겼다.
- **되돌리기는 시스템** — 띠 삭제. `Undo.register` 가 `UndoManager` 에 이름을 단다(「지우기」·「N월 N일로 옮기기」·「날짜 떼기」·「미루기」). 되돌린 줄은 `Reveal` 로 보인다. 휴지통은 툴바에서 한 번에.
- **편집 꼬리는 표준 바닥 툴바** — `ToolbarItemGroup(.bottomBar)` 셋을 `ToolbarSpacer` 로 나눔(무엇: 날짜·장소·폴더 / 생김새: 색 메뉴(Picker)·고정 / 끝: 지우기 destructive). 탭바·펜은 숨는다.
- **날짜 시트** — medium·large detent + 그래버, 「완료」만, 「날짜 떼기」는 격자 아래 destructive 단추, 유리 시트 그대로.
- **달력 옮기기는 시스템 끌기** — 줄 `draggable(id)`, 칸 `dropDestination`. 「들고 기다리기」 모드 삭제. 컨텍스트 메뉴의 「다른 날로」는 날짜 시트. 목록의 「달력에 놓기」도 시트.
- **색·대비** — `Paper.fadedInk` 삭제, 보조 글은 `.secondary`. 바램은 제목 색으로만(`MemoAge` fresh·recent 는 잉크, 그 뒤는 `.secondary`), 대비 높임이면 끔. `Paper.surface`·`ink` 에 라이트·다크·대비 높임 세 벌. 큰 글자(accessibility 크기)에서 줄이 세로로 쌓인다. 밀기 동작은 `accessibilityActions` 에도.
- **켤 때의 포커스는 한 번뿐** — 메모를 읽고 돌아올 때마다 키보드가 튀어 오르던 것을 막았다.

## 동작 흐름

- **`tabViewBottomAccessory` 는 키보드 위로 오르지 않는다** — 설계 §15.1 이 확신 없다고 적은 자리를 시뮬레이터에서 봤다: 키보드가 탭바와 함께 펜을 덮었다. 설계가 적어 둔 대로 물러났다 — `safeAreaInset(edge: .bottom)` 에 같은 유리 펜, 고른 탭에만. 접힘(`.inline` 알약)은 코드에 남겨 두되 지금은 닿지 않는다.
- **폴더 띠를 `safeAreaInset(edge: .top)` 에 두면 큰 제목이 그려지지 않았다** (자리는 비고 글자가 없음). 목록의 첫 줄로 옮기니 제목·부제가 나왔다.
- 켜면 키보드가 탭바를 덮는다 — Messages 와 같다. 목록을 쓸어 내리면 내려가야 하므로 `scrollDismissesKeyboard(.immediately)` (짧은 목록은 `.interactively` 로 안 내려간다). 시험은 느린 끌기로 내린다 — 플릭은 시뮬레이터가 스크롤로 안 본다.
- `LocationButton` 은 접근성 트리에 `Button` 이 아니라 `Other` 로 오지만 식별자·이름은 받는다.
- 시뮬레이터의 하드웨어 키보드 연결을 껐다(`ConnectHardwareKeyboard false`) — 그래야 소프트웨어 키보드가 떠서 위의 두 문제가 보인다.
- `ShotTests` — 맥의 `render-ui.sh` 자리. `./ios/scripts/uitest.sh --shots` 로만 돌고(`TEST_RUNNER_LAZYMEMO_SHOTS`), 펜·목록·편집·날짜 시트·달력을 /tmp 에 찍는다. `LAZYMEMO_DARK=1` 이면 다크.

## 검증

- `./ios/scripts/uitest.sh` → **6 tests passed** (적으면 파일·칩·부제, 첫소리 거르기 + 범위 줄 + ⊗, 밀어 지우고 휴지통에서 되돌리기, 편집이 파일을 바꿈, 달력 15일 + 펜 칩, 위치 단추 → 칩).
- `--shots` 로 라이트·다크 다섯 화면을 눈으로 봤다 — 큰 제목·부제·칩·유리 펜·바닥 툴바·시트 detent·격자의 번진 잉크.
- 흔들기 되돌리기는 시뮬레이터에서 못 눌러 봤다(실기기). **펜에 포커스가 있으면 흔들기의 첫 응답자가 글 칸이라 우리 `UndoManager` 에 안 닿는다** — 휴지통 단추가 그 틈을 메운다. 설계 §15.2 에 적힌 대로 실기기에서 걸리면 편집 화면에 시스템 Undo 툴바 항목.