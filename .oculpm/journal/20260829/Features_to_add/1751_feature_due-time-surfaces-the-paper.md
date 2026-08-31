---
schema_version: 1
type: feature
slug: "due-time-surfaces-the-paper"
status: done
difficulty: high
created_at: "2026-08-29T17:51:51+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/DueClock.swift"
    op: create
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DueClockTests.swift"
    op: create
  - path: "scripts/verify-due-surface.sh"
    op: create
related: []
tags:
  - "due-clock"
  - "reminder"
  - "layout"
  - "window"
  - "mcp-tool"
---
[x] 적힌 시각이 오면 종이가 나온다 — §7.2 가 해 놓고 안 지킨 약속

## 추가 기능

설계문서 §7.2 는 이렇게 적어 두었다 — "날짜가 붙은 것은 달력이 맡는다. 언제 볼지 이미 정해졌으니 **그 날이 오면 달력이 꺼내 준다**." 앞절반만 구현돼 있었다. 꺼내 주는 쪽이 없어서 `at` 이 적힌 메모는 그 시각에 아무 일도 하지 않았고, 남는 것은 "적었는데 그냥 지나갔다" 였다. 그것이 한 번 반복되면 사용자는 중요한 것을 이 앱에 맡기지 않는다.

**알림 권한을 요구하지 않는다.** 시스템 알림 배너를 쓰면 첫 실행에서 사용자를 시스템 설정으로 보내야 하고 그것은 §8 의 원칙을 깬다. 이미 있는 것을 쓴다 — 종이가 바탕화면으로 나온다. 재질도 같고 배울 것도 없다.

## 동작 흐름

`DueClock` 이 다음에 울릴 `at` 까지 자고, 깨면 지난 것을 전부 꺼내고 다시 잔다. 메모가 바뀌면(새로 적기·미루기·날짜 떼기) `withObservationTracking` 으로 알아채고 다시 건다.

**꺼낸 종이는 그대로 있는다.** 이것이 이 기능의 핵심이고, 계획서에 적었던 것과 모양이 달라진 자리다.

> 계획서의 `#missed-list` 는 "자리를 비웠을 때 놓친 것을 달력 머리에 모아 둔다" 였다. 만들다 보니 **놓친 것을 모으는 목록이 필요 없었다.** 그 시각에 자리를 비운 사람이 바로 이 기능이 구하려는 사람인데, 1.6초 뒤 내려앉는 `riseBriefly` 로는 그 사람에게 아무 일도 일어나지 않는다. 그래서 종이를 꺼내 놓고 **두었다** — 돌아온 사람은 화면에서 그것을 본다. 놓친 것이 곧 화면에 놓인 종이다. 개념을 하나 새로 만드는 대신 이미 있는 것(바탕화면의 종이)으로 같은 일을 한다.

하루가 끝나면 스스로 물러난다 (`DayClock` → `clearSurfaced`). 어제의 일정이 오늘도 바탕화면에 서 있으면 그것부터가 낡은 종이다 (철학 3).

**앱을 켤 때는 오늘 이미 지난 것을 꺼낸다.** 가장 가까운 것부터 세 장까지 — 저녁에 컴퓨터를 열었다고 하루치가 통째로 바탕화면을 덮으면 그건 알림이 아니라 치울 거리다. 어제 것은 꺼내지 않는다: 지난 일정을 언제까지 눈앞에 세워 둘지는 「미루기」와 「종이로」가 정할 일이고(§7.3) 시계가 정할 일이 아니다.

### 걸려 있던 함정 — 꺼내 주면 영영 남는다

일정은 종이로 나오지 않으므로(§7.2) 꺼내려면 창을 새로 지어야 하는데, `open()` 은 언제나 `layout.json` 에 `hidden = false` 를 적었다. 그러면 그 메모는 「사람이 꺼내 둔 것」(§7.2 의 예외)이 되어 **날짜를 가진 채로 영영 바탕화면에 남는다.**

- `surfaced: Set<ULID>` 를 두어 규칙과 무관하게 지금 나와 있어야 할 종이를 들고, `open(recording:)` 으로 기록을 끈다. `sync()` 도 다시 지을 때마다 끈다 — 한 번만 안 적는 것으로는 부족했다.
- `recordFrame` 이 기록 없는 메모에 무조건 `hidden = false` 를 떨어뜨리던 것도 고쳤다. 이제 적힌 뜻이 없으면 **규칙이 말하는 자리**를 적는다.
- 꺼낸 종이는 24장 상한에 밀리지 않게 목록 앞에 세운다. 잘리면 지금 이 앱이 하려는 말이 통째로 사라진다.

이 `surface` 통로는 `#calendar-read-not-place`(달력에서 일정을 **읽으려고** 눌러도 종이가 영구히 생기는 결함)가 쓸 자리이기도 하다.

## 검증

- `./scripts/test.sh` — 303개 통과 (`DueClockTests` 8건 신규).
- 시각이 지나면 꺼낸다 · 두 번 안 꺼낸다 · 자다 깨어 여러 개가 지나 있으면 시간 순으로 전부 · 날짜만 있는 메모는 안 울린다 · 켤 때 오늘 지난 것을 세 장까지 · 그것들은 나중에 다시 안 울린다 · 어제 것은 안 꺼낸다 · 자정을 넘기면 다시 센다.
- **`./scripts/verify-due-surface.sh` 신설.** 지난 시각·뒤의 시각·날짜 없음 세 장을 임시 Vault 에 넣고 실제로 앱을 띄운다. 바탕화면 레벨 창이 **2개**(지난 일정 + 날짜 없는 메모)이고 뒤의 일정은 안 나오는 것, 그리고 **`layout.json` 의 꺼내 준 일정이 `hidden=true` 로 남아 있는 것**까지 본다. 마지막 것이 요점이다 — 화면만 봐서는 "꺼내 줬다" 와 "영영 꺼내 뒀다" 가 똑같아 보이고, 틀린 것은 다음 날에야 드러난다.