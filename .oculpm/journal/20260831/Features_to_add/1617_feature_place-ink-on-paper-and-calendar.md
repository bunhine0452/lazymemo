---
schema_version: 1
type: feature
slug: "place-ink-on-paper-and-calendar"
status: done
difficulty: medium
created_at: "2026-08-31T16:17:03+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MapLink.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteFooter.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MapLinkTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/NoteFooterTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1538_feature_place-field-parser-and-mcp.md"
    kind: "followup"
tags:
  - "place"
  - "ui"
  - "calendar"
  - "a11y"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 장소가 눈에 보인다 — 종이의 잉크 자국과 달력 줄, 그리고 시스템 지도

플랜 `lazymemo-v2-surface-place` 의 `{#place-ink}`·`{#place-in-calendar}`. 앞 사이클에서 필드와 MCP 까지 갔지만 화면에는 아무것도 안 보였다. 이제 보인다.

## 추가 기능

**`MapLink`** — 장소를 시스템 지도에 넘기는 주소를 만든다. 좌표가 있으면 `ll` 로 그 점에 가고, `q` 는 **늘 함께** 넘겨 핀에 이름이 남게 한다. 좌표만 있으면 좌표가 곧 이름이다 — 이름 없는 핀을 만들지 않는다. 이 타입은 문자열만 만들고 **아무 데도 접속하지 않는다**: 실제로 여는 것은 사용자가 눌렀을 때의 OS 다.

**앱 안에 지도 뷰를 두지 않았다.** 종이 위에 지도를 얹는 순간 재질이 둘이 되고(§14.5), 화면이 «글자와 종이뿐»(철학 4)이 아니게 된다.

**종이** — 아래 줄에 `📍 강남역 3번 출구`. 누르면 지도가 바깥에서 열린다. 날짜와 결이 같지만 **자리가 다르다**: 날짜를 누르면 이 메모가 옮겨 앉은 달력으로 가고, 장소를 눌러도 이 종이는 그대로 있다.

**달력** — 쉬고 있을 때 `14:30 치과 예약 · 강남역 3번 출구`. 나가기 전에 필요한 전부가 한 줄에 있다.

## 동작 흐름

**렌더를 보고 두 번 고쳤다** (§14.9 — 눈으로 확인하는 방법이 실제로 일했다).

1. **종이의 꼬리가 세 줄로 접혔다.** 그 줄은 겹쳐 뜨는 캡슐이 덮지 않도록 오른쪽을 미리 비워 둔 자리라(`NoteControlLayout.footerReserve`), 날짜·장소·태그 셋을 260pt 에 밀어 넣으니 날짜가 «8월 31 / 일 오후 / 2:30» 으로 접히고 장소는 «강남역…» 으로 잘렸다. → `ViewThatFits` 로 바꿨다. 자리가 되면 한 줄, 안 되면 **장소가 아랫줄로 내려앉고** 캡슐이 비워야 할 자리도 함께 아랫줄로 옮겨 간다.
2. **달력 줄에 버튼이 넷이 되자 「미루기」가 두 줄로 접혔다.** → ① 「길찾기」 낱말 캡슐을 **핀 그림 하나**로 바꿨다 (이 줄에서 낱말을 쓸 수 있는 것은 둘까지고 셋째부터는 휴지통처럼 그림이어야 한다). ② 포인터가 온 줄에서는 장소를 적지 않는다 — **장소는 쉬고 있을 때 읽는 것이고, 포인터가 왔다는 것은 이미 읽었다는 뜻이다.**

달력 줄의 장소를 **누를 수 있게 만들지 않았다.** 그 자리는 끌기의 자리이고, 버튼을 끌기 영역에 두면 누르기 하나를 놓고 둘이 다툰다 — 그 파일에 이미 적혀 있던 교훈이다. 길찾기는 hover 조작 줄로 뺐다.

`RowWords` 로 **보이는 줄과 VoiceOver 가 읽는 줄을 한 함수에서 만든다.** 화면은 가운뎃점, 소리는 쉼표다 — 가운뎃점은 읽히지 않는다 (§14.11). `NoteFooter.isVisible` 도 뷰 밖으로 꺼냈다: 장소만 있는 메모에 꼬리가 아예 안 서면 사용자는 장소를 적었다는 것조차 알 수 없고, 그 실패는 화면에서 보이지 않는다.

`MemoStore.create`/`update` 에도 `place`/`geo` 를 냈다 — 앱 쪽 입력 경로(빠른 입력·`⌥⌘L`)가 이 문으로 들어온다.

## 검증

`./scripts/test.sh` — **420개 통과** (앞 사이클 408 → 새 12개: MapLink 5, NoteFooter 4, RowWords 3). `swift build` 새 경고 없음(남은 경고는 `StandardMenu.swift` 의 기존 것). `./scripts/render-ui.sh` 로 라이트·다크 양쪽을 눈으로 확인 — `note.png` 는 꼬리가 두 줄로 접혀 장소가 온전히 보이고, `calendar.png` 는 쉬는 줄에 장소가, `calendar-in-use.png` 는 포인터가 온 줄에 핀 버튼이 붙고 「미루기」가 한 줄로 선다.

## 메모

`site/index.html`·`README.md`·`.github/workflows/pages.yml` 이 이 세션 중(15:19–15:25) 바뀌어 있는데 **이 작업이 건드린 것이 아니다.** 다른 세션이나 사람이 함께 고치는 중으로 보인다 — 커밋할 때 섞이지 않게 볼 것.