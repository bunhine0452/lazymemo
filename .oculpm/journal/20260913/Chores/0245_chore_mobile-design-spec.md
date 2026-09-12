---
schema_version: 1
type: chore
slug: "mobile-design-spec"
status: done
difficulty: medium
created_at: "2026-09-13T02:45:17+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/MOBILE_DESIGN.md"
    op: create
related:
  - ref: "20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md"
    kind: "followup"
tags:
  - "ios"
  - "design"
  - "docs"
  - "ux"
  - "mcp-tool"
---
[x] 폰 화면 설계 — 펜 하나·무더기 하나·달력 하나, 아트보드 17장

## 무엇을

플랜 `lazymemo-ios-icloud` 4단계(ui-capture ~ ui-location)를 그대로 구현할 수 있는 화면 설계. `docs/MOBILE_DESIGN.md` 와 디자인 캔버스(https://claude.ai/code/artifact/3212a2d1-de8a-4c23-9717-8b86a4cd8988, iPhone 390×844 아트보드 17장 — 펜 5·무더기 5·편집/달력 4·다크 3). 코드는 건드리지 않았다.

## 결정

- **폰에는 종이도 서랍도 없다.** 그 구분은 메모의 성질이 아니라 바탕화면이라는 면의 자리라서(`layout.json` 이 동기화되지 않는 이유와 같다) 폰에서 흉내 내면 목록이 둘이 된다. 남는 것은 파일에 적혀 동기화되는 것뿐 — `due/at`·`folder`·`tidied`·`deleted`·`pinned`. 폰에서 적은 것은 맥에 종이로 선다(단축어와 같다).
- **펜은 바닥, 탭 위에 하나** (`tabViewBottomAccessory`). 켜면 키보드가 올라와 있고 「남기기」가 엄지 밑. 무더기는 펜 위로 쌓인다 — 새 줄이 펜 옆에 앉는 것이 «적히긴 한 건가»의 답. 달력 탭에서는 고른 날 칩이 미리 물려 있다.
- **탭 둘(메모·달력), 시트 둘(날짜·폴더), 설정 화면 없음.** 검색 탭은 펜이 겸한다.
- **편집은 화면 전체가 종이 + 꼬리 한 줄** — 맥의 꼬리와 겹쳐 뜨는 조작을 끝 줄 하나로 합쳤다(§14.4 — 첫 줄을 덮지 않는다). 키보드는 누를 때만. 날짜는 시스템 피커가 아니라 같은 달 격자 위에서 가리킨다.
- **달력의 「다른 날로」는 끌지 않고 들고 기다린다** (§7.3 의 놓기). 미루기는 오른쪽으로 밀기 한 번.
- **되돌리기 띠는 펜 바로 위 8초**, 낱말 셋(지웠습니다·N일로 옮겼습니다·날짜를 뗐습니다).
- 로컬뿐일 때만 펜 위에 띠가 계속 있고, 잘 될 때는 무더기 머리까지 올려야 보인다.
- 공유 확장의 로컬 폴백은 App Group 컨테이너여야 한다 — 없으면 iCloud 꺼진 폰에서 확장이 적을 곳이 없다. `ios-paths` 의 폴백 자리를 그리로 옮길 것.
- 뺀 것: 사진 붙이기·시스템 캘린더 읽기·가면 떠오르기·위젯 (표로 이유를 적었다).

## 검증

아트보드 17장을 로컬 HTTP 로 띄워 크롬에서 렌더를 눈으로 봤다 — 첫 렌더에서 절대 배치한 종이 바탕이 본문을 덮는 것(편집·달력·날짜 시트가 빈 종이로 보임)과 목록 머리가 폴더 칩 밑에 깔리는 것을 잡아 고쳤다. `seed-canvas --check` ok. 실제 손 검증은 구현 뒤 XCUITest 몫.

## 메모

작업 파일(`*.dc.html`·`canvas.json`·생성기 `gen.py`)은 세션 스크래치패드 `mobile-design/` 에 있다 — 캔버스를 다시 짓는 것은 `gen.py` 를 고치고 재시드하면 된다. 플랜 항목은 갱신하지 않았다(부모 세션이 한다).