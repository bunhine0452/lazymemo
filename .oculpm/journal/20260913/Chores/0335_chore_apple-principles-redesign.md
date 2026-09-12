---
schema_version: 1
type: chore
slug: "apple-principles-redesign"
status: done
difficulty: high
created_at: "2026-09-13T03:35:23+09:00"
session_id: "20260913-002"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/research/apple-design-principles.md"
    op: create
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260913/Chores/0245_chore_mobile-design-spec.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0307_feature_phone-ui-first-cut.md"
    kind: "followup"
tags:
  - "ios"
  - "design"
  - "hig"
  - "liquid-glass"
  - "research"
  - "mcp-tool"
---
[x] 애플 디자인 원칙을 원문으로 읽고 폰 설계를 2판으로 다시 썼다 — 목록은 위에서 아래, 조작은 유리, 되돌리기는 시스템

사용자 지시 「애플의 디자인 철학을 샅샅이 공부하고 디자인을 다시해」. 코드는 건드리지 않았다.

## 무엇을 읽었나

전부 원문 — HIG 는 `developer.apple.com/tutorials/data/design/human-interface-guidelines/*.json` 데이터 엔드포인트(렌더된 페이지는 JS 라 본문이 안 잡힌다), WWDC 는 세션 페이지의 트랜스크립트, 1st-party 앱은 support.apple.com. Designing for iOS · Layout · Entering data · Searching · Undo and redo · Feedback · Modality · Sheets · Onboarding · Privacy · Motion · Tab bars · Toolbars · Lists · Text fields · Virtual keyboards · Buttons · Context/Edit menus · Gestures · Materials · Color · Typography · Accessibility. WWDC25 219·356·323·359, WWDC17 802, WWDC18 801·803. 인용 가능한 노트로 `docs/research/apple-design-principles.md` 에 남겼다 — 원칙마다 출처·원문 한 줄·「폰의 lazymemo 에 뜻하는 바」. **못 찾은 것도 적었다**: 옛 HIG 여섯 원칙 원문(페이지가 사라졌고 archive.org 에 못 닿음), 액세서리 안 텍스트 필드의 키보드 동작, Reminders 의 자연어 날짜 제안 문서.

## 무엇이 바뀌었나 (`docs/MOBILE_DESIGN.md` §14 표)

- **목록을 뒤집지 않는다.** 1판의 「펜 위로 쌓기」는 Layout "most important… near the top", Consistency(Notes 모델), 그리고 구현이 scroll edge effect 를 꺼야만 보였다는 사실 — 세 방향에서 반대. 위에서 아래(고정 → 최근순), 새 줄은 맨 위에 생기고 화면이 그리로 가며 한 번 밝아진다.
- **조작은 유리, 종이는 콘텐츠 층.** 펜은 `tabViewBottomAccessory` 의 유리 캡슐(접히면 한 줄), 편집의 꼬리는 표준 바닥 툴바(키보드 위로 따라감, `ToolbarSpacer` 세 묶음), 시트는 유리 그대로. 「재질은 종이 하나」는 콘텐츠 층의 말이다.
- **되돌리기 띠를 뺐다.** HIG Undo "buttons only when necessary… shaking their iPhone". `UndoManager` 에 이름을 단 시스템 되돌리기 + 결과 보이기 + 툴바의 휴지통 단추.
- 저장 자리는 큰 제목의 **부제**(Mail 의 「Updated Just Now」 자리), 상시 띠 없음. 툴바에 휴지통, More 는 있을 때만.
- 달력 「들고 기다리기」 → **시스템 끌기** + 날짜 시트. 목록의 「달력에 놓기」도 시트.
- `fadedInk` 52% 는 미색 위 ≈3.3:1 로 캡션에 못 쓴다 → 시스템 `.secondary`. 바램은 제목 색으로만, Increase Contrast 면 끔.
- 「지금 여기」는 **시스템 `LocationButton`**.
- 남긴 것: 은유(종이·서랍 없음), 탭 둘, 칩을 눌러 읽지 않기(Entering data 의 「그 자리에서 고치기」), 편집 열 때 키보드 안 올림(Notes), 폴더 칩, 휴지통, 공유 시트.

## 캔버스

2판 캔버스 18장(화면 15 · 다크 3): https://claude.ai/code/artifact/ee32f4e3-300a-4c76-b832-147a6c4646ea — 생성기는 세션 스크래치패드 `mobile-design-v2/gen.py`, 색은 `ios/LazyMemo/Theme.swift` 값 그대로. 1판 캔버스는 문서 머리에 링크로 남겼다.

## 검증

- 노트의 인용은 전부 이 세션에서 실제로 받아 온 응답에서 옮겼다. 세 곳은 「못 찾음」으로 적었다.
- 캔버스는 `--check` 통과, 다섯 장을 헤드리스 Chrome 으로 렌더해 눈으로 봤다(시각 칩 줄바꿈 하나 고침).
- 플랜은 건드리지 않았다 — 부모 세션이 갱신한다.