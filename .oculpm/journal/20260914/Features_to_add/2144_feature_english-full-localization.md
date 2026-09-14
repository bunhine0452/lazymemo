---
schema_version: 1
type: feature
slug: "english-full-localization"
status: done
difficulty: high
created_at: "2026-09-14T21:44:45+09:00"
session_id: "20260914-005"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "176355c0-cdd8-46c9-b761-50bec054636d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoCore/Words.swift"
    op: create
  - path: "Sources/LazyMemoUI/Words.swift"
    op: create
  - path: "Sources/LazyMemoMCP/Words.swift"
    op: create
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "Sources/LazyMemoMCP/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: create
  - path: "ios/LazyMemoShare/en.lproj/Localizable.strings"
    op: create
  - path: "Resources/en.lproj/InfoPlist.strings"
    op: create
  - path: "Resources/Info.plist"
    op: update
  - path: "ios/Config/Mac-Info.plist"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "scripts/build-app.sh"
    op: update
  - path: "scripts/check-l10n.sh"
    op: create
  - path: "Sources/LazyMemoCore/Model/MemoTimeLabel.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/SurfaceWords.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Recurrence.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MonthGrid.swift"
    op: update
  - path: "Sources/LazyMemoCore/Inbound/MemoFilter.swift"
    op: update
  - path: "Sources/LazyMemoCore/Claude/ClaudeRunner.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeNote.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/DateWordsTests.swift"
    op: create
  - path: "docs/APP_STORE_READINESS.md"
    op: update
related: []
tags:
  - "l10n"
  - "english"
  - "ios"
  - "mac"
  - "mcp"
  - "mcp-tool"
---
[x] 영어 풀 지원 — 맥·아이폰·공유 확장·MCP 의 화면 말 전부가 en.lproj 표를 지난다

## 추가 기능

입력은 이미 네 나라 말을 읽고 있었다(`TimeWords`). 이번 것은 **출력** — 사람에게 보이는 말 590여 줄(맥 UI 338 · Core 82 · MCP 61 · 아이폰 107 · 공유 확장 7)이 영어 표를 지나고, 손으로 이어 붙이던 날짜(「9월 14일」·「2026년 9월」·요일 머리글)는 `DateWords` 가 그 말의 어순으로 짓는다(en 「Sep 14」·「September 2026」·「S M T W T F S」).

- **한국어 원문이 열쇠**. 코드는 한국어 그대로, 영어는 `<모듈>/Resources/en.lproj/Localizable.strings`(+ 복수형 `.stringsdict`). 표에 없으면 원문이 나오므로 한 줄 빠져도 한국어 사용자는 아무것도 잃지 않는다. `ko.lproj` 는 빈 파일 하나 — 단, 같은 한국어가 두 뜻으로 갈리는 자리(「3일 전」= ago/before)만 열쇠를 달리 두고 ko 표가 되돌린다.
- 패키지 모듈은 `L("…")` 하나로 지난다(`Words.swift`, 모듈마다 `.module` 번들). 아이폰 앱은 SwiftUI 리터럴이 스스로 표를 보고, `String` 자리만 `String(localized:)`.
- 개발 언어를 **en** 으로 바꿨다(Info.plist 둘·pbxproj·`defaultLocalization`). 지원하지 않는 말의 사용자는 Foundation 이 `Locale.current` 를 어차피 영어로 잡으므로 ko 로 두면 「한국어 글 + 영어 날짜」가 섞인다.
- `Recurrence.label` 은 파일 토큰이라 그대로, 화면은 `.text()`. `MemoShape` 는 `#photo`·`#todo` 도 알아듣고 칩도 그 말로 적는다. Claude 에게 시키는 다듬기·아침 브리핑 문장도 사용자의 말을 따른다.
- `scripts/check-l10n.sh [--ios]` — 컴파일러(`-emit-localized-strings`)가 뽑은 열쇠와 en 표를 맞춰 빠진 것을 잡는다. 지금 전 모듈 0.

## 동작 흐름

시스템 언어 → 앱 번들의 `ko.lproj`/`en.lproj` 가 언어를 정한다(build-app.sh 가 `Resources/*.lproj` 를 복사, Xcode 맥 타깃은 `ios/LazyMemoMac/*.lproj` 심볼릭 링크) → SwiftUI `Text` 와 `L()` 이 같은 답을 낸다(`Locale.current` 의 언어 = 앱의 언어, 개발 언어 en 일 때만 언제나 일치 — 스크래치 앱 번들로 여섯 조합을 확인) → 패키지 리소스 번들의 표에서 찾는다.

## 검증

- `swift test` 736 통과(영어 표 시험 추가: SurfaceWords·MonthGrid·MemoTimeLabel·DateWords·ClaudePrompts). `uitest.sh` 11 통과(시험은 ko 로 고정).
- 맥: `.build` 바이너리와 `dist/LazyMemo.app` 둘 다 `-AppleLanguages "(en)"` 로 31 장면 렌더 — 잘리던 「September」·종이 꼬리 고침. 같은 번들 기본 언어(ko 기계)는 이전과 동일.
- 아이폰: 시뮬레이터에 설치해 en 으로 띄워 목록 확인. `xcodebuild` 맥 스토어 타깃 성공, 번들에 lproj 둘·리소스 번들 둘. MCP 는 번들 안 바이너리로 verify-mcp.sh 통과.

## 메모

- `swift build` 는 `.xcstrings` 를 **컴파일하지 않고 그대로 복사한다** — 그래서 `.lproj/.strings` 다. Xcode 만 쓰는 타깃도 같은 꼴로 맞췄다.
- `String(localized:locale:)` 의 `locale` 은 표를 고르지 않는다(숫자·복수형만). 표까지 고르려면 `LocalizedStringResource(locale:)`. 시험이 기계의 말과 상관없이 같은 답을 받는 길이 이것뿐이다.
- stringsdict 에서 복수형 변수가 둘째 인자면 `%2$#@n@` 처럼 자리를 적어야 한다 — 안 적으면 엉뚱한 숫자를 읽는다.
- 남은 것: 영어 스토어 스크린샷(`ShotTests`·`DemoTour` 가 한국어 낱말로 누르는 자리 → 식별자), 개발 창 스파이크·진단 문자열은 일부러 한국어 그대로.