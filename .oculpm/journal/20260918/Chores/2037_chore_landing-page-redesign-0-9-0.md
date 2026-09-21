---
schema_version: 1
type: chore
slug: "landing-page-redesign-0-9-0"
status: done
difficulty: medium
created_at: "2026-09-18T20:37:07+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
related:
  - ref: "20260918/Features_to_add/1932_feature_theme-catalog-and-customization.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1909_feature_web-page-evidence-and-digest-memo.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1912_feature_widget-redesign-precise-comfortable.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1920_feature_mac-paper-fits-content.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2241_feature_site-relaunch-live-capture-hero.md"
    kind: "followup"
tags:
  - "site"
  - "landing"
  - "theme"
  - "release-0.9.0"
  - "design"
  - "a11y"
  - "mcp-tool"
---
[x] 소개 페이지를 0.9.0 판으로 다시 꾸몄다 — 페이지 자체가 여덟 벌 중 고른 종이가 된다

사용자: 「랜딩페이지도 새롭게 꾸미고」

## 한 문장

앞선 판의 가장 큰 볼거리는 **머리의 타자 재생**이었다. 0.9.0 의 가장 큰 볼거리는 **종이가 여덟 벌이 됐다는 것**이고, 그것을 「테마 절」 안에 스크린샷으로 가두면 그냥 또 하나의 기능 칸이 된다. 그래서 대담함을 한 자리에만 썼다 — **여덟 견본 중 하나를 누르면 이 페이지가 통째로 그 종이로 인쇄된다.** 바탕도, 도트 그리드도, 초록도, 호박색도, 종이의 가장자리와 그림자까지.

## 무엇을 했나

- **색은 `ThemeCatalog.swift` 에서 그대로 떠 왔다.** 여덟 테마 × 빛/어둠 = **CSS 변수 열여섯 벌**(한 벌에 13개). 파서 하나로 Swift 의 `ThemeRGB(0…1)` 을 hex 로 바꿔 옮겼으니 앱과 페이지가 같은 숫자를 본다. `:root[data-theme="…"]` 로 얹고 `@media (prefers-color-scheme: dark)` 안에 어둠 판을 한 번 더 둔다.
- **어두운가는 외관이 아니라 테마가 말한다.** 「미드나잇」·「숲속 어둠」을 고르면 빛 모드에서도 페이지가 어두워진다 — `--dark: 0|1` 한 숫자를 `calc()` 로 가장자리(`--edge-t`/`--edge-b`)·두 겹 그림자에 흘려, 앱의 `ThemeVariant.darkPaper` 와 같은 결정을 CSS 로 옮겼다.
- **견본 한 장이 앱 아이콘이다** (§14.7). 반듯한 첫 획(잉크)과 끝으로 갈수록 사라지는 둘째 획(강조색 → 투명 그라디언트), 그리고 오른쪽 아래의 호박색 점 하나. 그 테마의 실제 색으로 그려지므로 **JS 가 없어도 여덟 벌이 눈에 보인다** — JS 가 하는 일은 `data-theme` 한 글자를 바꾸는 것뿐이고, 없으면 기본 종이로 멀쩡히 읽힌다.
- **설계 문서의 숫자를 CSS 이름으로 옮겼다.** 모서리 반경 넷(`--r-card:14 --r-panel:20 --r-ctl:10 --r-chip:8`)과 움직임 낱말 둘(`--quick:.18s --settle:.30s`)은 테마가 바뀌어도 그대로다 — 「형태의 규칙이 테마마다 달라지면 그건 테마가 아니라 앱이 여덟 개인 것이다」(VISUAL_DESIGN). 페이지의 움직임은 **종이가 갈리는 0.18초 하나뿐**이고, 스크롤 등장 애니메이션·카드 호버 전환은 하나도 없다. `prefers-reduced-motion` 은 두 변수를 `0s` 로 눕힌다.
- **재질을 두 가지로 갈라 구조를 만들었다.** 「볼 것」은 종이 위에(`.sheet`/`.frame`/`.wg` — 두 겹 그림자 + 윗변 밝고 아랫변 어두운 `PaperEdge`), 「우리가 하는 말」은 도트 그리드 바탕 위에 그대로. 카드가 장식이 아니라 **어느 쪽인지를 말하는 표시**가 됐다.
- **절 구성** (두 언어 동일, 11개): 머리(0.9.0 · 한 문장 · brew 복사 상자 + 릴리스 · App Store 심사 중 한 줄 · 빠른 입력 종이 한 장) → `#lazy` 게으름 셋 → `#film` 시연 영상 → **`#themes` 여덟 견본** → `#assistant` 비서와 웹(정리한 메모를 진짜 종이 카드로 렌더 — 제목·핵심·세부 표·출처·꼬리) → `#paper` 종이가 자란다(CSS 도해 셋) → `#widgets` 위젯 넷(전부 CSS 목업, 새 이미지 0) → `#phone` → `#route` → `#features` → `#privacy` 표 → `#install`.
- **README 가 거는 `#route` 를 포함해 옛 id 열둘을 전부 살렸다** (scenes·film·phone·route·why·desk·recall·keys·files·claude·privacy·install).
- **곁다리로 고친 것 — 옆 여백이 없었다.** `.topbar`·`.hero`·`footer` 가 `.wrap` 과 같은 요소에 붙으면서 `padding: 22px 0 0` 같은 **shorthand** 로 `.wrap` 의 `padding: 0 32px` 를 덮고 있었다. 나중에 선언된 쪽이 이겨서 지금 나가 있는 판은 머리·바닥이 화면 가장자리에 붙어 있다. 셋 다 `padding-block` 으로 바꿨다.

