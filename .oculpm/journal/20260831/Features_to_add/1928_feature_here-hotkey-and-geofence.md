---
schema_version: 1
type: feature
slug: "here-hotkey-and-geofence"
status: done
difficulty: high
created_at: "2026-08-31T19:28:29+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/HereCapture.swift"
    op: create
  - path: "Sources/LazyMemoUI/Calendar/PlaceWatcher.swift"
    op: create
  - path: "Sources/LazyMemoCore/Agenda/GeofenceRule.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/Hotkey.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "Tests/LazyMemoCoreTests/GeofenceRuleTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1906_feature_claude-on-the-paper.md"
    kind: "followup"
tags:
  - "location"
  - "geofence"
  - "privacy"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 지금 여기(⌥⌘L)와 가면 떠오르기 — 그리고 프라이버시 절을 통째로 다시 썼다

플랜 `{#here-hotkey}`·`{#ios-shortcut-place}`·`{#geofence-design}`·`{#geofence-surface}`. 계획 `lazymemo-v2-surface-place` 의 마지막 넷이고, **신뢰 비용이 가장 큰 자리**다.

## 추가 기능

**`⌥⌘L` 「지금 여기」** — `⌥⌘V`(클립보드)의 형제. 창을 열지 않고 지금 있는 자리가 종이 한 장이 된다. 권한은 **처음 누를 때만** 묻고, 거절하면 다시 묻지 않으며 그 사실이 설정 메뉴에 남는다. **한 번 재고 끊는다** — 계속 켜 두지 않는다.

**「가면 떠오르게 하기」** — 적어 둔 자리에 도착하면 그 종이가 스스로 나온다. `DueClock` 의 짝이고 꺼내는 방식도 같다: 시스템 알림이 아니라 **바탕화면의 종이가 앞으로 나온다**(알림 권한을 여전히 안 쓴다).

**지켜볼 자리를 고르는 규칙을 Core 에 뒀다** (`GeofenceRule`). 위치를 다루는 규칙은 눈에 안 보이는 곳에서 조용히 넓어지기 쉽다.

- **좌표가 이미 적힌 메모만.** 이름만 적힌 `@강남역` 은 지켜보지 않는다 — 지켜보려면 이름을 좌표로 바꿔야 하고, 그건 **당신이 적어 둔 장소 이름을 전부 애플에 보내는 일**이다. 좌표는 `⌥⌘L` 과 아이폰 단축어가 만들어 주고, 그 둘은 사람이 직접 누른 것이다.
- 갈 일이 없는 것은 뺀다 — 지운 것·치운 것·다 체크한 목록·지난 일정.
- **스무 개까지**(CoreLocation 상한), 그리고 **몇 장이 빠졌는지 센다.** 조용히 자르면 「거기 갔는데 안 떴다」가 남고, 그게 이 기능을 못 믿게 만드는 가장 빠른 길이다.
- **도착만 센다.** 떠나는 것은 알아야 할 것이 아니다.

## 동작 흐름 — 문서가 거짓말을 하고 있었다

**`{#geofence-design}` 의 본론은 지오펜스가 아니라 이것이었다.** README 와 §9.3 은 "메모 본문이 밖으로 나가는 경로는 MCP 뿐" 이라고 적고 있었는데, 앞 사이클에서 `claude` CLI 를 붙이면서 **그것이 둘 더 늘었다**(종이 위 다듬기·아침 브리핑). 기능을 붙일 때 함께 안 고치면 문서가 사용자에게 거짓말을 한다.

그래서 나가는 것을 **일곱 줄 표 하나로** 다시 적고, 권한도 **넷을 표로** 적었다 — 그리고 「첫 실행에는 하나도 없다」를 한 줄로 못 박았다.

`Always` 위치 권한에는 §9.3 의 조건 셋으로 모자라 **넷으로 잠갔다**: ① 기본 꺼짐(켜는 것을 사람이 직접) ② 켜져 있다는 사실과 **지켜보는 자리 수**가 메뉴에 보임 ③ 좌표가 이미 적힌 메모만 ④ 도착만 세고 위치는 저장하지도 내보내지도 않음.

역지오코딩은 새 네트워크 경로다 — **좌표만 나가고 메모 본문은 안 나간다.** 실패하면 좌표만 적고 넘어간다: 그것 때문에 메모를 못 만들지는 않는다.

## 검증

`./scripts/test.sh` — **596개 통과** (앞 590 → 새 6개: GeofenceRule). `./scripts/verify-mcp.sh` 35항목 통과. `./scripts/build-app.sh` 로 번들을 짓고 세 권한 문구(`NSLocationWhenInUse…`·`NSLocationAlways…`·`NSCalendarsFullAccess…`)가 실제로 들어갔는지 확인했다. 번들 2.8M → **3.4M** (CoreLocation·EventKit 이 늘었다).

## 메모

**위치 기능은 눈으로 확인하지 못했다.** 권한 대화상자·실제 좌표·구역 진입은 전부 이 기계에서 진짜로 움직여 봐야 알 수 있고, 지오펜스는 그 자리에 가야 한다. 규칙(`GeofenceRule`)과 배선은 시험했지만 **`⌥⌘L` 을 한 번 눌러 보는 것과, 켜 둔 채로 어딘가에 도착해 보는 것**은 사용자 몫으로 남는다.

`CLLocationManager.authorizationStatus` 를 정적 접근에서 매번 새 인스턴스로 읽는다. 인스턴스를 오래 들고 있으면 권한이 바뀐 뒤에도 옛 값을 보는 경우가 있어서인데, 이건 실측으로 확인한 것이 아니라 조심한 것이다.