---
schema_version: 1
type: feature
slug: "thick-paper-materiality"
status: done
difficulty: high
created_at: "2026-09-01T12:13:25+09:00"
session_id: "20260901-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PhotoStrip.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerPaper.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MemoRow.swift"
    op: update
  - path: "Tests/LazyMemoUITests/PaperPaletteTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "design"
  - "palette"
  - "dark-mode"
  - "paper"
  - "typography"
  - "mcp-tool"
---
[x] 두꺼운 종이 — 다크 팔레트를 색 판에서 되돌리고, 가장자리와 그림자에 물성을 준다

세 가지 시각 방향(두꺼운 종이 / 가장자리에만 색 / 먹과 자)을 비교 시트로 그려 사용자가 **「두꺼운 종이」** 를 골랐다. 언어는 그대로 두고 물성만 올리는 판이다.

## 추가 기능

**1. 다크 팔레트의 방향을 뒤집었다** (`PaperTint.dark`)

앞선 배합은 밝기 0.50 짜리 색을 36% 섞었다. 여섯 장이 맨 종이보다 L\* 11 이나 밝고 채도는 빛 모드의 두 배 — 나란히 놓으면 잘 갈렸지만 한 장씩 보면 올리브·자주·적갈색 **색 판**이었다. 「종이는 거의 미색이고 색은 그 위에 스밀 뿐」이라는 규칙을 어둠에서만 어기고 있었다.

밝기 0.28 / 채도 상한 0.68 / 스밈 0.28 로 바꾼다 — **어두운 색을 짙게 만들어 조금 섞는다.** 종이는 맨 종이에서 L\* 2.6 만 떠오르고 채도는 절반이 된다.

**2. 그 압력을 만든 것은 시험의 잣대였다** (`PaperPaletteTests`)

거리를 sRGB 위에서 쟀는데 그 값은 감마가 씌워진 저장용 숫자라 어두운 자리를 과소평가한다. 그래서 «어둠도 빛만큼 갈려라» 가 사실상 «어둠에서는 색을 더 먹어라» 로 읽혔고, 통과하는 유일한 길이 종이를 진하게 칠하는 것이었다. **CIE Lab 의 ΔE 로 옮겼다** (손으로 적은 변환 — 시스템에 맡기면 어느 외관에서 해석됐는지가 값에 섞인다). 바닥은 JND 두 걸음인 5.0.

갈리라는 압력만 두면 다시 진해지므로 반대쪽 못을 하나 더 박았다 — `darkPapersStayNearTheBase`: 어두운 종이는 맨 종이에서 L\* 6 넘게 떠오르면 안 된다.

**3. 가장자리에 두께** (`PaperEdge`)

사방을 같은 세기(잉크 10%)로 두르던 것을 위아래로 갈랐다. 빛은 위에서 오므로 윗변은 밝고 아랫변은 제 두께에 가려 어둡다. 선은 굵히지 않는다 — 굵은 테두리는 종이가 아니라 카드가 된다. 세기는 외관마다 따로: 어두운 종이 위에서 흰 선을 빛 모드만큼 밝히면 두께가 아니라 광택이 된다.

**4. 그림자 두 겹** (`RaisedSurface`, `DrawerPaper`, `DrawerView`, `PhotoStrip`)

한 겹으로는 «닿아 있음» 과 «떠 있음» 을 흐림 하나로 말해야 한다. 닿는 자리에 좁고 진한 그림자, 그 둘레로 넓고 옅은 그림자. 서랍에서 한 장이 들릴 때는 **두 겹이 반대로 움직인다** — 닿는 쪽이 옅어지고 퍼지는 쪽이 자란다. 한 겹이면 «진해지면서 퍼지는» 한 방향뿐이라 들린 것이 아니라 커진 것으로 보였다.

**5. 꼬리의 숫자는 등폭** (`Theme.micro`/`.label`, `MemoRow.timeFont`)

비례 숫자는 `1` 이 좁아 「오늘 11:00」과 「오늘 9:30」의 오른쪽 끝이 줄마다 어긋난다. 고정폭 글꼴로 갈아 끼우지는 않는다 — 그 글꼴에 한글이 없어 한 줄에 두 얼굴이 섞인다. `monospacedDigit()` 로 **같은 얼굴의 숫자만** 등폭으로.

곁들여: 점 그리드를 물리고(0.28→0.22, 다크 0.30→0.26) 종이 결을 그만큼 올렸다(0.16→0.20). 가장자리가 종이를 물건으로 만들기 시작했으므로 격자는 물러나도 된다.

## 검증

- `./scripts/test.sh` — 604개 전부 통과. 다시 쓴 팔레트 시험 포함 (빛 ΔE 6.11 / 어둠 6.00, 비율 0.98, 맨 종이에서 최대 +L\* 4.9).
- `./scripts/render-ui.sh build/ui-thick` — 라이트·다크 22장 렌더. 이전 판(`build/ui5`)과 겹쳐 놓고 확인: 다크 여섯 장이 색 판에서 물든 숯색 종이가 됐고 서랍에서 여전히 갈린다. 모서리 확대에서 윗변 밝은 선·아랫변 어두운 선, 캡슐 아래 접촉 그림자가 보인다.
- 종이 투명도를 내린 판(`note-sheer.png`)에서 흰 가장자리가 튀지 않는 것까지 확인.