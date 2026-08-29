---
schema_version: 1
type: refactor
slug: "calendar-pen-marks-redesign"
status: done
difficulty: high
created_at: "2026-08-29T02:33:44+09:00"
session_id: "mcp-20260829-023344"
agent:
  id: "claude-code"
  version: "Opus 5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Calendar/CalendarInk.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/PenMarks.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CalendarInkTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "calendar"
  - "design"
  - "philosophy"
  - "swiftui"
  - "mcp-tool"
---
[x] 달력 대격변 — 부품을 걷어내고 종이 위의 펜 자국으로 다시 적음

## 동기

달력의 **동사**는 지난 판에서 이미 바로 세웠는데(보고·옮기고·미룬다) **생김새가 남의 것이었다.** 채운 원(오늘), 테두리 원(고른 날), 캡슐 점(밀도), `‹ ›`(달 이동), 1px 실선(두 층 경계) — 전부 맞는 표시였고 전부 어느 앱에나 있는 표시였다. 이 앱은 재질이 하나(좋은 종이, §14.5)인데 그 위에 놓인 표시만 UI 부품이면 달력 한 창만 남의 물건으로 읽힌다.

**재질을 정하는 것으로는 부족하고, 낱말까지 그 재질로 적어야 화면이 한 물건이 된다.**

## 변경 요약

달력이 쓰는 낱말을 전부 종이 위의 몸짓으로 다시 적었다.

| 뜻 | 버린 것 | 지금 |
|---|---|---|
| 오늘 | 채운 노란 원 + 검은 숫자 | 손으로 그린 동그라미 + 안쪽에 스민 호박색 |
| 고른 날 | 회색 원 + 테두리 | 숫자에 바짝 붙인 밑줄 |
| 놓을 자리 | 작은 파란 고리 | 칸 전체가 눌린다 (착지 판정 범위와 일치) |
| 붐비는 날 | 캡슐 점 셋, 넷부터 막대 | 숫자 아래 번진 잉크 |
| 달 이동 | `‹ ›` | 이웃 달의 **이름** (`7월 8월 9월`) |
| 두 층 경계 | 1px 실선 | 접힌 자리 + 아래 절반에 도트 그리드 |
| 다음 한 줄 | `＋ 이 날에 적기` | 비워 둔 줄 |
| 지난 날 | 일괄 55% | 하루씩 마른다 (`InkDrying`) |

- 획은 `stroke` 가 아니라 **가변 굵기 도형**이다 (중심선을 따라 법선 방향으로 폭 보간). 아이콘의 흘림선과 같은 기법 (§14.7).
- 흔들림은 날짜에서 뽑은 씨앗으로 재현한다 (`PenHand`, SplitMix64). 매 프레임 새로 흔들리면 그건 손이 아니라 잡음이다 — 오늘의 동그라미는 하루 종일 같고 내일은 새로 그은 것이 된다.
- 얼룩은 칸마다 도형을 두지 않고 격자 전체에 `Canvas` 한 장으로 그린다 (`InkBleedLayer`). 앞선 판의 캡슐 점보다 **레이어가 적다** (§14.8).

## 렌더를 보고서야 고친 것 셋

값만 봐서는 판별되지 않고 그림에서만 드러났다.

1. **동그라미를 한 바퀴 크게 넘겨 그었더니 꼬리가 획을 가로질러 `e` 로 읽혔다.** overshoot 0.55 → 0.26, 흔들림 진폭도 절반으로. 손 티가 나기 시작하면 표시가 아니라 잡티가 된다.
2. **얼룩을 칸 한가운데에 두었더니 숫자가 잿빛 원판 위에 올라앉아 "고른 칸" 으로 읽혔다.** 여러 색이 섞이면 얼룩은 어차피 잿빛이 되므로 그것은 색이 아니라 부품으로 보인다. 숫자 **아래**로 내리고, 겹쳐 찍던 색을 옆으로 늘어놓았다.
3. **밑줄이 얼룩과 같은 높이에 앉아 한 덩어리로 뭉쳤다.** 숫자에 바짝 붙이고(offset 0.56→0.40) 폭도 숫자만큼만 줄여 얼룩보다 좁게 했다.

## 검증

- `./scripts/test.sh` — 215 tests / 33 suites 통과. 새 suite 「달력의 잉크」 15건: 달 띠 이름이 `MonthGrid.advanced(by:)` 와 열두 달 전부 일치, 번짐이 자라되 멎음, 마름의 단조성과 바닥, 같은 씨앗 = 같은 손, 펜 자국이 제 칸을 벗어나지 않음.
- `./scripts/render-ui.sh` — `calendar.png` · `calendar-in-use.png` 를 빛/어둠 모드로 눈 확인. 조작 중 모습(집어 든 조각·놓을 자리·미루기·되돌리기·접힌 자리의 가리킴 표시)까지 실제로 옮겨서 그렸다.