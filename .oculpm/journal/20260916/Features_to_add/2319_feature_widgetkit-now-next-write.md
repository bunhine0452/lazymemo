---
schema_version: 1
type: feature
slug: "widgetkit-now-next-write"
status: done
difficulty: high
created_at: "2026-09-16T23:19:36+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoWidgetsCore/WidgetAgenda.swift"
    op: create
  - path: "Sources/LazyMemoWidgetsCore/WidgetLink.swift"
    op: create
  - path: "Sources/LazyMemoWidgetsCore/WidgetKind.swift"
    op: create
  - path: "Sources/LazyMemoWidgetsCore/NowSeen.swift"
    op: create
  - path: "Sources/LazyMemoWidgetsCore/WidgetRefresher.swift"
    op: create
  - path: "Tests/LazyMemoWidgetsCoreTests/WidgetAgendaTests.swift"
    op: create
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemoWidgets/LazyMemoWidgets.swift"
    op: create
  - path: "ios/LazyMemoWidgets/NowWidget.swift"
    op: create
  - path: "ios/LazyMemoWidgets/NextWidget.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WriteWidget.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WidgetVault.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WidgetWords.swift"
    op: create
  - path: "ios/LazyMemoWidgets/WidgetPaper.swift"
    op: create
  - path: "ios/LazyMemoWidgets/en.lproj/Localizable.strings"
    op: create
  - path: "ios/LazyMemoWidgets/ko.lproj/Localizable.strings"
    op: create
  - path: "ios/Config/Widgets-Info.plist"
    op: create
  - path: "ios/Config/LazyMemoWidgets.entitlements"
    op: create
  - path: "ios/Config/LazyMemoWidgets-macOS.entitlements"
    op: create
  - path: "ios/Config/Info.plist"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemo/AppLinks.swift"
    op: create
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
  - path: "ios/LazyMemo/LazyMemoApp.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/NowBand.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemoUITests/DeepLinkTests.swift"
    op: create
  - path: "scripts/check-l10n.sh"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Features_to_add/1541_feature_spotlight-index-mac-ios.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0246_feature_share-extension-and-app-group.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
tags:
  - "widgets"
  - "widgetkit"
  - "ios"
  - "mac"
  - "app-store"
  - "deep-link"
  - "mcp-tool"
---
[x] 진짜 위젯 — 아이폰·맥 스토어 판의 「지금」·다음 약속·적기, WidgetKit 확장 타깃과 lazymemo:// 딥링크

## 추가 기능

**한 확장 타깃 `LazyMemoWidgets`** (`ios/LazyMemoWidgets`, 번들 id `io.github.bunhine0452.lazymemo.widgets`)이 `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx` · `SDKROOT = auto` 로 두 플랫폼으로 빌드되어 `LazyMemo-iOS` 와 `LazyMemo-macOS` 두 앱의 PlugIns 에 박힌다. entitlement 는 sdk 조건부 — 폰은 iCloud 컨테이너 + App Group, 맥은 샌드박스 + iCloud 컨테이너. `MARKETING_VERSION` 도 sdk 조건부(폰 0.1.0 · 맥 0.4.0)라 품는 앱과 맞는다 — 스토어 검증이 확장과 앱의 판이 같기를 요구한다. GitHub 판(SwiftPM 번들)에는 확장이 실리지 않는다 — README 에 그렇게 적었다.

- **「지금」** (`WidgetKind.now`) — `Recall.nowCards` 그대로. 작게 한 장(+「외 N장」), 중간 세 장, 크게 세 장 아래 「다음」(오늘 뒤의 일정 여섯 줄까지, `WidgetAgenda.upcoming`). 잠금 화면 네모·한 줄. 카드는 `Link`/`widgetURL` 로 그 메모, 빈 위젯은 펜.
- **「다음 약속」** (`next`) — 시각이 적힌 가장 가까운 약속(`WidgetAgenda.next`). 큰 글자가 시각, 옆에 오늘/내일/날짜, 제목 두 줄, 마지막 줄은 가는 길이 있으면 「18:39 출발 · 2호선」(`RouteNote.read` → `TransitRoute.depart` + 첫 탈것) 아니면 `Text(.relative)` 로 흐르는 「N시간 M분 뒤」. 잠금 화면 네모·동그라미(24시간 시계)·한 줄.
- **「적기」** (`write`) — 앱 아이콘의 두 글줄(`BrandMark`) + 「누르면 펜이 올라와요」. 잠금 화면 동그라미(연필)·한 줄. 시간표는 `.never`.

