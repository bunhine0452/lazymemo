---
schema_version: 1
type: chore
slug: "peek-papers-real-screen-verified"
status: done
difficulty: medium
created_at: "2026-09-21T18:46:26+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/verify-peek.sh"
    op: create
  - path: "scripts/verify-peek.swift"
    op: create
related:
  - ref: "20260920/Features_to_add/0157_feature_peek-papers-hotkey.md"
    kind: "followup"
tags:
  - "mac"
  - "windows"
  - "hotkey"
  - "verification"
  - "comfort"
  - "mcp-tool"
---
[x] 「종이 보기」 ⌥⌘P 를 실제 화면에서 손검증 — 브라우저 위로 서고, 4초 뒤 눕고, 누른 종이만 남는다

## 한 일

어제 일지가 「실제 화면은 손으로 보지 않았다 — 레벨 값만 확인」이라고 남긴 항목을 닫았다. 이 화면은 브라우저·Ocul-PM 창이 늘 꽉 차 있어 바탕화면 높이의 종이는 평소 보이지 않는다 — 그 조건 그대로에서 검증했다.

- 디버그 빌드를 임시 vault(메모 두 장)로 띄우고, `CGEvent` 로 진짜 ⌥⌘P 키 이벤트를 넣고(설치된 0.9.3 판이 같이 돌고 있어도 그쪽은 이 조합을 안 잡는다), `CGWindowListCopyWindowInfo` 로 창 레벨을 읽고, `screencapture` 로 화면을 찍어 눈으로 봤다.
- 결과 (전부 ✓): 누르자 두 장이 `focusedLevel`(2) 로 올라 Ocul-PM 창 위에 보였다(스크린샷) → 4.3~4.4초 뒤 스스로 `desktopLevel` 로 내려앉았다 → 서 있는 동안 다시 누르면 곧바로 내려앉았다 → 서 있는 동안 종이 한가운데를 클릭하면 그 종이만 키 윈도로 남고(캐럿이 선 것을 스크린샷에서 확인) 다른 장은 4초 뒤 내려앉았다.
- 이 손검증을 `scripts/verify-peek.sh` + `scripts/verify-peek.swift` 로 옮겼다 — `verify-drawer-mouse.sh` 와 같은 결(합성 HID 이벤트, 손쉬운 사용 권한 전제). 스크린샷은 스크립트에 넣지 않았다(샌드박스 안에서 `screencapture` 가 멈춘다).

## 검증

- `./scripts/verify-peek.sh` ✓ (세 번 연속). 첫 시도에서 「종이가 사라졌다」로 보인 것은 드라이버가 겹친 두 종이 중 뒤쪽 종이의 자리를 눌러 앞쪽 종이를 맞힌 것과, 빈 목록에 `allSatisfy` 가 참이 되던 검사 버그 — 둘 다 드라이버 쪽이었고 앱은 정상.
- macOS 27 의 `desktopIconWindow` 레벨은 -2147483603 (INT32_MIN 근처) — 앱이 계산한 `desktopLevel` 과 CGWindowList 의 `kCGWindowLayer` 가 같은 값이라 검증에 문제없다.

## 메모

- 사람이 직접 볼 것으로 남는 것: 없음. 다른 Space·Stage Manager·다중 디스플레이는 이 스크립트가 다루지 않는다.
- 스크린샷은 세션 scratchpad 에만 두고 저장소에 넣지 않았다(용량 규칙 7).