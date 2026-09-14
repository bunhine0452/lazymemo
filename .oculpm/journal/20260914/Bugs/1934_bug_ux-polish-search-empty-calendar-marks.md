---
schema_version: 1
type: bug
slug: "ux-polish-search-empty-calendar-marks"
status: done
difficulty: low
created_at: "2026-09-14T19:34:41+09:00"
session_id: "20260914-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/MonthGridView.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "ios/LazyMemo/TrashView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerRow.swift"
    op: update
related: []
tags:
  - "ios"
  - "mac"
  - "ux"
  - "drawer"
  - "calendar"
  - "mcp-tool"
---
[x] 아마추어로 읽히던 자리 여섯을 고쳤다

## 발생 원인
스토어 스크린샷(`dist/store/{ios,mac}`)을 사람 눈으로 다시 보니 조작 자체는 되는데 «만든 사람이 안 써 본» 흔적이 여섯 있었다.
- 폰 펜에 글을 치는 동안 목록이 「5장 중 없다」 + 「찾는 메모가 없어요 / 아래의 글을 새 메모로…」로 같은 말을 둘 씩 하고, 큰 제목이 서서 새 메모를 적는 사람이 틀린 것처럼 읽었다.
- 폰 달력 탭 위에 「달력」 제목이 한 번 더 서서 탭 이름·격자 머리 「9월 2026」과 셋이 같은 말을 했다.
- 달 격자에서 일정 있는 칸을 네모 바탕으로 물들였는데, 그 네모가 고른 날의 표시와 같은 모양이라 두 칸이 골라진 것처럼 보였다. 맥은 점을 쓴다 — 두 플랫폼이 같은 것을 다르게 그렸다.
- 날짜 시트가 중간 높이로 열려 격자 밑의 시각 칩 줄(없음·09:00·14:00·직접…)이 반쯤 잘렸다.
- 휴지통 줄의 「N일 전 지움」이 오버레이 + `padding(.trailing, 96)`으로 겹쳐 놓은 임시 배치였다.
- 맥 서랍 줄에서 둘째 줄이 없는 메모는 왼쪽에 시각을 대신 적는데 오른쪽 끝에도 같은 시각이 있어 「오늘 … 오늘」이 한 줄에 두 번 섰다.

## 해결 방법
- `StackView`: 찾는 중 빈 결과는 각주 한 줄 「N장 중 겹치는 것 없음 · 남기면 새 메모예요」만. 제목·아이콘 빈 상태는 찾지 않을 때만. 식별자 `scope`/`search-empty` 유지.
- `CalendarView`: 루트에서 네비게이션 막대를 숨긴다. 밀어 들어간 편집은 제 막대를 가진다.
- `MonthGridView`: 오늘=채운 원, 고른 날=옅은 원(34pt), 일정=숫자 밑 점(최대 3, 오늘 위에서는 밝은 색). 맥과 같은 낱말.
- `DateSheet`: `PresentationDetent` 선택을 `.large`로 시작(중간도 남긴다).
- `MemoRowView`: `retired`면 시각 조각이 「N일 전 지움」+휴지통 아이콘. `TrashView`의 오버레이 삭제.
- `DrawerRow`: 둘째 줄이 없으면 비운다 — 시각은 오른쪽에 이미 있다.

## 검증
- `swift test` 725/725, `./ios/scripts/uitest.sh` 10/10 통과.
- `uitest.sh --shots`와 `store-shots.sh`(임시 vault, 스크래치패드로)로 달력·펜·날짜 시트·서랍을 눈으로 확인 — 「달력」 제목 없음, 14 오늘 원+점 하나, 15 옅은 원+점 둘, 시트 시각 칩 온전, 서랍 「명함 사진 찍어 두기」 줄의 중복 시각 없음.
- 실기기 손검증(스와이프·시트 끌기)은 남는다.