**읽기는 파일만** — `WidgetVault.memos()` 가 `AppPaths.resolveCloud(container:shared:)` 로 앱·공유 확장과 같은 차례로 자리를 정하고 `MemoVault.loadAll()` 만 부른다. 인덱스(SQLite)는 앱의 파생물이라 열지 않는다(`InboxDrop` 과 같은 이유). 맥 위젯에는 App Group 이 없어 `shared: nil`.

**시간표** — `WidgetAgenda.moments`: `now` + 각 eligible 메모의 `surface`·`at`(36시간 안, 미래) + 다음 자정, 최대 12개, 정책 `.atEnd`. 그 순간마다 `Recall.nowCards`/`next` 를 다시 세어 장면을 만든다 — 시각이 지나 「지남」이 되고, 다음 약속이 그다음으로 넘어가고, 자정에 오늘이 바뀐다.

**앱이 위젯을 다시 그리게** — `WidgetRefresher`(`LazyMemoWidgetsCore`): `SpotlightCenter` 와 같은 모양으로 `store.memos` 를 `withObservationTracking` 으로 보다가 **2초 안에 모아** `WidgetCenter.shared.reloadTimelines(ofKind:)` 셋. 폰은 `AppModel.start` 끝에 붙이고 `background()` 에서 `flush()`; 맥은 `AppDelegate` 가 메모를 다 읽은 뒤 붙인다. `#if canImport(WidgetKit)` 뒤라 `swift build`/`test.sh` 헬퍼에서도 컴파일된다.

**「봤어요」의 기억** — `NowSeen` 을 앱에서 `LazyMemoWidgetsCore` 로 옮기고 자리를 App Group defaults(`UserDefaults(suiteName: group…)`)로 바꿨다. 앱에서 내려놓은 카드가 위젯에서도 내려간다. 앱 쪽 `NowBand.swift` 는 typealias 한 줄, `StackView` 는 import 한 줄.

**딥링크** — `WidgetLink`: `lazymemo://memo/<ULID>`·`lazymemo://write`. 맥의 `lazymemo://add`(`InboundLink`)와 같은 스킴, 동사만 다르다. 폰 `Info.plist` 에 스킴을 등록했다.
- 폰: `LazyMemoApp.onOpenURL` → `AppModel.open(url:)`. memo 는 **`SpotlightCenter.shared.opened` 에 담는다** — `HomeView` 가 알림·Spotlight 와 같은 시트로 열고, HomeView 는 손대지 않았다. write 는 새 `AppLinks.shared.requestWrite()` → `PenBar` 가 `onChange(initial: true)` 로 받아 `pen.requestFocus()` (받으면 비워 탭을 옮겨도 두 번 안 오른다, 첫 실행 안내가 떠 있으면 미룬다). 그 밖은 `InboundLink.note(from:)` → `NoteReader` → `store.create` — **폰도 이제 `lazymemo://add?text=…` 를 받는다** (저장소가 서기 전이면 `pendingInbound`).
- 맥: `AppDelegate.application(_:open:)` 이 `WidgetLink.destination` 을 먼저 보고 memo → `windows.reveal(id, keepingPlace: true)`(창이 서기 전이면 `pendingReveal`), write → `menuBar.showCapture()`(전이면 `pendingWrite`), 나머지는 예전처럼 `door.receive(url:)`.

**말** — 위젯의 한국어 열쇠 31개 전부 `en.lproj` 에 있다(`check-l10n.sh --ios` 에 Widgets 모듈을 더했다). 종이·잉크·포레스트는 `ios/LazyMemo/Theme.swift` 와 같은 숫자를 `WidgetPaper.swift` 에 한 번 더 적었다(UIColor/NSColor 동적 색, 대비 높임까지 네 벌).

## 동작 흐름

