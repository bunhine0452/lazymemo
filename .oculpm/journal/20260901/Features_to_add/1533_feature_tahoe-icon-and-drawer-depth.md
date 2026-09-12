---
schema_version: 1
type: feature
slug: "tahoe-icon-and-drawer-depth"
status: done
difficulty: high
created_at: "2026-09-01T15:33:42+09:00"
session_id: "20260901-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/make-icon.swift"
    op: update
  - path: "scripts/make-icon.sh"
    op: update
  - path: "Resources/AppIcon.icns"
    op: update
  - path: "Sources/LazyMemoUI/Resources/MenuBarIcon.png"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerSearch.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerKeys.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerGeometry.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerContents.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerPaper.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerSearchTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/DrawerKeysTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/DrawerPickingTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "icon"
  - "drawer"
  - "design"
  - "macos26"
  - "search"
  - "mcp-tool"
---
[x] 시스템이 아이콘을 깎는다는 것을 알아내고, 서랍에 찾기·고르기·더 보기를 넣는다

## 추가 기능

셋을 함께 했다 — 아이콘, 서랍(폴더) 기능, 앱 전반 디자인.

### 1. 아이콘 — 그릇을 걷어냈다

**전제부터 틀렸던 것을 실측으로 잡았다.** macOS 26 이 아이콘 규격을 바꿨을 것이라 짐작하고 시작했는데, Tahoe 시스템 앱을 재 보니 몸통은 여전히 1024 캔버스 안 824 였다. 그런데 lazymemo 도 똑같은 값이 나오는 것이 수상해서, **캔버스를 꽉 채운 빨간 정사각형 icns** 를 만들어 시스템에 물었다.

돌아온 것은 가운데 824 초타원으로 깎이고 그림자까지 붙은 그림이었다. 즉 **macOS 26 은 모든 레거시 icns 를 같은 실루엣에 밀어 넣고 그림자를 자기가 붙인다.**

- 몸통 `x[100..923] y[100..923]`, 모서리 초타원 지수 **4.47** (마스크 실루엣 최소제곱, RMS 4.1px)
- 시스템 그림자는 캔버스 밖 `y 91..948` 까지 번진다

그래서 앞선 아이콘은 화면에서 **판이 세 겹**이었다 — 시스템 회색 유리판 → 우리가 그린 남색 판 → 그 안의 종이 카드. 그림자도 두 번 겹쳤다.

지금은 **캔버스를 종이로 끝까지 채운다.** 실루엣·그림자·바탕은 시스템 몫이고, 남는 것은 재질 하나(좋은 종이)와 그 위의 잉크 두 줄뿐이다 — §14.7 이 하려던 말(「그릇의 모양이 아니라 글씨의 태도」)에 오히려 더 가깝다. 종이를 크림 쪽으로 익히고(밝은 Dock 에서 녹지 않게), 획을 44 → 92 로 굵혔다(16px 에서 두 줄이 두 줄로 남게). 황동 클립과 접힌 모서리는 붙을 자리가 없어 뺐다.

미리보기(`--sheet`)도 **시스템이 깎은 뒤의 모습**으로 그리게 고쳤다. 그린 것을 그대로 늘어놓고 골랐기 때문에 세 겹인 줄 몰랐던 것이다.

### 2. 서랍 — 분류를 만들지 않고 깊이만 준다

§16.1 의 「폴더인데 분류가 아니다」를 지키면서 안을 다졌다. 넷 다 **아무것도 저장하지 않는다** — 접으면 전부 내려놓고 파일에는 흔적이 없다.

- **찾기** (`DrawerSearch`) — 제목·본문에서 거른다. **첫소리도 찾는다**(`ㅈㅂㄱ` → 장보기), 다만 질의가 통째로 초성일 때만. 한글은 조합 입력이라 날 키를 모으면 「장」이 「wkd」가 되므로 **진짜 글 상자**를 쓴다.
- **고르기** — ⌘-클릭. 처음에 손이 얹힌 것처럼 옆으로 밀어 냈다가 §16.3 이 이미 적어 둔 고장(묻힌 장을 밀면 몸통이 옆으로 빠져나온다)이 그대로 나와서, 테두리 하나로 바꿨다. **겹친 무더기에서는 «자리» 로 말할 수 없다 — 자리는 이미 겹침이 쓰고 있다.**
- **더 보기** — 「그리고 N장 더」가 이제 눌린다. 예전에는 말만 하고 길이 없었다(그 넉 장을 보려면 앞의 여덟 장을 먼저 꺼내야 했다). 화면이 허락하는 데까지만 자란다.
- **키보드** (`DrawerKeys`) — ↑↓ 훑기, ↩ 펼치기, ⌘↩ 꺼내기, ⌘⌫ 지우기, ⌘F 찾기. esc 는 **한 겹씩** 벗긴다.

함정 셋을 미리 막았다. ① 조합 중(`hasMarkedText`)에는 어떤 키도 맡지 않는다. ② 커서 위치는 `@FocusState` 가 창에 적어 준다 — 응답 사슬로 짐작하면 틀려도 표가 안 나는데, 틀리면 **띄어쓰기 스페이스가 종이를 고르는 키**가 된다. ③ 걸러지거나 서랍에서 나간 종이는 펼침·짚음·고름에서 함께 빠진다(화면에 없는 종이에 조작이 걸리면 안 된다).

### 3. 디자인 — 작아진 종이도 종이다

`PaperEdge`(위는 빛, 아래는 그늘 — 종이의 두께)를 **큰 종이에만** 쓰고 있었다. 서랍에 겹친 한 장, 달력으로 끌고 가는 조각은 저마다 평평한 테두리를 갖고 있었고 세기도 8%·10%·13%·14% 로 갈려 있었다 — 우연히 비슷했을 뿐이라 한쪽을 고치는 사람은 다른 쪽을 몰랐다. 지금은 크기와 무관하게 하나를 쓰고, 작아진 종이의 모서리에도 이름을 주었다(`Theme.chipRadius`, 흩어져 있던 `4` 여덟 자리).

## 검증

- `./scripts/test.sh` — **645개 통과** (`DrawerSearchTests` 14 · `DrawerKeysTests` 8 · `DrawerPickingTests` 18 신규)
- `./scripts/verify-drawer.sh` — 모서리고정·제자리복귀·계획크기 전부 true
- `./scripts/verify-notes.sh` — 바탕화면 레벨·subrole 그대로
- 아이콘은 **실제로 빌드한 번들을 시스템에 렌더시켜** Notes·Reminders·Calendar·Mail 과 나란히 16/32/64/128px, 밝은·어두운 바탕에서 확인했다
- `./scripts/render-ui.sh` — 서랍 7화면(찾는 중·못 찾음·고른 것 신규) 눈으로 확인

**사람 눈 확인이 남았다**: 실제 창에서 찾기 상자에 **한글을 쳐 보는 것**. `NSEvent` → 창이 키인가 → 커서가 상자에 있는가 로 이어지는 고리는 기계로 확인할 수 없다. 순수 부분(`DrawerKeys`, `DrawerModel.handle`)은 시험이 덮었지만 그 고리는 안 덮인다.