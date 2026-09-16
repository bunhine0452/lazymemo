---
schema_version: 1
type: bug
slug: "korean-app-english-plurals-words-locale"
status: done
difficulty: high
created_at: "2026-09-15T13:39:16+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Words.swift"
    op: update
  - path: "Sources/LazyMemoUI/Words.swift"
    op: update
  - path: "Sources/LazyMemoMCP/Words.swift"
    op: update
  - path: "Sources/LazyMemoReminders/Words.swift"
    op: update
  - path: "Sources/LazyMemoCore/Claude/ClaudeRunner.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoTimeLabel.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MonthGrid.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Recurrence.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/SurfaceWords.swift"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.stringsdict"
    op: update
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.stringsdict"
    op: create
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.stringsdict"
    op: update
  - path: "ios/LazyMemo/ko.lproj/Localizable.stringsdict"
    op: create
  - path: "scripts/test.sh"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoTitleTests.swift"
    op: update
related:
  - ref: "20260914/Features_to_add/2144_feature_english-full-localization.md"
    kind: "followup"
tags:
  - "l10n"
  - "stringsdict"
  - "swift-test"
  - "ios"
  - "mac"
  - "release"
  - "mcp-tool"
---
[x] 한국어 앱에 「1 photos」가 서고 swift test 가 한국어 기계에서도 영어로 돌았다 — Words.locale 을 이름 있는 로케일로

## 발생 원인

정식 출시 점검으로 `./scripts/test.sh` 를 돌리니 775개 중 39개가 빨갛다 — 전부 한국어 원문을 기대하는데 영어가 온 것(「빈 메모」→「Empty note」). 시뮬레이터 XCUITest 도 「명함 사진, 어제, 노랑, **1 photos**」로 빨갛다. 스크래치 앱 번들과 툴체인 헬퍼로 재현해 원인을 둘로 갈랐다.

1. **`LocalizedStringResource(locale: .current)` 는 「주 번들이 고른 말」을 뜻한다.** `swift test` 의 실행 파일은 `swiftpm-testing-helper` 라 lproj 가 없고, 그래서 고를 것이 없어 늘 개발 언어(영어)로 떨어진다 — `Locale.current` 가 `ko_KR` 이어도. `swift run`·`.build` 의 MCP 도 같은 이유로 영어였고, `verify-tidy.sh`·`verify-mcp.sh` 가 한국어 문자열을 못 찾아 빨갰다. 릴리스 워크플로(en 러너)는 시험 단계에서 멈췄을 것이다 — 영어 전환(e69a1a1) 뒤 태그를 민 적이 없어 안 드러났다.
2. **ko 표에 없는 복수형 열쇠는 영어 `stringsdict` 로 건너뛴다.** `.strings` 는 파일만 있으면 열쇠를 그대로 돌려주지만, `stringsdict` 는 없는 열쇠를 개발 언어 표에서 찾는다. 그리고 복수 범주는 **로케일**이 고르는데 한국어엔 `one` 이 없어 `other` 꼴(「%lld photos」)이 선다. 앱 번들 안에서도 그렇다 — TestFlight 에 올라간 폰·맥 판에 실제로 들어 있다. 영어 쪽도 「사진 %lld장」·「걸어 둔 알림 %lld개」·「%lld장 중 겹치는 것 없음」 셋이 `.strings` 에 복수형 없이 적혀 「1 photos」였다.

## 해결 방법

- `Words.locale` 을 두고 모든 `locale:` 기본값이 그것을 본다. **늘 이름 있는 로케일** — `Locale(identifier: Locale.current.identifier)`. 이름을 주면 `.current` 의 두 버릇(주 번들 의존·영어 stringsdict 건너뛰기)이 다 사라진다. 앱 번들 안에서 `Locale.current` 는 번들이 고른 말 + 지역이라 뜻은 같다(스크래치 번들로 ko/en/ja 조합 확인 — 지원 안 하는 말은 `en_XX` 로 떨어진다). `LAZYMEMO_LANGUAGE=ko` 가 있으면 그 말 — `test.sh` 가 이것으로 고정해 어느 러너에서든 같은 답.
- 아이폰 앱의 SwiftUI 리터럴은 `String(localized:)` 라 `Words.locale` 을 안 지난다 → `ko.lproj/Localizable.stringsdict` 를 두어 영어 stringsdict 의 열쇠 다섯을 한국어(`other` 하나)로 적었다. 건너뛸 자리가 없다.
- 영어 복수형 셋을 `stringsdict` 로 옮기고(`1 photo`·`1 reminder scheduled`·`among 1 note`), `MemoTitleTests` 에 영어 단·복수 시험을 더했다.

## 검증
- `./scripts/test.sh` 776 통과(이전 39 실패). `check-l10n.sh --ios` 빠짐 0.
- XCUITest 15개 전부 통과 — `testPhotoFromMacShowsOnThePaper` 가 「사진 1장」을 본다.
- Xcode 맥 스토어 타깃 빌드 → `.build` 밖으로 옮겨 `LAZYMEMO_MENU=1` 로 띄우면 한국어 「메모 1장」, `-AppleLanguages (en)` 이면 「1 note」. `verify-tidy`·`verify-mcp` 도 초록.

## 메모
- `CFBundleAllowMixedLocalizations` 를 주 번들 info dict 에 런타임으로 꽂는 해킹도 통하지만(`CFBundleGetInfoDictionary` 가 mutable) 기계의 말에 묶인다. 환경 변수 하나가 낫다.
- ASC 에 붙은 빌드(09-15 03:08)에 이 버그가 있다 — 제출 전에 새로 올려야 한다 (`docs/APP_STORE_READINESS.md` 출시 날 할 일 1).