- 얼굴은 `NowView(entry:family:)` 처럼 **크기를 손으로 받는다** — `@Environment(\.widgetFamily)` 는 읽기 전용이라 렌더 검증이 그렇게 부른다. 확장 안에서는 `NowRoot` 가 환경을 읽어 넘긴다.
- 확장 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` — `TimelineProvider` 의 완료 클로저가 `@Sendable` 이고 어느 큐에서 오는지 모르므로 프로젝트 기본(MainActor)을 따르지 않는다. 엔트리는 전부 `Sendable`.
- 렌더 검증은 스크래치패드의 임시 SwiftPM 패키지(얼굴 파일을 복사, `Link` 는 정규식으로 벗김 — `ImageRenderer` 가 `Link` 를 노란 🚫 자리표시자로 그린다)에서 `ImageRenderer` 로 맥(system 세 크기·다크·빈 상태)과 iPhone 17 Pro 시뮬레이터(accessory 넷)를 PNG 로 찍어 눈으로 봤다. 큰 위젯의 아랫부분이 비어 「다음」을 여섯 줄로 늘리고 카드 여백을 키웠고, 작은 「다음 약속」이 158pt 에서 제목이 한 줄로 잘려 날 표시를 시각 옆으로 옮겼다. PNG 와 패키지는 확인 뒤 지웠다.

## 검증

- `swift build` OK · `./scripts/test.sh` **886 통과**(새 시험 14 — WidgetAgenda 9·WidgetLink 4·NowSeen 1). 첫 전체 실행에서 `SpotlightCenterTests` 의 「지문은 UserDefaults 에…」 하나가 한 번 빨갛게 나왔다가 재실행·단독 실행에서 통과 — 손대지 않은 시간 의존 시험의 흔들림.
- `xcodebuild build` `LazyMemo-iOS`(iPhone 17 Pro 시뮬레이터)·`LazyMemo-macOS`(generic/platform=macOS) 둘 다 `-derivedDataPath .build/ios` · `CODE_SIGNING_ALLOWED=NO` 로 BUILD SUCCEEDED. 폰 앱 `PlugIns/LazyMemoWidgets.appex`(0.1.0, Core 자원 번들·en/ko.lproj 동봉), 맥 앱 `Contents/PlugIns/LazyMemoWidgets.appex`(0.4.0) 확인. 서명하는 시뮬레이터 시험 빌드에서는 appex 의 `__entitlements` 에 iCloud+App Group 이 박혔다.
- `check-l10n.sh --ios`: Widgets 코드 31 · en 31 · 빠짐 0, iOS 빠짐 0 (LazyMemoUI 의 PreviewRenderer/QuickCaptureModel 7건은 전부터 있던 것).
- UI 시험 `DeepLinkTests` 2건(iPhone 17 Pro 시뮬레이터): `lazymemo://memo/<id>` → 「닫기」가 있는 시트에 그 메모 본문, `lazymemo://write` → 내려 둔 키보드가 다시 오른다. 시험은 스프링보드의 「'lazymemo'에서 열겠습니까?」에서 「열기」를 누른다(위젯에서는 이 창이 없다).

## 메모

- **남은 것 — 사용자가 해야 하는 프로비저닝**: 새 App ID `io.github.bunhine0452.lazymemo.widgets` 에 iCloud 컨테이너와 App Group 을 붙인 프로필이 있어야 실기기·아카이브가 서명된다. `./ios/scripts/archive.sh`(`-allowProvisioningUpdates`)를 한 번 돌리면 Xcode 가 등록한다 — 공유 확장 때와 같다. App Store Connect 에 따로 만들 것은 없다(앱 레코드 안의 확장).
- 실기기에서 아직 안 본 것: 홈 화면에 실제로 얹었을 때의 갤러리 견본(`context.isPreview` → `WidgetSample`), 잠금 화면의 vibrant 렌더, 맥 알림 센터에서 `Link` 가 앱을 깨우는지, 하루 갱신 예산 안에서 `WidgetRefresher` 의 2초 모으기가 충분한지.
- 맥에서 메모 폴더를 iCloud 밖으로 옮겨 둔 사람의 위젯은 빈다 — 위젯은 그 폴더의 열쇠(`VaultBookmark`)가 없다. README 에 적었다. 필요하면 앱이 App Group 으로 vault 경로+열쇠를 건네는 길을 따로 연다.
- iOS 는 인자 도메인(`-now-seen {}`)이 suite defaults 에도 먹어 UI 시험이 그대로 돈다.
- 스크래치·산출물은 지웠다: 렌더 패키지·PNG·시뮬레이터 스크린샷, 워크트리의 `.build`(맥 debug + 시뮬레이터·맥 derived data ≈ 3GB).