---
schema_version: 1
type: feature
slug: "widget-theme-follow-choice"
status: done
created_at: "2026-09-18T19:44:53+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Sonnet 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemoWidgets/WidgetPaper.swift"
    op: update
  - path: "ios/LazyMemoWidgets/NowFaces.swift"
    op: update
  - path: "Tests/LazyMemoWidgetsCoreTests/WidgetThemeDefaultsTests.swift"
    op: create
related:
  - ref: "20260918/Features_to_add/1912_feature_widget-redesign-precise-comfortable.md"
    kind: "followup"
tags:
  - "theme"
  - "widgets"
  - "ios"
  - "macos"
  - "mcp-tool"
---
[x] 위젯이 사람이 고른 테마를 따라간다 — `WidgetTheme.paper` 가 `ThemeChoice` 를 읽는다

## 추가 기능

`ios/LazyMemoWidgets/WidgetPaper.swift` 의 `WidgetTheme.paper` 를 리터럴 `Shade` 넉 벌짜리 `static let` 에서, App Group 거울 `ThemeChoice.load()` 를 읽어 짓는 `static var` (계산 속성)로 바꿨다. 이제 사람이 설정에서 고른 여덟 테마(크림과 포레스트·미드나잇·세피아·흑백 잉크·봄 파스텔·숲속 어둠·바다·장미) 중 무엇을 골라도 홈 화면·알림 센터 위젯이 같은 종이·잉크로 그려진다.

## 동작 흐름

1. `paper` 가 불릴 때마다 `ThemeChoice.load()` 로 `ResolvedTheme` 한 벌(라이트·다크·대비 높임 넷을 이미 지어 둔 것)을 읽는다.
2. 각 색(`surface`/`card`/`ink`/`secondary`←`secondaryInk`/`accent`/`onAccent`/`accentInk`/`highlightInk`)을 새로 만든 `themedColor(_:_:)` 로 감싼다 — `UIColor { traits in … }` / `NSColor(name:) { appearance in … }` 닫힘 안에서 그 순간의 라이트·다크·대비 높임을 `theme.variant(dark:highContrast:)` 로 뽑아 온다. 「미드나잇」처럼 빛 모드에서도 어두운 종이인 테마는 `ThemeVariant.darkPaper` 가 이미 그 구분을 담고 있어 시스템 appearance 로 따로 뒤집을 필요가 없었다.
3. 메모 색 여섯의 잉크는 `ThemeSpec.ink(_:)` 로 뽑아 `WidgetTheme.memoInks` 사전에 미리 채우고, `theme.ink(for:)` 메서드로 노출했다. 예전에는 `MemoColor.widgetInk` 라는 하드코딩 스위치가 있었는데(테마 카탈로그의 `stationery` 표와 숫자가 겹쳐 적혀 있었다) 그걸 지우고 `NowFaces.swift` 의 유일한 호출부(`card.memo.color.widgetInk` → `theme.ink(for: card.memo.color)`)만 고쳤다.
4. 리터럴이 사라지면서 `Shade` 구조체(네 벌짜리 좌표 → 동적 `Color`)도 더는 쓰이지 않아 함께 지웠다 — 대신 같은 역할을 하는 `themedColor(_:_:)` 가 `ResolvedTheme` 을 받는다. `ThemeRGB → UIColor/NSColor/Color` 변환은 앱 쪽(`ios/LazyMemo/Theme.swift`)과 같은 자리 이름으로 `WidgetPaper.swift` 안에 `private extension ThemeRGB` 로 새로 두었다(위젯 타깃은 앱 모듈을 못 든다).
5. `mono`(잠금 화면 vibrant · iOS 18+ 틴트) 는 그대로 시스템 계층색만 쓴다 — 손대지 않았다.
6. 타임라인 새로고침은 **아직 안 걸려 있다.** `Sources/LazyMemoUI/Views/ThemeStore.swift:83` 과 `ios/LazyMemo/ThemeModel.swift:72` 의 `apply(_:)` 가 `ThemeChoice.save(...)` 를 부른 뒤 `WidgetRefresher.shared.reload()` 를 부르지 않는다 — 테마를 바꿔도 앱이 위젯에 "다시 그려라" 신호를 안 보내므로, 위젯은 다음 자연 새로고침(또는 앱 재실행)까지 옛 종이로 남는다. 이 파일들은 이 작업의 편집 허가 범위 밖이라(`ios/LazyMemoWidgets/**` 만 clone) 고치지 않고 여기 남긴다 — 두 자리 각각에 `ThemeChoice.save(...)` 다음 줄로 `WidgetRefresher.shared.reload()` 한 줄만 추가하면 된다.

## 검증

- `Tests/LazyMemoWidgetsCoreTests/WidgetThemeDefaultsTests.swift` 새로 작성 — App Group 거울이 비었을 때 `ThemeChoice.load()` 가 예전 `WidgetPaper.swift` 리터럴(라이트·다크·대비 높임 네 벌의 surface/card/ink/accent/onAccent/accentInk/highlightInk, 메모 잉크 여섯)과 숫자가 정확히 같은지 잰다. `./scripts/test.sh --filter LazyMemoWidgetsCoreTests` — 23 tests, 4 suites, 전부 통과 (기존 20개 + 신규 3개).
- `swift build` 성공.
- `cd ios && xcodebuild build -target LazyMemoWidgets -sdk iphonesimulator -arch arm64 SYMROOT=… OBJROOT=… CODE_SIGNING_ALLOWED=NO` — BUILD SUCCEEDED (상대경로 SYMROOT/OBJROOT 는 SwiftPM 하위 빌드가 다른 cwd 에서 다시 풀어 엉뚱한 자리에 흩는 문제가 있어 절대경로로 줬다).
- 같은 명령을 `-sdk macosx` 로 — BUILD SUCCEEDED (universal arm64+x86_64).
- 빌드 산출물 539MB, `rm -rf .build/ios-wtheme` 로 지웠다 (검증용 SYMROOT/OBJROOT, 저장소 기본 `.build` 밖에 따로 잡음).

## 메모

첫 시도에서 SYMROOT/OBJROOT 를 `../.build/ios-wtheme/...` 상대경로로 줬더니, 메인 xcodebuild 는 `ios/` 를 cwd 로 풀어 `lazymemo/.build/ios-wtheme` 를 썼지만 그 안에서 도는 SwiftPM 패키지 하위 빌드(`LazyMemoCore` 등)는 패키지 루트(`lazymemo/`)를 cwd 로 같은 상대경로를 풀어 `1dev/.build/ios-wtheme`(저장소 바깥!)에 흩었다 — "Unable to resolve module dependency" 로 실패. 절대경로로 주면 둘 다 같은 자리를 봐서 해결된다. 이 프로젝트에서 xcodebuild 에 SYMROOT/OBJROOT 를 줄 땐 항상 절대경로를 쓸 것.