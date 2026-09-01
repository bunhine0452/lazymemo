---
schema_version: 1
type: feature
slug: "eventkit-read-only-agenda"
status: done
difficulty: medium
created_at: "2026-08-31T17:25:26+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Agenda/ForeignEvent.swift"
    op: create
  - path: "Sources/LazyMemoCore/Agenda/DayAgenda.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/EventKitFeed.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "Tests/LazyMemoCoreTests/DayAgendaTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1701_feature_surface-at-agent-surface.md"
    kind: "followup"
tags:
  - "eventkit"
  - "calendar"
  - "privacy"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 달력이 반쪽이 아니게 됐다 — 시스템 캘린더를 읽어 연필 줄로 함께 세운다

플랜 `{#eventkit-read}`·`{#eventkit-ink}`. D5 가 후순위로 미뤄 둔 것이고, `surface_at` 의 「회의 30분 전」이 성립하려면 **회의를 알아야** 한다.

## 추가 기능

**읽기 전용이 규칙이 아니라 배선이다.** `CalendarFeed` 프로토콜에 함수가 `events(from:to:)` 하나뿐이고 `ForeignEvent` 에는 고칠 수 있는 것이 없다 — D6 이 하드 삭제 함수를 아예 안 만든 것과 같은 방식이다. 양쪽에 쓰기 시작하면 어느 쪽이 정본인지가 매일 흔들린다.

**권한을 묻는 자리는 달력 창이 처음 열릴 때 하나뿐이다.** 메모를 적으러 온 사람에게 첫 실행부터 캘린더를 내놓으라고 묻지 않는다(§8) — 달력을 한 번도 안 여는 사람에게는 영영 물을 일이 없다. 거절하면 `EKEventStore.authorizationStatus` 가 그 사실을 기억하므로 우리가 따로 적어 둘 것이 없고, **거절했다는 사실은 설정 메뉴에 보인다**(「시스템 설정 → 개인정보 보호에서 캘린더를 허용하면 함께 보입니다」). 조용히 빈 달력을 내놓으면 사용자는 연동이 고장 난 줄 안다.

**남의 일정은 연필로 적힌 줄이다.** 착각하면 지울 수 없는 것을 지우려 들고, 그때 아무 일도 안 일어나는 것이 「고장」으로 읽힌다. 그래서 셋을 바꿨다 — 막대를 채우지 않고 **테두리만**(반쯤 보고도 구별된다), 글자는 흐리게, **조작이 하나도 붙지 않는다.** 끌 수도 없다: 남의 달력은 우리가 옮길 수 있는 것이 아니고, 끌리는데 안 옮겨지는 것이 가장 나쁘다.

## 동작 흐름

`DayAgenda.rows` 가 우리 종이와 남의 일정을 한 줄기로 세운다. **정렬 규칙은 이 앱이 이미 쓰던 것 그대로** — 시각이 있는 것부터, 그 다음 최근에 손댄 순. 캘린더 권한을 준 날부터 하루를 읽는 순서가 달라지면 그 자체가 낯섦이다. 같은 시각이면 **우리 것이 먼저**다: 그 줄에만 조작이 붙으므로 손이 가는 것이 위에 있는 편이 낫다.

**격자의 번진 잉크(§10.4)에는 넣지 않았다.** 그 밀도는 «내가 쌓아 둔 것» 을 말하는 것이고, 남의 회의까지 세면 평일이 전부 똑같이 붐벼 보여 밀도가 아무것도 알려 주지 않게 된다. 일부러 남긴 선택이고, 써 보고 아쉬우면 다시 볼 것.

가져오기는 우리 메모를 다 세운 **뒤에** 얹는다 — 캘린더가 느리거나 권한이 없어도 내 메모는 이미 화면에 있다.

## 검증

`./scripts/test.sh` — 새 7개(DayAgenda). `./scripts/render-ui.sh` 로 눈으로 확인 — `calendar.png` 에서 「팀 스탠드업 10:00」이 속 빈 막대와 흐린 글씨로 「팀 회의 09:30」(채운 보라 막대)과 「은행 13:00」(채운 초록) 사이에 시각 순으로 섰다. 라이트·다크 양쪽에서 갈린다. 렌더가 실제 캘린더 권한 없이 돌도록 `PreviewRenderer` 에 표본 문(`SampleFeed`)을 세웠다.

## 메모

`NSCalendarsFullAccessUsageDescription` 을 넣었다 — macOS 14 부터 읽기에도 full access 가 필요하다. **실제 권한 대화상자는 아직 못 봤다**: 확인하려면 번들을 띄우고 달력을 열어야 하고, 그러면 이 기계의 진짜 캘린더를 읽게 된다. 설치본에서 한 번 열어 볼 것.