---
schema_version: 1
type: refactor
slug: "paper-words-in-the-dark"
status: done
difficulty: high
created_at: "2026-08-31T13:05:11+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MemoRow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarInk.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PhotoStrip.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperPaletteTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/MemoRowTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CalendarInkTests.swift"
    op: update
related: []
tags:
  - "design"
  - "dark-mode"
  - "palette"
  - "a11y"
  - "mcp-tool"
---
[x] 어둠에서도 종이의 낱말로 — 붉은 기둥·시스템 파랑·같은 숯색 여섯 장

## 동기

화면이 종이의 낱말을 쓴다는 약속이 **네 자리에서 새고 있었다.** 넷 다 "그림을 흘긋 봐서는 좀 이상한가 까지밖에 말할 수 없는" 종류라 재서 못 박는 쪽으로 갔다.

1. **다크 모드에서 여섯 색이 다시 같은 종이가 됐다.** 빛 모드에서 한 번 고친 비율(밝기를 맞추고 섞기) 한 벌을 두 외관이 함께 쓰고 있어서, 숯색 바탕에서 같은 일이 반복됐다 — 무채와 노랑의 거리가 빛 모드의 절반 이하였다.
2. **빠른 입력 목록의 붉은 휴지통 다섯 개가 세로 기둥을 이뤘다.** 적으러 연 사람에게 화면이 가장 눈에 띄는 자리에서 "지워라" 를 다섯 번 말한다.
3. **메뉴 목록만 시스템 파랑으로 강조됐다.** 이 목록만 남의 앱에서 잘라 온 부품처럼 보였고, 같은 메모를 빠른 입력과 다르게 그렸다.
4. **달 격자의 잉크 얼룩이 인쇄 얼룩처럼 보였다.** 1개와 4개의 지름 차이가 30%, 세기 차이가 25% 뿐이라 나란히 놓아도 같아 보였다 — 그러면 얼룩은 "붐빈다" 를 말하지 못하고 종이에 묻은 자국으로만 남는다.

## 변경 요약

- **`PaperTint` 신설** — 잉크를 종이로 눕히는 계산을 뷰 밖으로 뺐다. 스밈·채도 상한·밝기를 `light`/`dark` 로 **따로** 잡는다(어두운 종이는 색을 더 먹어야 색으로 보인다). 잉크 자체도 하나 손봤다: 보라와 파랑이 색상환에서 47° 밖에 안 떨어져 늘 가장 닮은 쌍이었다 — 종이에 스미면 채도가 절반 아래로 눌리므로 잉크에서 미리 벌려 둔다.
- **글자 색과 면 색을 갈랐다** — `accent`/`accentInk`, `danger`/`dangerInk`. 딥 네이비는 미색 종이에서 11:1 인데 숯색 종이에서는 1.6:1 이라 「되돌리기」가 바탕에 잠겨 있었다. 주말 숫자(일요일 빨강·토요일 파랑)도 다크에서 밝은 쪽으로 올렸다 — 관행을 지키려던 색이 그 이틀을 가장 안 읽히는 칸으로 만들면 안 된다.
- **휴지통은 손이 닿았을 때만 붉다** (`RowTrash`). 평상시에는 종이의 잉크색.
- **메뉴의 골라진 줄은 그 메모의 종이색** (`MemoRow.highlightFill`). 글자 색은 함께 뒤집지 않는다 — 옅은 바탕이라 잉크가 그대로 읽히고, 뒤집으면 여덟 줄 중 한 줄만 다른 재질이 된다.
- **얼룩의 폭과 대비를 벌렸다** — 반지름 `0.14+0.12s → 0.11+0.22s`, 세기 `0.46+0.30s → 0.30+0.58s`. 한 건은 슬쩍 밴 자국, 네 건은 종이가 젖을 만큼.
- **VoiceOver 가 읽을 이름을 줬다** (`SpokenHelp`, `.spoken(_:)`). 새 낱말을 만들지 않고 이미 붙은 도움말을 가른다 — 「—」 앞이 이름, 뒤가 힌트. 여러 조각으로 된 줄(목록 한 줄, 달력 칸, 사진)은 하나로 묶어 읽힌다.

## 검증

`PaperPaletteTests` 6건 신설 — 여섯 장에서 **가장 닮은 두 장의 거리**를 두 외관에서 각각 재고, 어두운 쪽이 밝은 쪽만큼 갈리는지, 무채가 무채로 남는지, 여섯 장 모두에서 글이 4.5:1 을 넘는지, 바랜 종이도 여전히 그 색인지. 고치기 전 값으로 돌리면 빛(0.044)·어둠(0.036) 둘 다 떨어진다. `MemoRowHighlightTests` 3건, `SpokenHelpTests` 3건, 얼룩 2건 추가. 전체 377개 통과.

`palette.png`·`menu.png`·`capture-recent.png`·`calendar.png` 를 라이트/다크로 다시 렌더해 눈으로 확인 — 다크의 여섯 장이 갈리고, 붉은 기둥이 사라지고, 강조가 종이색이고, 1개와 4개의 얼룩이 구별된다. 성능 예산(RSS 87MB / idle 0%)과 빠른 입력 지연(중앙값 6.9ms) 그대로.