---
schema_version: 1
type: feature
slug: "mac-app-store-sandbox-build"
status: done
difficulty: high
created_at: "2026-09-13T11:55:33+09:00"
session_id: "20260913-006"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Update/InstallSource.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/VaultBookmark.swift"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Claude/ClaudeSupport.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Update/Updater.swift"
    op: update
  - path: "Sources/LazyMemoUI/VaultMover.swift"
    op: update
  - path: "Sources/LazyMemoUI/VaultLabel.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/VaultBookmarkTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/AppPathsTests.swift"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemo.xcodeproj/xcshareddata/xcschemes/LazyMemo-macOS.xcscheme"
    op: create
  - path: "ios/LazyMemoMac/main.swift"
    op: create
  - path: "ios/Config/Mac-Info.plist"
    op: create
  - path: "ios/Config/LazyMemo-macOS.entitlements"
    op: create
  - path: "ios/scripts/archive.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "docs/APP_STORE_READINESS.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md"
    kind: "followup"
tags:
  - "macos"
  - "app-store"
  - "sandbox"
  - "icloud"
  - "xcode"
  - "mcp-tool"
---
[x] 맥 App Store 판 — 샌드박스 Xcode 타깃, Claude 없음, iCloud 기본 자리, 폴더 열쇠

## 추가 기능

스토어는 샌드박스를 요구하고 GitHub 판(`build-app.sh`, ad-hoc)은 그 길로 못 간다. 코드는 하나로 두고 **껍데기를 하나 더** 만들었다 (설계문서 §12.6).

- `ios/LazyMemo.xcodeproj` 에 `LazyMemo-macOS` 타깃 — `LazyMemoUI` 패키지 의존, `ios/LazyMemoMac/main.swift`(SPM 진입점과 같은 넉 줄), `Config/Mac-Info.plist`(`LazyMemoAppStoreBuild=true`·카테고리·암호화 면제·`NSUbiquitousContainers`), `Config/LazyMemo-macOS.entitlements`(샌드박스·사용자 선택 파일·북마크·네트워크·위치·캘린더·iCloud — 각 줄에 근거 주석), `Resources/AppIcon.icns` 참조. 공유 스킴 `LazyMemo-macOS`. pbxproj 는 손으로 썼다(id 접두 `4C4D…02xx`).
- `InstallSource.current` — 판별 한 곳. `Updater`·`ClaudeSupport`·메뉴가 같은 답을 본다. 스토어 판에서 `ClaudeSupport.resolve` 는 `nil` (로그인 셸도 안 띄운다), 설정 메뉴의 Claude 두 줄과 업데이트 줄이 없다.
- `AppPaths.resolve(cloudContainer:)` — 설정이 비어 있을 때의 기본 자리를 iCloud 컨테이너 `Documents/` 로. 스토어 판만 `AppDelegate` 가 컨테이너를 찾아 넘긴다(막히는 호출이라 detached). 샌드박스의 `~/Documents` 는 Finder 에서 안 보이는 자리라 D4 를 지키는 곳이 iCloud Drive 의 「LazyMemo」뿐이고 폰과 같은 자리다.
- `AppDelegate.rememberVault` — 스토어 판은 **첫 실행에 정한 자리를 `vaultPath` 에 적는다.** iCloud 를 나중에 켜거나 끄는 것만으로 다음 실행이 다른 폴더를 보면 「메모가 전부 사라진」 화면이 된다. `LAZYMEMO_VAULT` 시험은 적지 않는다.
- `VaultBookmark`(Core, macOS) + `Settings.vaultBookmark` — 패널로 고른 폴더의 security-scoped bookmark 를 설정에 같이 적고 `resolve` 가 그것으로 문을 연다. 낡은 열쇠는 `Resolution.refreshedBookmark` 로 되돌려 `rememberVault` 가 다시 적는다. iCloud 컨테이너(merge)에는 열쇠를 안 붙인다 — entitlement 가 여는 자리.
- `VaultLabel` — 샌드박스에선 `NSHomeDirectory()` 가 컨테이너라 `~/Documents/lazymemo` 로 잘못 보인다. iCloud 컨테이너/앱 컨테이너는 이름으로 적고, 줄임 기준은 `getpwuid` 의 진짜 홈.
- `cloudSyncItem` 이 `cloudContainerOnDisk()`(홈 기준이라 샌드박스에서 못 찾음) 대신 뜰 때 찾아 둔 컨테이너를 본다.
- `menuDiagnostics` 가 하위 메뉴·부제까지 찍는다 — 스토어 판에 Claude·업데이트 줄이 없는 것을 그걸로 봤다.
- `ios/scripts/archive.sh mac` — 맥 아카이브·업로드, 아카이브에 `app-sandbox` 가 없으면 멈춘다.
- 문서: DESIGN §12.6, README(설치·배포), APP_STORE_READINESS 표 갱신.

## 동작 흐름

스토어 판 첫 실행: `ubiquityContainer()` → 있으면 `…/Mobile Documents/iCloud~…/Documents/` 가 vault, 없으면 컨테이너 `Documents/lazymemo` → `rememberVault` 가 그 자리를 적는다 → 이후는 메뉴의 옮기기만 자리를 바꾼다. 「메모 폴더 옮기기…」 → 패널 → adopt/move → 열쇠 생성·저장 → 재실행 시 열쇠로 연다.

## 검증

- `./scripts/test.sh` 725개 통과 (`VaultBookmarkTests` 3개, `AppPathsTests` 「스토어 기본 자리」 추가).
- `xcodebuild build -scheme LazyMemo-macOS`(서명 없이) 통과. 산출물을 ad-hoc + 샌드박스 entitlement(iCloud 제외)로 서명해 `LAZYMEMO_MENU=1` 로 띄웠다 — 샌드박스 안에서 뜨고, vault 가 `~/Library/Containers/…/Documents/lazymemo`, `settings.json` 에 `vaultPath` 가 적히고, 설정 메뉴에 Claude·업데이트 줄이 없으며 폴더 줄이 「이 앱의 보관함 — iCloud 가 꺼져 있을 때의 자리」. 시험 컨테이너는 지웠다.
- 자동 서명 아카이브는 **아직 못 돌렸다** — Xcode 에 개발자 계정이 로그인돼 있지 않다 (`No Accounts`). 사용자가 Xcode › Settings › Accounts 에 로그인해야 한다.

## 메모

iCloud entitlement 가 든 실제 서명본의 컨테이너 접근·핫키·달력·위치·재시작은 TestFlight 판으로 손검증해야 한다 (플랜 `mac-sandbox-handtest`).