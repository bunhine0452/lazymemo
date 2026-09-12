---
schema_version: 1
type: feature
slug: "core-compiles-for-ios"
status: done
difficulty: low
created_at: "2026-09-13T02:06:08+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/VaultWatcher.swift"
    op: update
  - path: "Sources/LazyMemoCore/Claude/ClaudeRunner.swift"
    op: update
  - path: "Sources/LazyMemoCore/Update/UpdateInstaller.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/ClaudeRunnerTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/UpdateInstallerTests.swift"
    op: update
  - path: ".swiftpm/xcode/xcshareddata/xcschemes/LazyMemoCoreTests.xcscheme"
    op: create
  - path: ".gitignore"
    op: update
related:
  - ref: "20260831/Features_to_add/1305_feature_vault-can-actually-move.md"
    kind: "followup"
tags:
  - "ios"
  - "icloud"
  - "core"
  - "build"
  - "mcp-tool"
---
[x] LazyMemoCore 가 iOS 로 컴파일되고 343개 테스트가 시뮬레이터에서 돈다

## 추가 기능

iOS 앱 + iCloud 컨테이너 동기화 계획(`lazymemo-ios-icloud`)의 첫 단계. 도메인·저장 계층 6,100줄이 **그대로** 폰으로 간다는 것을 확인했다 — import 가 Foundation·SQLite3·CryptoKit·CoreGraphics 뿐이라 예상대로였고, macOS 에만 있는 것은 셋뿐이었다.

- `VaultWatcher` — FSEvents. `#if os(macOS)` 로 감싸고 iOS 쪽에는 같은 인터페이스의 **빈 감시자**를 두었다 (`oculpm-defer` 표식). 동기화 단계에서 `NSMetadataQuery` 가 이 자리에 들어온다.
- `ClaudeRunner` — `Process`. 파일 전체를 맥의 것으로 두되, 같은 파일의 `ClaudePrompts`(순수 문자열)는 울타리 밖으로 꺼냈다 — `ClaudePromptsTests` 가 폰에서도 돌아야 하고, 문장은 플랫폼과 무관하다.
- `UpdateInstaller` — `Process`. 폰의 판 갈이는 스토어의 몫이라 파일 전체가 맥의 것.

## 동작 흐름

- `Package.swift` `platforms` 에 `.iOS(.v26)` 추가. 타깃은 그대로 — iOS 앱 셸은 패키지 밖(`ios/`)에 Xcode 프로젝트로 두고 `LazyMemoCore` 만 끌어 쓴다는 결정. `swift build` 가 iOS 전용 타깃을 macOS 에서 지으려 드는 일이 없다.
- 자동 생성되는 `LazyMemo-Package` 스킴은 AppKit 에 기대는 `LazyMemoUITests` 까지 끌고 와 iOS 로는 못 짓는다. 그래서 Core + CoreTests 만 담은 공유 스킴 `LazyMemoCoreTests` 를 `.swiftpm/xcode/xcshareddata/xcschemes/` 에 두고, `.gitignore` 의 `.swiftpm/` 을 층층이 열어 그 폴더만 들여왔다.
- `ClaudeRunnerTests`·`UpdateInstallerTests` 도 `#if os(macOS)`.

## 검증

- `xcodebuild test -scheme LazyMemoCoreTests -destination 'platform=iOS Simulator,name=iPhone 17'` → **343 tests in 54 suites passed** (맥에서 빠지는 18개 = ClaudeRunner 10 + UpdateInstaller 8).
- 맥은 그대로: `swift build` 전체 성공, `./scripts/test.sh --filter LazyMemoCoreTests` → 361개 통과.