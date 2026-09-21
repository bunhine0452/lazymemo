---
schema_version: 1
type: refactor
slug: "one-motion-vocabulary"
status: done
difficulty: medium
created_at: "2026-09-18T19:50:51+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/Motion.swift"
    op: create
  - path: "ios/LazyMemo/Motion.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyRecorder.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/RowTrash.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PlaceCards.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemo/PlaceCards.swift"
    op: update
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemo/PhotoCards.swift"
    op: update
related:
  - ref: "20260918/Chores/1950_chore_motion-ux-audit-2026-09-18.md"
    kind: "blocked_by"
  - ref: "20260831/Features_to_add/1834_feature_desktop-drawer-widget.md"
    kind: "followup"
tags:
  - "ux"
  - "motion"
  - "swiftui"
  - "accessibility"
  - "macos"
  - "ios"
  - "mcp-tool"
---
[x] 움직임의 낱말을 셋으로 — 여섯 가지 속도를 quick·settle·fly 한자리에 모으고 「움직임 줄이기」를 지키게 했다

## 동기

재질이 하나여야 화면이 한 물건으로 읽힌다(§14.5). 움직임도 같은데, 세어 보니 **같은 뜻의 움직임이 여섯 가지 속도**였다 — 서랍의 호버 `easeOut(0.14)`, 달력의 호버 `easeOut(0.18)`, 달력의 자리 옮김 `easeInOut(0.28)`, 자리 카드의 점 `.snappy`, 폰의 밝히기 `easeOut(0.6)`, 폰의 달 넘김 `.smooth(0.3)`. **우연히 비슷했을 뿐 같은 값이 아니어서, 한쪽을 고치는 사람은 다른 쪽이 있는 줄 몰랐다** — `PaperEdge` 가 「작아진 종이의 테두리 세기가 넷으로 갈려 있었다」로 배운 것과 같은 결함이다.

더 나쁜 것이 둘 있었다.

- **창과 내용이 각자 적고 있었다.** `DrawerWindowController.duration = 0.30` 과 `DrawerView.opening = timingCurve(0.22,0.9,0.24,1, duration: 0.30)` — 주석은 「짝이다」라고 적어 두고 값은 두 파일에 나눠 놨다. 한쪽만 고치면 «내용이 먼저 나오고 창이 뒤따라 커지는» 한 프레임 잘림이 돌아온다.
- **「움직임 줄이기」를 절반만 지켰다.** 서랍과 폰 달력은 `accessibilityReduceMotion` 을 보는데, 맥 달력·`RowTrash`·`HotkeyRecorder`·자리 카드·폰의 목록/펜/시트/안내는 **환경값을 읽지도 않았다.**

## 변경 요약

`Motion` 한자리 — 맥 `Sources/LazyMemoUI/QuickCapture/Motion.swift`, 폰 `ios/LazyMemo/Motion.swift`. **두 기기가 같은 숫자를 본다.**

| 낱말 | 무엇에 | 값 |
|---|---|---|
| `quick` | 값 하나 — 손이 얹힘, 강조, 칩이 서고 물러남 | `.smooth(0.18)` |
| `settle` | 자리를 잡는 것 — 목록이 바뀜, 달 판이 미끄러져 앉음 | `.smooth(0.30)` |
| `fly` | 창·판이 통째로 — 서랍이 펼쳐지고 접힘 | `timingCurve(0.22,0.9,0.24,1, 0.30)` |

- **스프링이되 튕기지 않는다** (`.smooth` = bounce 0). 종이는 고무가 아니고, 열 장이 겹친 바탕화면에서 튕기는 종이는 어지럽다. 스프링인 이유는 곡선이 아니라 **가로채기** 다 — 끝나기 전에 값이 또 바뀌면 지금 속도를 이어받는다 (WWDC18 803 "Allow for constant redirection and interruption").
- `Motion.quick/settle/fly(_ reduced:)` 가 **끄지 않고 바꾼다** — 자리를 옮기는 것은 `instant`(0.01), 드러나고 물러나는 것은 `crossFade`(0.12). HIG Accessibility "Replacing transitions in x-, y-, and z-axes with fades". 아예 끄면 무엇이 새로 생겼는지 알 길이 사라진다.
- 창은 `Motion.flyDuration`·`Motion.flyTiming` 을 본다 — `DrawerWindowController` 와 `DrawerView` 가 **같은 한 값**을 읽는다.
- **수식어를 겹겹이 쌓지 않는다.** 빠른 입력의 루트에 열 겹, 서랍에 여덟 겹이던 `.animation` 을 값 묶음(`BubbleKey`·`PanelKey`·`HoverKey`·`PenKey`) 하나씩으로 줄여 한 겹으로. 값이 늘어도 겹은 안 는다.
- **도형을 갈아 끼우지 않는다.** 빠른 입력의 줄 자국과 폰 시트의 시각 칩이 `if/else` 로 서로 다른 뷰를 세우고 있어서, 누를 때마다 자국이 사라졌다 새로 생겼다 — 색이 이어지지 않는 까닭이었다. 도형 하나에 색만 바꾼다.

`Views/Theme.swift` 의 `reveal`·`settle` 은 다른 세션이 잡고 있어 손대지 못했다 — 두 벌로 남아 있고 값도 0.28↔0.30 으로 어긋난다. 넘길 것으로 적어 두었다 (감사 문서 §7).

## 검증

- `swift build` 통과, 내 파일에 오류·경고 0.
- `./scripts/test.sh --filter LazyMemoUITests` — 377 tests / 56 suites. 15 이슈는 전부 다른 세션의 테마 시험 넷(`ThemeContrastTests`·`PaperPaletteTests`)이고, 내 구역 스위트(서랍·빠른 입력·자리·Esc·말풍선 자리)는 전부 초록.
- `scripts/verify-drawer.sh` ✓ · `verify-drawer-mouse.sh` ✓ (합성 마우스: 탭 잡아 끌기 Δ120,80 · 누르기 → 펼침 440×344 · 머리 줄 끌기 Δ-100,-60 · × 접힘 · 바깥 클릭 접힘) · `verify-capture.sh` ✓ · `verify-capture-dismiss.sh` ✓.

## 메모

폰 스모크는 다른 세션의 `themedUIColor` 크래시(`ios/LazyMemo/Theme.swift`)에 막혀 23 중 6 이 빨갛다 — `UIColor { traits in … }` 공급자가 메인 밖에서 불릴 때 격리 검사가 트랩을 건다. 스택은 감사 문서 §6.1 에 그대로 적었다.