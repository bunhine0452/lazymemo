---
schema_version: 1
type: feature
slug: "spotlight-index-mac-ios"
status: done
difficulty: medium
created_at: "2026-09-16T15:41:50+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoSpotlight/SpotlightCenter.swift"
    op: create
  - path: "Sources/LazyMemoSpotlight/SpotlightEntry.swift"
    op: create
  - path: "Sources/LazyMemoSpotlight/SystemSpotlightIndex.swift"
    op: create
  - path: "Sources/LazyMemoSpotlight/Words.swift"
    op: create
  - path: "Sources/LazyMemoSpotlight/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "Sources/LazyMemoSpotlight/Resources/ko.lproj/Localizable.strings"
    op: create
  - path: "Tests/LazyMemoSpotlightTests/SpotlightCenterTests.swift"
    op: create
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemo/LazyMemoApp.swift"
    op: update
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "site/privacy/index.html"
    op: update
related: []
tags:
  - "spotlight"
  - "corespotlight"
  - "search"
  - "mac"
  - "ios"
  - "privacy"
  - "mcp-tool"
---
[x] Spotlight 에서 찾기 — 앱을 열지 않고도 메모가 찾힌다

## 추가 기능

새 모듈 `LazyMemoSpotlight` — `LazyMemoReminders` 와 같은 모양이다. Core 에 두지 않은 이유도 같다: MCP 서버·테스트까지 CoreSpotlight 를 들지 않게.

- **`SpotlightEntry`** — 무엇을 보이는지는 여기서만 정한다. 제목(`Memo.title`)·둘째 줄(`previewLine`, 없으면 장소)이 결과에 보이고, 본문 전체는 `textContent` 로 찾기에만 쓰인다. 태그·폴더·장소는 `keywords`, 일정은 `dueDate`(at, 또는 due 의 그 날 시작) — 「내일」같은 상대 낱말을 색인에 굳히지 않는다(어제 색인한 「내일」은 오늘 거짓말). 글도 사진도 없는 메모와 휴지통은 올리지 않는다. `fingerprint` = 본문+due+at+place+folder+tags 의 SHA-256.
- **`SpotlightIndex` 프로토콜 + `SystemSpotlightIndex`** — `CSSearchableIndex.default()` 위의 얇은 문. `ifBundled()` 로 앱 번들 안에서만 선다(bare `swift run`·`swift test` 는 번들 id 가 없다). 항목 만료는 `.distantFuture` — 기본 한 달 만료를 끈다, 내리는 것은 대조가 한다.
- **`SpotlightCenter`** — `@MainActor @Observable`, `shared`, `start(store:)`, `withObservationTracking` 으로 `store.memos` 를 보고 `refresh()`(dirty/running 한 번에 하나). **대조가 전부다**: 있어야 할 집합을 새로 세고 없어진 것은 내리고 바뀐 것만 다시 올린다. 시스템 색인은 «지금 무엇이 있나»를 물을 길이 없어 올린 것의 지문(id→fingerprint)을 `UserDefaults("spotlight.indexed")` 에 함께 적는다 — 껐다 켜도 바뀐 것만 다시 올린다. `enabled`(`spotlight.enabled`, 기본 **켜짐**, 기기별)를 끄면 domain 전체를 내리고 지문을 비운다. 실패는 `trouble` 에 사람의 말로 적고 삼키지 않는다.
- **열기** — `SpotlightCenter.memoID(from: NSUserActivity)` 가 `CSSearchableItemActionType` 활동에서 ULID 를 꺼낸다. 화면 코드는 CoreSpotlight 를 들지 않는다(`activityType` 상수를 모듈이 내준다).

## 동작 흐름

- **맥** `AppDelegate`: 메모를 다 읽은 뒤 `SpotlightCenter.shared.start(store:)` (알림과 같은 이유 — 빈 목록에 대조하면 전부 내린다). `application(_:continue:restorationHandler:)` → `windows.reveal(id, keepingPlace: true)`(보는 일이지 자리를 옮기는 일이 아니다). 창이 서기 전에 오면 `pendingReveal` 에 들고 있다가 `revealReady` 뒤 꺼낸다 — Spotlight 로 앱이 처음 깨어나는 경우. 설정 메뉴에 「Spotlight 에서 찾기」 토글, 부제 「메모 제목과 글이 이 맥의 검색에 보입니다 — 기기 밖으로 나가지 않습니다」(trouble 이 있으면 그것).
- **폰** `AppModel.start` 가 같은 자리에서 붙이고, `LazyMemoApp` 이 `.onContinueUserActivity(SpotlightCenter.activityType)` 로 `opened` 에 담으면 `HomeView` 가 알림과 **같은 시트**(`NotifiedMemo`)로 연다. 폰에는 토글이 없다 — 설정 화면이 없고(MOBILE_DESIGN §16), 폰은 나눠 쓰는 기기가 아니다.
- **문서** README 프라이버시 표·docs/PRIVACY.md(ko·en)·site/privacy 에 한 줄씩: 아무것도 안 나간다, 기기 안 검색에 제목과 글이 보인다, 기본 켜짐, 맥은 끌 수 있다.

## 검증

- `Tests/LazyMemoSpotlightTests` 8개(가짜 색인): 기본 켜짐·빈 메모 제외 / 바뀐 것만 다시 올리고 지운 것은 내림 / 끄면 전부 내리고 다시 켜면 전부 올림 / 꺼 둔 채 시작하면 손대지 않음 / 지문이 UserDefaults 에 남아 다음 실행이 바뀐 것만 올림 / 못 쓰는 기기는 trouble / 실패는 적고 다음 대조에서 재시도 / Entry 모양. 전체 `scripts/test.sh` **837 passed**.
- `swift build` 맥 패키지 · `xcodebuild` LazyMemo-iOS(시뮬레이터)·LazyMemo-macOS 둘 다 BUILD SUCCEEDED. `check-l10n.sh` Spotlight 2/2·UI 새 열쇠 2개 en 있음.
- **실기기 손검증은 남았다** — 앱을 띄워 Spotlight(⌘Space)에 메모 제목을 쳐서 나오는지, 눌러서 그 종이가 앞으로 오는지, 끄면 사라지는지. GitHub 판 번들은 `#bundle-dylib` 때문에 지금 켜지지 않으므로 Xcode 산출물(`.build/ios/Build/Products/Debug/LazyMemo.app`, 스토어 판)로 봐야 한다.

## 메모

- 처음 제안한 `#dup-hint`(빠른 입력 중복 알림)는 만들지 않았다 — **이미 있다.** 빠른 입력은 치는 동안 기존 메모를 걸러 보이고(구 검색 → 여러 낱말이면 `MemoRanker` 낱말 랭킹 폴백), 폰은 「N장 중 겹치는 것 없음 · 남기면 새 메모예요」까지 적는다. 조사 때 「duplicate|비슷한」으로 grep 해 못 본 것.
- `SpotlightEntry.description` 이 빈 문자열이면 시스템이 자리를 비운다 — nil 을 넘기려고 옵셔널로 만들 이유가 없었다.