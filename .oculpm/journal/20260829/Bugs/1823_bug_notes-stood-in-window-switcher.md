---
schema_version: 1
type: bug
slug: "notes-stood-in-window-switcher"
status: done
difficulty: medium
created_at: "2026-08-29T18:23:55+09:00"
session_id: "20260829-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/DesktopLevelWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "scripts/verify-notes.sh"
    op: update
related: []
tags:
  - "window"
  - "accessibility"
  - "alt-tab"
  - "nspanel"
  - "mcp-tool"
---
[x] 바탕화면 종이가 알트탭에 줄줄이 서던 것 — 창을 표준 창으로 소개하고 있었다

## 발생 원인

앱 전환기(⌘Tab) 쪽은 이미 막혀 있었다 — `LSUIElement` + `.accessory` 로 앱이 목록에 안 뜨고, `collectionBehavior` 의 `.ignoresCycle` 로 ⌘` 창 순환에서도 빠진다.

막히지 않은 것은 **창 단위 전환기**(AltTab 류)였다. 그쪽은 앱 목록이 아니라 **접근성 API 로 창을 훑고**, 역할(subrole)로 거른다. `DesktopLevelWindow` 는 `NSWindow` 였고 그 역할은 `AXStandardWindow` 다 — 그래서 메모가 열 장이면 전환기에 열 칸이 생겼다. 바탕화면에 눕혀 둔 쪽지가 브라우저·에디터와 나란히 서는 것은 이 앱이 하려는 말과 정반대다.

**이것은 화면으로 확인할 수 없는 종류다.** 표준 창이든 떠 있는 창이든 그림은 똑같고, 다른 점은 다른 앱이 이 창을 목록에 넣느냐뿐이라 렌더에도 캡처에도 안 잡힌다.

## 해결 방법

두 단계로 내려갔다. 중간 결과를 남겨 둔다 — 첫 단계만으로는 부족했기 때문이다.

1. `NSWindow` → **`NSPanel`.** 역할이 `AXStandardWindow` 에서 벗어난다. 다만 여기서 `AXDialog` 가 나왔는데, **대화상자도 전환기가 목록에 넣는다.** 게다가 사실도 아니다 — 대화상자는 사람이 답해야 넘어가는 물건이고 이 종이는 그냥 쪽지다.
2. `accessibilitySubrole()` 을 **`AXFloatingWindow`** 로 밝힌다. 이 창의 실제 성격이고, 보조 기술에도 그 편이 옳다.

**패널로 바꾸면서 반드시 함께 꺼야 하는 것이 있다 — `hidesOnDeactivate`.** 패널의 기본값은 켜짐이라 그대로 두면 **다른 앱을 쓰는 순간 메모가 통째로 화면에서 사라진다.** 바탕화면 메모는 앱이 비활성인 동안이 삶의 대부분이므로 그건 곧 앱이 없어지는 것이다. `QuickCapturePanel` 이 같은 함정을 이미 겪었고("눌러도 안 보인다"), 그 주석이 이번에 길을 알려 줬다.

곁들여 `isExcludedFromWindowsMenu` 도 켰다.

## 검증

- **`verify-notes.sh` 에 창 역할 검사를 붙였다.** 앱 안에서 `DesktopLevelWindow.roleDiagnostics` 를 찍어 `subrole` · 표준창 여부 · 순환제외 · 비활성숨김을 한 줄로 내보내고, 스크립트가 `AXFloatingWindow` 이면서 `비활성숨김=false` 일 때만 통과시킨다. 누군가 `NSPanel` 을 `NSWindow` 로 되돌리면 그 자리에서 걸린다 — 안 그러면 알트탭에 메모가 도로 서는 것을 며칠 뒤에나 안다 (§14.9).
- 실측: `subrole=AXFloatingWindow 표준창=false 순환제외=true 비활성숨김=false`, 바탕화면 레벨 창 3개 그대로.
- `./scripts/test.sh` 313개 통과 · `verify-restore.sh` 창 좌표·크기·내용 복원 통과 · `verify-capture.sh` 다른 앱이 앞에 있어도 빠른 입력이 올라옴 · `verify-due-surface.sh` 통과.

## 메모

전환기 쪽에서 "표준이 아닌 창까지 전부 보이기" 를 켜 둔 사용자에게는 앱이 할 수 있는 일이 없다. 그때는 그 도구의 제외 목록에 lazymemo 를 넣어야 한다.