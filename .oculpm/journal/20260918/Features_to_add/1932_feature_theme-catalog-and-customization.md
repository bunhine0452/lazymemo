---
schema_version: 1
type: feature
slug: "theme-catalog-and-customization"
status: done
difficulty: high
created_at: "2026-09-18T19:32:26+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Theme/ThemeColor.swift"
    op: create
  - path: "Sources/LazyMemoCore/Theme/ThemeSpec.swift"
    op: create
  - path: "Sources/LazyMemoCore/Theme/ThemeCatalog.swift"
    op: create
  - path: "Sources/LazyMemoCore/Theme/ThemeOverrides.swift"
    op: create
  - path: "Sources/LazyMemoCore/Theme/ThemeRuntime.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/ThemeStore.swift"
    op: create
  - path: "Sources/LazyMemoUI/Settings/ThemeSection.swift"
    op: create
  - path: "Sources/LazyMemoUI/Settings/SettingsScreen.swift"
    op: update
  - path: "Sources/LazyMemoUI/Settings/SettingsWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/Theme.swift"
    op: update
  - path: "ios/LazyMemo/ThemeModel.swift"
    op: create
  - path: "ios/LazyMemo/ThemeSettingsView.swift"
    op: create
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "Tests/LazyMemoCoreTests/ThemeCatalogTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/ThemeOverridesTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/ThemeContrastTests.swift"
    op: create
  - path: "scripts/render-settings.sh"
    op: update
  - path: "docs/VISUAL_DESIGN.md"
    op: update
related: []
tags:
  - "theme"
  - "색"
  - "설정"
  - "접근성"
  - "대비"
  - "mcp-tool"
---
[x] 테마 여덟 벌과 커스터마이징 — 색을 한 곳에 모으고, 고른 색은 읽히는 데까지 되끌어 올린다

## 추가 기능

사용자: 「테마를 여러게 정할수있게하고 사용자가 원하는 방법대로 커스터마이징 할수 있게한다.」

**색이 세 곳에 따로 적혀 있었다** — 맥(`Views/Theme.swift`)·폰(`ios/LazyMemo/Theme.swift`)·위젯(`WidgetPaper.swift`). 같은 숫자 세 벌이라 한쪽을 고치면 나머지가 조용히 어긋난다. 테마를 여럿 두려면 먼저 그것을 한 곳으로 모아야 했다.

- **카탈로그 한 곳** (`LazyMemoCore/Theme/`): 여덟 벌 — 크림과 포레스트(기본) · 미드나잇 · 세피아 · 흑백 잉크 · 봄 파스텔 · 숲속 어둠 · 바다 · 장미. 한 벌은 빛·어둠 두 종이와 (손으로 안 잡으면 자동으로 지어지는) 대비 높임 두 벌, 그리고 여섯 메모 잉크를 든다.
- **기본 테마의 숫자는 앞선 판 그대로다.** 한 번도 고르지 않은 사람에게는 아무것도 달라지지 않는다 — `ThemeCatalogTests` 가 그 숫자를 따로 적어 두고 대조한다.
- **커스터마이징 넷**: 강조색 · 종이에 스미는 색 · 글자 크기(-1…+2) · 종이 결. 맥은 설정 창의 「테마」 절, 폰은 시트.
- **고른 색이 글을 가리면 되끌어 올린다.** 색은 이 앱에서 장식이 아니라 읽히는 일이라(§8.2), 얹은 것은 전부 바닥(WCAG AA) 위로 올린 뒤 쓴다.

## 동작 흐름

