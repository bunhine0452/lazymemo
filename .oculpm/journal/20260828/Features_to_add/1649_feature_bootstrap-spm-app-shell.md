---
schema_version: 1
type: feature
slug: "bootstrap-spm-app-shell"
status: done
difficulty: medium
created_at: "2026-08-28T16:49:55+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: create
  - path: "LICENSE"
    op: create
  - path: "README.md"
    op: create
  - path: ".gitignore"
    op: update
  - path: "Resources/Info.plist"
    op: create
  - path: "scripts/build-app.sh"
    op: create
  - path: "scripts/test.sh"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: create
  - path: "Sources/LazyMemoCore/Version.swift"
    op: create
  - path: "Sources/LazyMemo/main.swift"
    op: create
  - path: "Sources/LazyMemo/AppDelegate.swift"
    op: create
  - path: "Sources/LazyMemo/MenuBar/MenuBarController.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/AppPathsTests.swift"
    op: create
related: []
tags:
  - "spm"
  - "appkit"
  - "nsstatusitem"
  - "lsuielement"
  - "swift-testing"
  - "build-script"
  - "foundation"
  - "mcp-tool"
---
[x] SPM 골격과 메뉴바 상주 앱 셸 — Xcode 없이 빌드·테스트·번들 조립까지

플래너 `{#foundation}` phase 4개 항목을 한 사이클로 끝냈다. 설계문서가 §3 에서 "Xcode 없이 빌드 가능"을 검증해 뒀지만, 그건 단발 스파이크였고 이번에 실제 프로젝트 구조로 재현했다.

## 추가 기능

**패키지 구조** — 타깃을 둘로 갈랐다.

- `LazyMemoCore` — 도메인·저장 계층. AppKit 비의존이라 테스트가 GUI 없이 돈다. 나중에 MCP 서버 실행 파일(`{#mcp-server}`)이 같은 타깃을 재사용한다.
- `LazyMemo` — AppKit 셸. 도메인 로직을 두지 않는다.

`swift-tools-version: 6.2` + `platforms: [.macOS(.v26)]` 가 설치된 Swift 6.3.3 에서 정상 동작함을 확인했다.

**진입점을 SwiftUI `@main` 이 아니라 `main.swift` 로 잡았다.** 메모당 NSWindow(D2)와 바탕화면 창 레벨을 직접 다루려면 `NSApplication` 을 소유해야 하는데, SwiftUI `App`/`WindowGroup` 생명주기가 그 경로를 가린다. SwiftUI 는 `NSHostingView` 로 창 내용에만 쓴다.

**`AppPaths`** — 설계문서 §5.1 레이아웃을 타입으로 고정했다. 정본(`vault`)과 파생물(`support`)을 별도 필드로 두어 "파생물은 통째로 지워도 된다"는 불변식이 타입 서명에서 읽히게 했다. 메모 디렉터리는 `notes/2026/08/` 로 연·월 분할한다.

**빌드 스크립트 2개**

- `scripts/build-app.sh` — `swift build` → `.app` 번들 조립 → ad-hoc 서명(`codesign -s -`) → `codesign --verify` 까지.
- `scripts/test.sh` — 아래 함정을 감싼 래퍼.

## 동작 흐름

`open dist/LazyMemo.app` → `NSApp.setActivationPolicy(.accessory)` → `AppPaths.createDirectories()` → `MenuBarController` 가 `NSStatusItem` 에 SF Symbol `note.text` 를 붙인다. 저장 폴더 생성이 실패하면 복구 경로가 없으므로 조용히 죽지 않고 `NSAlert` 로 이유를 보이고 종료한다.

메뉴는 새 메모(⌘N, 아직 beep 스텁) · 메모 폴더 열기 · 종료. "메모 폴더 열기"를 넣은 건 D4(파일이 정본)를 UI 에서 곧바로 확인 가능하게 만들기 위해서다.

## 알아낸 것 — Command Line Tools 에서 swift test 가 실패하는 이유

`swift test` 가 `no such module 'Testing'` 으로 그냥 죽는다. Xcode 가 없으면 swift-testing 이 툴체인 기본 검색 경로 밖에 있기 때문인데, 문제는 **필요한 것이 한 곳이 아니라 두 곳에 흩어져 있다**는 점이다.

- 컴파일·링크: `$(xcode-select -p)/Library/Developer/Frameworks` (Testing.framework)
- 실행: `$(xcode-select -p)/Library/Developer/usr/lib` (`lib_TestingInterop.dylib`)

프레임워크 경로만 넣으면 빌드는 통과하고 실행 시점에 `Library not loaded: @rpath/lib_TestingInterop.dylib` 로 죽는다. `-rpath` 두 개를 각각 넣어야 끝까지 통과한다. 이 지식을 `scripts/test.sh` 에 가뒀고, Xcode 가 있는 환경에서는 표준 경로로 폴백한다.

## 검증

- `./scripts/test.sh` → `AppPaths` 스위트 4개 테스트 전부 통과.
- `./scripts/build-app.sh` → 번들 조립 후 `codesign --verify` 가 `satisfies its Designated Requirement` 반환.
- `open dist/LazyMemo.app` 실행 후 `lsappinfo` 로 `ApplicationType="UIElement"` 확인 — Dock 아이콘 없이 상주함이 확정됐다. `ps` 기준 RSS 44.6MB (빈 셸 기준선, 예산은 메모 10장에 100MB).
- `~/Documents/lazymemo/{notes,.trash}` 와 `~/Library/Application Support/lazymemo` 가 실제로 생성됨을 확인.
- 메뉴바 아이콘의 **육안 확인은 못 했다** — 이 터미널에 화면 기록 권한이 없어 `screencapture` 가 거부된다. 사용자 확인 필요.