---
schema_version: 1
type: refactor
slug: "drawer-hover-grow-and-empty-room"
status: done
difficulty: medium
created_at: "2026-09-01T11:09:21+09:00"
session_id: "20260901-001"
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
  - path: "Sources/LazyMemoUI/Drawer/DrawerPaper.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerContents.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260831/Refactors/2029_refactor_drawer-grid-to-pile.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1834_feature_desktop-drawer-widget.md"
    kind: "followup"
tags:
  - "drawer"
  - "ux"
  - "animation"
  - "hover"
  - "layout"
  - "mcp-tool"
---
[x] 서랍 디자인을 다듬었다 — 호버는 커지기만 하고, 판을 빈자리에 저당 잡히지 않는다

사용자 요청: 서랍(바탕화면 폴더 위젯)의 **디자인 업그레이드.** 기능·상호작용 모델은 그대로 두고 생김새와 판형만 손봤다.

## 동기 — 판의 4분의 1이 늘 비어 있었다

호버가 클릭의 일을 하고 있었다. 손이 얹힌 한 장을 **통째로** 드러내려고 아래 것들을 `sheet.height - band`(124pt) 만큼 내렸는데, 그러려면 창이 그 124pt 를 **늘 비워 두고** 있어야 했다.

| 언제 | 무엇이 보였나 |
|---|---|
| 손을 치웠을 때 | 판의 아래 4분의 1이 빈 채로 남는다 |
| 한 장을 원래 크기로 되돌렸을 때 | 그 빈자리가 **판의 절반**이 된다 (`drawer-zoomed`) |

앞선 세션도 이것을 알고 있었다 — 일지에 *"부채꼴 자리를 늘 비워 두는 값을 치른다 … 써 보고 거슬리면 다시 볼 것"* 이라고 적어 두었다. 거슬렸다.

## 변경 요약

**호버는 커지기만 한다.** 사람이 부탁한 것이 그것이다 — "호버시 잠깐 커지게". 벌어지는 자리를 124pt → **44pt** 로 줄이고, 대신 그 장이 6% 커지고(`hoverScale`) 옆으로 밀려 나온다. 띠가 30pt 에서 80pt 남짓으로 벌어지며 **제목 밑에 잠들어 있던 두 줄이 그 자리에서 드러난다.** 판형이 154pt 짧아졌고 빈자리가 사라졌다.

**닫힌 무더기가 비뚤어졌다.** 계단만으로 쌓았더니 사각형 넷이 자로 잰 듯 겹쳐서 바탕화면에서 그것이 **그림자 진 카드 한 장**으로 보였다 — 메모 한 장과 구별되지 않았다. 몇 도씩 어긋나게 하니 그 순간 «여러 장» 이 됐다. 손이 오면 무더기가 **느슨해진다**(각도가 벌어지고 계단이 넓어진다) — 크기 3%보다 이쪽이 «누를 수 있다» 를 훨씬 잘 말하고, 펼쳤을 때 무엇이 나올지까지 미리 말한다. 종이가 위에 떠 있으면 가장 크게 벌어진다.

**되돌린 종이 뒤가 흐려진다.** 뒤에 또렷한 제목 여덟 줄이 그대로 있으면 눈이 둘로 갈리고, 그러면 앞의 종이는 «펼쳐진 것» 이 아니라 «위에 얹힌 딴것» 으로 보인다.

**「그리고 N장 더」.** 판형은 `scrolls` 로 넘침을 이미 셈해 놓고도 화면에서는 한마디도 하지 않고 있었다. 설계문서가 *「조용히 자르지 않는다」* 고 적어 둔 그 자리가 비어 있었다.

**작은 장에도 도트 그리드를 깔았다.** 빼 두었더니 벌어진 자리에서 글 없는 종이가 «빈 종이» 가 아니라 **색 덩어리**로 보였다 — 이 앱의 재질은 종이 하나인데(§14.5) 작은 장만 칩이 됐던 것이다.

## 그림에서 «디자인» 처럼 보이던 고장 둘

1. **덮인 몸통이 옆으로 빠져나왔다.** 종이를 늘 154pt 로 그려 두었더니 6% 커질 때 가려져 있던 아래쪽까지 같이 넓어져서, 다음 장들 오른쪽으로 색 띠 하나가 154pt 내내 삐져나왔다. 묻힌 장은 **보일 수 있는 만큼만** 그린다 (`DrawerGeometry.peek = band + lift`).
2. **띠에 걸린 글자가 한가운데서 잘렸다.** 30pt 짜리 띠 밑에 본문 두 줄을 그려 두니 다음 장이 둘째 줄을 글자 중간에서 잘랐고, 잘린 글자는 글이 아니라 때처럼 보인다. 자리는 잡아 두되 `opacity` 로 비워 둔다 — 없앴다 넣으면 종이가 «드러난» 것이 아니라 «갈아 끼운» 것으로 보인다 (§14.10).

## 검증

- `./scripts/test.sh` — **603개 통과** (새로 4개). 빌드 경고 0. 새 시험이 지키는 것: 무더기가 판을 거의 다 쓴다(예전 124pt 는 여기서 걸린다), 벌어져도 판을 넘지 않는다, 묻힌 장이 커져도 삐져나오지 않는다, 넘친 장수를 말한다.
- `./scripts/verify-drawer.sh` — 실제 창으로 `닫힘 40,40 128×96 → 펼침 40,40 288×250 → 되돌아옴 40,40 128×96`, 모서리고정·제자리복귀·계획크기 모두 true.
- `./scripts/render-ui.sh` — 닫힘·떠 있음·펼침(가운데 한 장에 손)·되돌림을 빛·어두움 두 벌로 확인. 표본에 세 장을 더해 「그리고 3장 더」가 실제로 나오게 했고, 손은 **무더기 가운데**에 얹어 위엣것을 가리지 않는지 봤다.

## 남은 것

제목만 있는 메모는 벌어져도 빈 종이가 드러난다 — 정직한 그림이지만 손을 얹을 때마다 45pt 짜리 빈 면이 나오는 것이 거슬리면 벌어지는 자리를 장마다 다르게 하는 길이 있다. 다만 그러면 아래 것들이 매번 다른 거리로 움직여서 무더기가 출렁인다.