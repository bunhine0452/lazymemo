---
schema_version: 1
type: feature
slug: "drawer-one-gesture-summon-bigger"
status: done
difficulty: high
created_at: "2026-09-17T16:35:06+09:00"
session_id: "20260917-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Drawer/DrawerGeometry.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerKeys.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerRow.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerKeysTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerPickingTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "scripts/verify-drawer.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260913/Features_to_add/0039_feature_drawer-folders-list-redesign.md"
    kind: "followup"
  - ref: "20260917/Chores/1311_chore_convenience-audit-research-note.md"
    kind: "followup"
tags:
  - "mac"
  - "drawer"
  - "ux"
  - "hig"
  - "keyboard"
  - "mcp-tool"
---
[x] 서랍 편의성 재설계 — 줄 한 번에 꺼내기·도로 넣기, 메뉴바에서 펼친 채 앞으로, 판 440·탭 232×60 에 최근 두 장

## 추가 기능

사용자 말 "서랍 기능이 지금 너무 불편해". 무엇이 불편한지 물으니 넷 다 — 손짓이 많다 · 바탕화면 뒤라 닿기 어렵다 · 판이 답답하다 · 탭이 작다. 병렬 fork 세션이 HIG 근거를 달아 설계·구현하고 부모가 수거했다. 결정은 `docs/DESIGN.md` §16.12 에.

1. **줄 클릭 / ↩ = 꺼내기** (3손짓 → 1). 종이가 제자리로 돌아가 잠깐 앞에 선다. 바닥 줄에 「「x」 꺼냈습니다 · 도로 넣기」 — 접으면 내려놓는다(며칠 뒤 고친 종이를 도로 넣는 단추 방지). 근거: WWDC17 802 80/20 · HIG Undo.
2. **Space = 펼쳐 보기(읽기만), ⇧↑↓ = 고르며 훑기** — Finder 훑어보기·⇧화살표 관용구(HIG Gestures "familiar gesture"). 호버 펼침은 §16.3 대로 안 함. 찾는 중 ↩는 짚지 않아도 **찾은 첫 줄**을 꺼내고 그 줄이 미리 밝혀진다(§14.10); ⌘⌫는 넘겨짚지 않는다.
3. **메뉴바 「서랍」= `summon()`**: 내놓기 → 펼치기 → 앱 활성 → 키 → 찾기 줄 커서(HIG Search fields). 이미 펼쳐져 키면 접고, 키 쥐고 있었으면 `NSApp.deactivate()`. 전역 단축키는 감사 §2.6 대로 안 만듦. 바탕화면에서 치우기/내놓기는 ⌥ 대체 항목(Progressive Disclosure).
4. **탭 232×60 두 줄**: 이름·장수 / 최근 두 장 제목(HIG Feedback — Mail 「Updated Just Now」 자리). §16.11 이 걷어낸 «흐트러진 카드»로는 안 돌아감.
5. **판 폭 372→440, 줄 50→54**, 폴더는 위 띠 유지(HIG scope bar; 사이드바는 목록이 320 으로 돌아가 기각).
6. **놓을 자리**: 종이가 떠 있는 동안 펼친 판 **전체**가 「놓으면 「폴더」에 들어옵니다」 덮개(점선 테두리 + 큰 글자) — 탭이든 판이든 어디에 놓아도 보고 있는 폴더로.

## 동작 흐름

`DrawerModel.target`(펼친 → 짚은 → 찾은 첫 줄) 이 ↩·클릭의 과녁. 꺼내면 `lastTakenOut` 이 남고 `putBack()`/`onPutBack` 이 창 관리자로 도로 넣는다. `DrawerWindowController.summon()` 이 창 레벨을 올려 앞으로 부르고, 접을 때 다시 바탕화면 레벨로 내려앉는다(진단 `앞으로=`·`내려앉음=`). 펼친 채 키를 잃으면 내려앉는 기존 규칙(`DesktopLevelWindow.resignKey`)은 그대로.

## 검증

- `swift build` ✓ · `./scripts/test.sh` 전체 ✓ (서랍 6 스위트 75개 — 새 시험 6: 찾는 중 ↩ 첫 줄, ⌘⌫ 넘겨짚지 않음, 도로 넣기, 접으면 내려놓음, ⇧↓ 고르기, ⇧화살표 문법).
- `./scripts/verify-drawer.sh` ✓: `모서리고정=true 제자리복귀=true 계획크기=true 앞으로=true 내려앉음=true` (펼침 440×344, 닫힘 232×60).
- 정적 렌더(스크래치패드, 프로젝트 밖) 라이트·다크: 탭 두 줄, 손 얹은 줄 「↗ 꺼내기 ˅ 📁 🗑」, 찾는 중 첫 줄 밝힘, 펼친 줄, landing 탭.
- 사람 눈 확인 필요: 메뉴바 「서랍」이 다른 앱 앞에 펼쳐지고 커서가 찾기 줄에 서는가 · 한 번 더 누르면 접히며 키보드가 이전 앱으로 가는가 · 줄 클릭 → 종이가 제자리에 떠오르고 「도로 넣기」로 다시 들어가는가 · 끌어올 때 덮개와 폴더 이름 · ⌥ 메뉴 항목.

## 메모

- en 표 추가/삭제 목록은 부모가 `Resources/en.lproj/Localizable.strings` 에 반영(다른 세션 미커밋 파일이라 fork 는 안 건드림). README 「서랍」절 표도 부모가.
- 후속: 빠른 입력 상자에서 「서랍」을 치면 여는 길(`QuickCaptureModel.Commit.command` 가 비서 갈래라 앱 명령 갈래 신설 필요) · 「열려 있는 동안은 늘 앞에」로 바꾸려면 `DesktopLevelWindow` 플래그 · 펼친 줄의 본문을 클릭해도 꺼낸다(접으려면 ˄/Space).