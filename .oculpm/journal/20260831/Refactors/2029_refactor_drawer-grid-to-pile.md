---
schema_version: 1
type: refactor
slug: "drawer-grid-to-pile"
status: done
difficulty: high
created_at: "2026-08-31T20:29:16+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Drawer/DrawerGeometry.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260831/Bugs/2002_bug_flaky-paste-diagnostic.md"
    kind: "followup"
tags:
  - "drawer"
  - "ux"
  - "redesign"
  - "philosophy"
  - "mcp-tool"
---
[x] 서랍을 격자에서 종이 무더기로 다시 그렸다 — 가리는 대신 연다

사용자가 서랍을 보고 **디자인과 UX 를 강하게 거절했다.** 다른 세션(`lazymemo-0c`)이 만든 것인데 그 세션이 끝나 내가 이어받았다.

## 동기 — 이 앱이 스스로 세운 규칙을 서랍만 어기고 있었다

| 무엇이 | 왜 나빴나 |
|---|---|
| 머리글(`서랍 · 8장`)과 꺾쇠 버튼 | 이 앱의 어느 종이에도 없다. 철학 4 를 서랍만 어기니 **서랍만 «앱처럼»** 보였다 |
| 색 칩 격자 | §16.2 가 *「한꺼번에 나타나면 «내용물» 이 아니라 «격자» 로 읽힌다」* 고 **스스로 경고해 놓고**, 애니메이션만 한 장씩이고 멈춘 상태는 그냥 격자였다 |
| 타일마다 제목 한 줄 | 여덟 장이 색으로만 갈렸다. 찾으려면 하나씩 눌러야 했는데 **메뉴 목록이 여덟 줄을 한눈에 보여주고 클릭도 적다** — 이미 있는 것보다 나쁜 화면 |
| 폴더 그림에 크게 적힌 「8장」 | 128×108 을 쓰고 하는 말이 숫자 하나. 메뉴가 이미 「치워 둔 N장」으로 말한다 |
| 호버 `scaleEffect(1.06)` | 6%는 눈에 안 띈다. **무엇을 누르게 되는지 말 못 하는 표시는 없는 것과 같다** |

## 변경 요약

**격자를 버리고 겹쳐 쌓았다.** 띠(30pt)만큼씩 어긋나 겹치므로 **여덟 장의 첫 줄이 동시에 읽힌다.**

**닫힌 상태**는 폴더 그림을 걷고 종이만 그린다 — 맨 위 한 장이 첫 줄을 들고, 아래 세 겹이 계단으로 두께를 말한다. 숫자는 안 적는다.

**머리글을 없앴다.** 접는 길은 종이의 × 와 같은 자리·같은 규칙(손이 왔을 때만 오른쪽 위)으로 옮겼다.

**호버는 가리지 않고 연다.** 처음엔 얹힌 장을 맨 위로 올렸는데, 그러면 **그 위에 있던 장들이 왼쪽 슬라이버로 뭉개졌다** — 격자가 안 읽히던 문제를 그대로 다시 만드는 일이다. 지금은 **아래 것들이 밀려 내려가** 얹힌 장이 제자리에서 통째로 드러난다(`DrawerGeometry.fan`). 위의 것들은 첫 줄을 그대로 든다. 창은 그 한 번을 위한 자리를 늘 비워 둔다 — 손이 왔을 때 창이 커지면 「열린다」가 아니라 「창이 튄다」로 보인다.

**통째로 보이는 장은 글도 보인다** — 무더기의 맨 위 한 장과 얹힌 한 장. 가려진 장에 본문을 그리면 읽을 수 없는 회색 줄무늬가 될 뿐이다.

## 고친 결함 둘

1. **닫힌 무더기의 두께가 한 겹만 보였다.** 두 원인이 겹쳤다 — `peekingInks` 가 맨 위 종이 자신을 포함해 같은 종이를 두 번 그렸고, 아래 장을 더 작게 만들면서 더 밀어 둬서 오른쪽 아래 끝이 한 자리에 모여 서로를 통째로 덮었다. `dropFirst` 와 **같은 크기·계단 자리**로 고쳤다.
2. **펼친 종이가 창 위로 잘려 제목이 안 보였다.** 무더기의 그 장을 `opacity(0)` 으로 두니 같은 id 를 가진 뷰가 둘이 되어 `matchedGeometryEffect` 가 펼친 종이를 무더기 자리에 놓았다. `isSource: !hidden` 으로 원본을 지정해 고쳤다.

## 시험이 한 번 나를 막았다

종이를 213pt 로 키웠더니 `tilesAreVisiblySmaller` 가 걸렸다 — 자라는 배율이 1.22배라 **누른 것이 자란 것으로 안 보인다.** 앞서 격자 기준(0.6)을 한 번 완화했던 시험이라 **또 완화하지 않고 종이를 200pt 로 줄였다**(1.30배). 시험이 지키는 것은 숫자가 아니라 «누른 것이 눈에 보이게 달라진다» 이고, 그 뜻은 판형이 바뀌어도 그대로다.

## 검증

`./scripts/test.sh` **599개 통과**. `verify-drawer`·`verify-notes`·`verify-capture-paste` 통과. 빌드 경고 0. `render-ui.sh` 로 라이트·다크 넉 장 확인 — 닫힘(첫 줄 + 세 겹 두께), 펼침(부채꼴로 한 장이 열리고 나머지 첫 줄이 다 읽힘), 펼친 한 장(제목까지 온전).

## 메모

**부채꼴 자리를 늘 비워 두는 값을 치른다** — 아무것도 안 얹혔을 때 창 아래가 124pt 비어 보인다. 가리지 않으려면 그만큼의 자리가 어딘가에 있어야 하고, 겹친 무더기에서 그 자리는 아래뿐이다. 써 보고 거슬리면 다시 볼 것.

`lazymemo-0c` 가 세운 것 중 이건 그대로 살렸다 — `DrawerContents` 의 한 문장 규칙(「지금 바탕화면에 없는, 날짜 없는 종이」), 새 필드 0개, 서랍 안에서는 읽기만, 창 프레임과 SwiftUI 움직임의 시간 일치, §16.3 의 「모서리 하나는 그대로 남는다」.