1. `ThemeRuntime`(잠금 하나로 지키는 전역)이 지금 쓰는 한 벌을 든다. 그리는 닫힘(`NSColor(name:)`·`UIColor { traits }`)은 아무 스레드에서나 불리므로 메인에 매인 것을 볼 수 없다 — 값은 여기서 읽는다.
2. `Theme.*`·`Paper.*` 의 **API 표면은 그대로 두고**(부르는 자리가 칠백 곳이다) 안쪽만 동적으로 바꿨다. `NSColor`/`UIColor` 객체는 **하나로 고정**한다 — 마크다운 칠하기가 글자에 색 *객체* 를 물려 두므로(`MarkdownStyler`), 테마마다 새 객체를 만들면 이미 칠해 둔 글이 옛 색에 남는다.
3. 다시 그리게 하는 일만 관찰 대상이 맡는다(`ThemeStore`·`ThemeModel`). 색을 돌려주는 계산 속성이 `Theme.track()` 을 스치고 가서, SwiftUI 가 본문을 부르는 동안이면 `generation` 을 읽은 것이 된다 — 칠백 곳을 고치지 않고 다시 그려진다. AppKit 뷰는 스스로 안 깨므로 창의 `needsDisplay` 를 세운다.
4. **어두운가는 외관이 아니라 테마가 말한다**(`ThemeVariant.darkPaper`). 「미드나잇」·「숲속 어둠」은 빛 모드에서도 어두운 종이라, 가장자리의 두께·그림자·잉크를 종이로 눕히는 비율(`PaperTint`)·주말 색·지우기의 붉은색을 `colorScheme` 으로 고르면 그 테마에서만 전부 뒤집힌다.
5. 유도 규칙 — 고른 강조색은 **면**이고, 그 위의 글자는 그 면 위에서 4.5:1 까지 민 것, 종이 위의 글자로 쓸 때는 종이 반대쪽으로 가라앉힌 것. 종이 색은 16% 만 스미되 잉크가 4.5:1 아래로 내려가면 2%씩 물러난다.
6. 정본은 `settings.json` 의 `theme`(id 한 줄)·`themeOverrides`(색은 `"#295245"` 한 조각). App Group 의 defaults 에 거울을 둔다(`ThemeChoice`) — 위젯이 `settings.json` 을 열지 않기 때문이고, 앱이 뜰 때 읽는 것도 이 거울이다.

## 검증

`swift build` · `./scripts/test.sh --filter "LazyMemoCoreTests|LazyMemoUITests"` → 881개 전부 초록(새 시험 17+7개 포함 — 여덟 테마 × 네 외관에서 종이 위의 글 여덟 자리가 바닥 위인가, 얹은 뒤에도 그런가, 여섯 장이 나란히 놓여 갈리는가 ΔE>5). iOS 는 `.build/ios-theme` 로 빌드 성공 후 지웠다. `check-l10n.sh` 에서 내 열쇠는 빠짐 0(남은 23개는 다른 세션의 진행 중 파일 — PreviewRenderer·DemoTour·QuickCaptureModel).

**손으로 걸었다**: 설정 창을 띄워 접근성으로 견본을 눌렀더니 바탕화면의 종이가 **그 자리에서** 미색 → 숯색으로 바뀌었다(`screencapture -l` 로 전후를 떠서 확인 — `NSTextView` 의 글자색까지 따라왔다). 거울을 손으로 적고 다시 띄우니 강조색(#B0382E)·종이 색·글자 한 칸(+2, 창이 478 → 649pt 로 자람)이 그대로 섰다.

## 메모

- **맥은 아직 `settings.json` 에 안 적는다** — `ThemeStore.attach(settings:)` 를 부를 한 줄이 `AppDelegate.open` 에 필요하고 그 파일은 내 담당이 아니다. 지금도 거울로 다시 켜도 남지만, 파일이 정본이 되려면 그 한 줄이 있어야 한다(오케스트레이터에게 보고).
- 설정 창의 「직접 고르기」 패널은 상태를 열어 둔 채 렌더해 눈으로 확인했다. 합성 마우스로는 `DisclosureGroup` 이 열리지 않았다 — 접근성 값·좌표 클릭 모두 안 먹었다. 왜인지는 못 밝혔다.
- `scripts/render-settings.sh` 가 같은 파일을 두 번 찍으면 **옛 그림을 그대로 두고 끝났다**(기다림이 「파일이 생겼는가」였다). 먼저 지우게 고쳤다. 라이트·다크를 한 번에 찍도록 `LAZYMEMO_SETTINGS_APPEARANCE` 도 열었다.