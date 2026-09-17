---
schema_version: 1
type: feature
slug: "ios-hide-machine-lines-photo-remove"
status: done
difficulty: high
created_at: "2026-09-17T21:40:14+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MachineLines.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MachineLinesTests.swift"
    op: create
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: update
  - path: "ios/LazyMemo/PhotoCards.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260916/Features_to_add/1912_feature_appointment-transit-route.md"
    kind: "followup"
  - ref: "20260914/Features_to_add/2115_feature_ios-place-cards-map-app-handoff.md"
    kind: "followup"
tags:
  - "ios"
  - "editor"
  - "route"
  - "photo"
  - "ux"
  - "mcp-tool"
---
[x] 폰의 글 칸이 「## 가는 길」 절과 사진 참조를 감춘다 — 카드가 대신 서고, 사진은 카드에서 뗀다

사용자의 폰 화면(2026-09-17): 길 카드 아래에 `## 가는 길 …` 절 전체와 `[map.naver…](…)` 가 날것으로 보였다. 「경로를 만들면 텍스트가 안 보이게」, 「사진만 보이게」. 폰의 글 칸은 마크다운을 꾸미지 않는 맨 `UITextView` 라 기계가 적은 줄이 그대로 섰다 — MOBILE_DESIGN 은 「지우면 사진이 떨어지니 감추지 않는다」고 결정했었는데, 사용자가 본 것은 그 결정의 값이었다.

## 추가 기능

- **Core `MachineLines`** — 감출 구간과 커서 규칙, 순수 함수. 사진 참조는 줄을 혼자 차지하면 줄바꿈까지(안 그러면 사진마다 빈 줄이 남는다), 글 사이의 것은 참조만. 「## 가는 길」 절은 `RouteNote.sectionRange` 그대로. `caret(_:avoiding:in:)` — 참조 안이면 **뒤**로(사이에 글자가 끼면 참조가 깨진다), 절 안·머리·끝이면 절 **앞** 빈 줄로(「## 가는 길」 앞에 글자가 붙으면 제목이 아니게 되어 절 전체가 드러나고 카드가 사라진다). `removingPhoto(_:from:)` — 그 참조의 줄만 뺀 본문.
- **`PaperTextView`** — 글자는 그대로 두고(D4) 그 구간만 0.01pt·투명으로(맥 `MarkdownStyler` 와 같은 수). 글이 바뀔 때마다 바탕부터 다시 깔되 한글 조합 중에는 손대지 않는다. 선택이 바뀔 때마다 `typingAttributes` 를 바탕으로 — 감춘 글자 뒤에서 치면 그 글꼴을 물려받아 친 글자까지 사라지던 것. 커서가 감춘 구간에 들면 `MachineLines.caret` 로 내보낸다. 글자 크기 설정 변경(`UITraitPreferredContentSizeCategory`)에도 다시 깐다.
- **사진 떼기** — 참조가 감춰졌으니 떼는 길은 카드다: 사진 카드를 길게 누르면 「사진 떼기」(파일은 남고 참조만 빠진다 — 휴지통 규칙과 같다).

## 동작 흐름

메모 열기 → `restyle` 로 절·참조가 접힌다(「점심 약속」 한 줄만 보임) → 글 아래 빈 자리를 누르면 커서는 글 끝 = 절 안 → 절 앞 빈 줄로 나온다 → 친 글자는 그 줄에, 파일은 `…\n덧붙임\n## 가는 길\n…` 로 절이 그대로 → 카드가 그대로 선다.

## 검증

- `MachineLinesTests` 7건(구간·커서·떼기). 
- 시뮬레이터 XCUITest 신규 2건 통과: `testMachineLinesAreHiddenAndTypingLandsBeforeTheRoute`(절+사진이 든 메모를 열어 스크린샷으로 「점심 약속」만 보이는 것 확인, 아래를 눌러 「덧붙임」을 치면 파일에서 절 앞에 적히고 절·참조는 그대로), `testRemovingAPhotoFromItsCard`(길게 누르기 → 사진 떼기 → 파일에서 참조가 빠짐). 이웃 시험 `testEditingWritesTheFile`·`testPhotoFromMacShowsOnThePaper`·`testDoneLowersTheKeyboardInTheEditor`·`testAppointmentWithMapLinkAsksWhereToLeaveFrom` 그대로 통과.
- 스크린샷 `/tmp/lazymemo-machine-lines.png`·`-typing.png` 눈으로 확인.

## 메모

- 첫 시도에서 XCUITest 의 `paper.tap()`(칸 한가운데)이 첫 줄에 커서를 놓아 「덧붙임점심 약속」이 됐다 — 글 아래를 누르려면 `coordinate(withNormalizedOffset:)` 로.
- 링크 마크다운 `[이름](주소)` 은 여전히 날것이다 — 폰은 꾸미지 않는다는 원칙 그대로. 제목만 이름으로 줄였다(같은 날 `2138_bug_naver-long-link-name-not-title`).
- 절이 본문의 전부인 메모(있을 수 없는 모양)에서는 커서가 0 으로 가 「##」 앞에 글자가 붙을 수 있다 — 두지 않았다.