## 안 한 것

새 이미지를 한 장도 만들지 않았다. 위젯도 테마 견본도 종이 자람도 전부 CSS 라, `site` 는 17M 그대로고 html 두 장이 13KB 씩 늘었다. `scripts/render-ui.sh` 는 앱을 빌드해야 하는데 `.build` 를 다른 세션과 나눠 쓰므로 부르지 않았다.

## 검증

- **`.github/workflows/pages.yml` 의 「바깥으로 나가는 것이 없는지」 단계를 그대로 돌렸다** — `외부 요청 없음 ✓`. 웹폰트·CDN·바깥 이미지 없음, 색은 전부 인라인 CSS.
- `python3 -m http.server` 로 띄워 `/` `/ko/` `/privacy/` 가 200, 두 페이지가 부르는 로컬 자원 **15개가 전부 200** (`ALL ASSETS OK`).
- 파서로 태그 균형·중복 id·내부 링크를 쟀다 — `unclosed=[] errors=[] duplicate_ids=[]`, 내부 링크 8개 전부 목적지 있음. CSS 변수 34개 사용 / 미정의 0, 테마 블록 16개가 전부 같은 13개 키. 두 언어의 절 순서·요소 수(section 11 · h2 11 · h3 18 · figure 6 · video 3 · table 4 · button 11)가 **완전히 같다**.
- `xmllint --html --noout` 은 인라인 SVG 를 모르는 libxml2 의 알려진 한계로 `Tag svg invalid` 넷만 내는데, **손대지 않은 `site/privacy/index.html` 도 똑같이 낸다** — 회귀 아님.
- 400px 폭: 고정 폭 중 가장 넓은 것이 190px(`.grow div.c`), `minmax(200px,…)` 는 760px 아래에서 1열로 접힌다. 표 둘은 660/560px 에서 블록으로 갈리고, `pre` 는 `overflow-wrap: anywhere` 로 긴 URL 을 끊는다. 가로 스크롤 유발 요소 없음.
- `wc -l` 800 / 793 줄 (상한 900), `du -sh site` **17M — 늘지 않았다.**