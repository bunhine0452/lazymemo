---
schema_version: 1
type: feature
slug: "desktop-level-window-spike"
status: done
difficulty: high
created_at: "2026-08-28T16:54:39+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemo/Windows/DesktopLevelWindow.swift"
    op: create
  - path: "Sources/LazyMemo/Spike/DesktopWindowSpike.swift"
    op: create
  - path: "Sources/LazyMemo/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemo/AppDelegate.swift"
    op: update
  - path: "scripts/verify-window.swift"
    op: create
  - path: "scripts/verify-window.sh"
    op: create
related: []
tags:
  - "nswindow"
  - "window-level"
  - "cgwindowlist"
  - "nshostingview"
  - "swiftui"
  - "glass-effect"
  - "spike"
  - "mcp-tool"
---
[x] 바탕화면 레벨 NSWindow 스파이크 — 스크린샷 권한 없이 창 레벨을 기계 검증

설계문서 §7 이 "프로젝트 최대 리스크"로 지목한 영역의 첫 단추. `{#desktop-window}` 를 끝냈고, 나머지 세 항목(Stage Manager · 월페이퍼 클릭 · 다중 디스플레이)은 사람 조작이 필요해 도구만 준비했다.

## 추가 기능

**`DesktopLevelWindow`** — 설계문서 §7 의 창 속성을 한 클래스에 모았다. 메모당 하나씩 생기므로(D2) 여기서 정한 것이 곧 프로젝트 전체의 창 동작이 된다.

- `level = desktopIconWindow + 1` — 바탕화면 아이콘 위, 일반 창 아래
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` — `.ignoresCycle` 은 설계문서에 없던 추가분이다. 메모가 수십 개가 되면 ⌘Tab 창 순환을 오염시키기 때문.
- `canBecomeKey` 를 `true` 로 연다 — borderless 창은 기본적으로 키가 못 되는데, §8 대로 메모 안에서 글을 쓰려면 필요하다. 반대로 `canBecomeMain` 은 닫아 둔다.
- `isReleasedWhenClosed = false` — 저장 버튼이 없는 앱이라 "창을 닫는다 = 메모를 숨긴다"이다. 시스템이 임의로 해제하면 안 된다.

**스파이크 창** — 그냥 떠 있는 창이 아니라 **무슨 일이 일어났는지 세어 보여주는 창**으로 만들었다. Stage Manager·Mission Control·월페이퍼 클릭은 코드로 흉내 낼 수 없어 사람이 조작해 봐야 하는데, 조작 후 "창이 살아 있나"만으로는 판단 근거가 약하다. 그래서 창 레벨·디스플레이 이름·좌표와 함께 Space 전환 횟수, 디스플레이 구성 변경 횟수, 마지막 이벤트를 실시간으로 띄운다.

SwiftUI `.glassEffect(.regular, in: .rect(cornerRadius: 20))` 가 SDK 26.5 에서 실제로 컴파일·렌더된다는 것도 여기서 처음 확인했다 (설계문서 §3 은 컴파일까지만 검증했었다).

## 동작 흐름

메뉴바 → "바탕화면 창 스파이크" 토글, 또는 `LAZYMEMO_SPIKE=1` 환경변수로 기동 시 자동 오픈. 후자는 자동 검증용 진입점이다.

## 알아낸 것 1 — 스크린샷 권한 없이 창을 검증하는 법

이 터미널에 화면 기록 권한이 없어 `screencapture` 가 `could not create image from display` 로 거부된다. 창이 실제로 화면에 올라왔는지 눈으로 볼 방법이 없다는 뜻이다.

`CGWindowListCopyWindowInfo` 는 **창 제목만** 화면 기록 권한을 요구하고 창 번호·레벨·좌표·알파는 권한 없이 읽힌다. 이걸로 `scripts/verify-window.swift` 를 짰다. 함정 하나: `kCGWindowListExcludeDesktopElements` 옵션을 쓰면 바탕화면 레벨 창이 통째로 걸러진다 — 정확히 우리가 찾는 창이므로 옵션 없이 전체를 훑어야 한다.

Python + PyObjC 로 먼저 시도했으나 시스템 python3 에 Quartz 모듈이 없어 Swift 스크립트로 갈아탔다. Swift 프로젝트에 Python 의존을 들이지 않는 편이 맞기도 하다.

## 알아낸 것 2 — NSHostingView 가 창 크기를 끌고 간다

첫 검증에서 창이 **340×380 이 아니라 340×1082** 로 나왔다. 화면 세로 끝까지 늘어난 것이다.

원인은 `NSHostingView.sizingOptions` 의 기본값이 SwiftUI 뷰의 이상적 크기를 창에 반영한다는 것. 카드 뷰에 쓴 `.frame(maxHeight: .infinity)` + `Spacer` 조합이 "무한히 크고 싶다"는 신호가 되어 창을 늘렸다. `init(contentRect:)` 로 준 크기는 `contentView` 를 붙이는 순간 덮인다.

`hosting.sizingOptions = []` 로 끄고, `contentView` 를 붙인 **뒤에** `setFrame` 을 호출하는 순서로 고쳤다.

이건 스파이크 한정 문제가 아니다. 창 크기는 `layout.json` 이 정본이 될 값인데(설계문서 §5.1), 뷰가 크기를 끌고 가면 `{#note-interaction}` 의 위치·크기 복원이 조용히 깨진다. 지금 잡아서 다행이고, `{#note-window}` 에서 같은 순서를 따라야 한다.

## 검증

- `./scripts/verify-window.sh` → `window #23661 level=-2147483602 bounds=(1132, 73 340×380) alpha=1.00`, 기대 레벨 `desktopIconWindow(-2147483603) + 1` 과 일치. 수정 전에는 같은 스크립트가 `340×1082` 를 뱉었다.
- `swift build` 경고 0.
- **사용자 육안 확인 대기** — 창이 실제로 보이는지, Stage Manager / Mission Control / 월페이퍼 클릭 / 다중 디스플레이에서 어떻게 동작하는지는 `{#env-stage-manager}` `{#env-wallpaper-click}` `{#multi-display}` 로 남아 있다.