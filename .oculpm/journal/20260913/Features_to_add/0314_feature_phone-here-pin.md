---
schema_version: 1
type: feature
slug: "phone-here-pin"
status: done
difficulty: low
created_at: "2026-09-13T03:14:55+09:00"
session_id: "20260913-002"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/HereFix.swift"
    op: create
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/scripts/uitest.sh"
    op: create
related:
  - ref: "20260913/Features_to_add/0307_feature_phone-ui-first-cut.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1928_feature_here-hotkey-and-geofence.md"
    kind: "followup"
tags:
  - "ios"
  - "location"
  - "privacy"
  - "uitest"
  - "mcp-tool"
---
[x] 폰의 「지금 여기」 — 핀을 누를 때만 묻고 한 번 재고 칩으로 물린다, 그리고 UI 시험 스크립트

## 추가 기능

- **`HereFix`** — 맥 `HereCapture` 의 규칙 그대로: 첫 실행에 묻지 않고 핀을 처음 누를 때 「사용 중」 한 번, 거절하면 「설정에서 위치를 켜야 합니다」, 한 번 재고 끊는다(12초 인내), 좌표만 애플 지오코딩에 보내 주소를 받는다. `CLLocationUpdate.liveUpdates()` 라 권한 창은 시스템이 알아서 띄우고 첫 좌표 하나로 끝.
- 잰 자리는 메모가 되는 게 아니라 **펜에 칩으로 물린다**(`@강남구 …`) — 사람이 글을 덧붙이고 「남기기」. 글이 없으면 자리가 곧 글이다(맥과 같다). 핀은 재는 동안 스피너, 못 재면 칩 자리에 한 줄.
- `NSLocationWhenInUseUsageDescription` 은 README 프라이버시 절의 말투로: 「펜의 핀을 누를 때만 … 저장하지도 내보내지도 않습니다.」
- **`ios/scripts/uitest.sh`** — 맥의 `verify-*.sh` 자리. 시뮬레이터를 띄우고 자리(강남)와 위치 권한을 simctl 로 미리 준 뒤 xcodebuild test. 이름 일부로 하나만 돌릴 수 있다.

## 동작 흐름

- 처음엔 칩이 안 떴다 — `placeChip` 이 `reading.place` 만 보는데 빈 펜은 `InboundNote.make` 가 `nil` 이라 자리가 사라졌다. `here` 를 먼저 보게 하고, `canLeave` 도 자리가 있으면 참.
- 시스템 권한 창을 `addUIInterruptionMonitor` 로 받으려다 접었다 — 시뮬레이터 로캘에 따라 단추 이름이 달라 취약하다. 스크립트가 권한을 미리 준다; 실기기의 첫 누름은 그 창을 진짜로 띄운다.

## 검증

`./ios/scripts/uitest.sh` → **6 tests passed** (지금 여기 포함: 핀 → 칩 `@…` 가 5초 안에 물린다).