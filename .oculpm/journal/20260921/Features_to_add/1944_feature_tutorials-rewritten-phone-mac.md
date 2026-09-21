---
schema_version: 1
type: feature
slug: "tutorials-rewritten-phone-mac"
status: done
difficulty: high
created_at: "2026-09-21T19:44:41+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemo/TutorialArt.swift"
    op: create
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260912/Features_to_add/1545_feature_interactive-first-launch-tutorial.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1847_feature_phone-app-intents-write-today-pen.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1901_feature_widget-checkbox-writes-file.md"
    kind: "followup"
tags:
  - "tutorial"
  - "onboarding"
  - "ios"
  - "mac"
  - "l10n"
  - "testflight"
  - "mcp-tool"
---
[x] 첫 실행 안내를 두 판 다시 씀 — 폰은 앱의 부품을 그린 다섯 장, 맥은 이 컴퓨터의 단축키로 말하는 다섯 단계

사용자: 「테스트 플라이트에 올리기 전에 이 앱 튜툐리얼(모바일과 mac 용 모두) 을 제대로 그리고 정확하고 퀄리티 있게 만들어주고」. 「정확하고」를 README 「쓰는 법」·「다시 보기」·「위젯」·「어디서든 던지기」와 코드(`StackView` 스와이프, `HomeView` 컨텍스트 메뉴, `MenuBarController` 메뉴·클릭, `Hotkey` 기본값)에 대조하는 것으로 읽었다 — 안내에 적힌 손짓은 전부 본 화면에 그대로 있어야 한다.

## 추가 기능

**폰 (`TutorialView` · 새 `TutorialArt`)** — 네 장에서 다섯 장으로. 장마다 SF 심볼 타일 대신 **앱의 진짜 부품을 작게 그린 그림**이 먼저 선다(`Text` 로 그려 다크·테마·큰 글자를 그대로 따른다, 만질 수 없고 소리로 읽지 않는다).
1. 펜 — 칩 두 개(「9월 22일 (화) 15:00 · 달력으로」「@강남역」)·글 칸·「달력에 남기기」, 첫소리 「ㅊㄱ → 치과 예약」. 글: 남기기·칩·찾기·묻기(모델을 받으면).
2. 「지금」 — 카드 두 장(다시 보기·오늘 일정)과 「봤어요」, 종 단추의 「한 시간 뒤」「내일 아침 9시」. 글: 세 장·봤어요·종 단추·알림은 더 보기 → 알림에서 켤 때만.
3. 손짓 — 밀린 줄 셋(고정 / 일정 줄은 미루기 / 지우기)과 길게 누르기·흔들기. 글은 `StackView` 의 실제 스와이프 순서와 같다.
4. 달력 — 두 주 격자(오늘 원·고른 날·**메모 색 점**)와 그 날의 줄·「이 날에 적기」. 글: 누르기·쓸기·색 점·미루기·끌어 놓기·되풀이 낱말.
5. 앱 밖의 문 — 위젯(체크상자 포함)·공유 시트·Siri 타일. 글: 위젯 넷·공유·Siri 「lazymemo 에 적기」·iCloud 폴더·테마.
- 접근성 id(`tutorial-next/done/skip`)는 그대로. `SmokeTests` 의 「다음」 횟수 3→4.
- 마크다운 굵게가 「」 옆에서 깨지던 것: `**「지금」**에` 는 닫는 `**` 가 구두점 뒤·글자 앞이라 오른쪽 경계가 아니다(CommonMark) — `「**지금**」에` 로 안쪽에 둔다.

**맥 (`WelcomeView`)** — 네 단계에서 다섯 단계로, `WelcomeShortcuts` 로 **이 컴퓨터에 설정된 조합**(빠른 입력·클립보드·종이 보기)을 받는다(`MenuBarController.showWelcome`).
1. 바로 적기 — 연습 그대로 + 첫소리 찾기·자동 저장.
2. 날짜에 맡기기 — 연습 문장에 `@강남역`, 되풀이 낱말 안내.
3. 종이와 서랍(새) — 종이·× ·「서랍 N」 탭 그림과 「서랍에 넣어 보기」, **⌥⌘P 종이 보기**, 끝난 것은 물러남. 옛 「메뉴바를 오른쪽 클릭해 서랍을 열고」는 바탕화면 탭이 생긴 뒤의 사실과 어긋나 고쳤다.
4. 달력과 다시 보기(새) — 격자 조각(오늘 원·잉크 칸·그 날의 줄)과 달력에 놓기·미루기·끌기·종이로·우클릭 「다시 보기…」·알림 켜는 자리.
5. 준비 완료 — 단축키 넷 표(⌥⌘N·⌥⌘V·⌥⌘P·⌥⌘L, 앞 셋은 실제 값)·메뉴바 좌/우클릭·로그인 시작 스위치·iCloud 동기화 자리.
- `PreviewRenderer` 는 `WelcomeView.stepCount` 만큼 렌더(welcome·tutorial-2…5). 창 높이 610→640.
- 영어 표: 폰 38·맥 34 열쇠 추가, 두 표 `plutil -lint` OK. 폰 표에서 내가 앞서 넣었던 중복 열쇠 둘(`%@ · 달력으로`·`%@ %@ · 달력으로`)을 뺐다.

## 동작 흐름

폰: 첫 실행 → 안내 시트(키보드는 안 오른다) → 다섯 장 → 「시작하기」 → 펜에 키보드. More → 「사용법」으로 다시. 맥: 첫 실행 창 → 01·02 연습 → 03·04 그림+글 → 05 표와 스위치 → 「첫 메모 적기」/「달력 열기」. 메뉴 → 「시작하기 및 사용 안내…」로 다시.

## 검증

- 폰: 임시 XCUITest 로 다섯 장을 시뮬레이터에서 찍어 눈으로 봤다(굵게 깨짐·왼쪽으로 밀린 줄의 글 잘림을 그 자리에서 고치고 다시 찍음). `testFirstLaunchShowsTutorialThenThePen`·`testCalendarShowsTheDay` 초록. 임시 시험은 지웠다.
- 맥: `./scripts/render-ui.sh` 로 다섯 단계 라이트·다크 PNG 를 보고 지웠다 — 잘림·겹침 없음, 단축키 열이 실제 값(⌥⌘N 등)으로 선다.
- 사람이 볼 것: 실기기 다크·큰 글자에서 그림 카드의 높이, 영어 UI 의 줄 수.

## 메모

- 폰 안내의 그림은 화면의 실제 뷰(`PenBar`·`NowBand`)를 재사용하지 않았다 — 그것들은 모델과 손짓을 들고 있어 정적으로 세우기가 무겁다. 대신 같은 색·모양의 정물이다; 부품이 바뀌면 그림도 같이 고쳐야 한다(`TutorialArt` 머리 주석).
- 맥 04 의 오늘 표시는 정확한 원으로 그렸다 — 실제 맥 달력은 손으로 그린 동그라미(`PenMarks.HandRing`)다. 그림이라 넘어갔지만, 맥 달력도 위젯처럼 정확한 원으로 갈지는 사용자 몫.