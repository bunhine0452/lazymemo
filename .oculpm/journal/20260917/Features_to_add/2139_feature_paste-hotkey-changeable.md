---
schema_version: 1
type: feature
slug: "paste-hotkey-changeable"
status: done
difficulty: low
created_at: "2026-09-17T21:39:13+09:00"
session_id: "20260917-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyRecorder.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260828/Features_to_add/2221_feature_multiline-capture-bubble-and-settings.md"
    kind: "followup"
tags:
  - "hotkey"
  - "settings"
  - "mac"
  - "quick-capture"
  - "mcp-tool"
---
[x] 클립보드 즉시 메모(⌥⌘V)도 설정에서 단축키를 바꿀 수 있다

사용자: 「옵션+커맨드+V 명령어도 수정 가능하게 해주고」. 빠른 입력(⌥⌘N)만 바꿀 수 있었다.

## 추가 기능

- `Settings.pasteHotkeyKeyCode`·`pasteHotkeyModifiers` — `nil` 이면 기본 ⌥⌘V (빠른 입력과 같은 규칙: 사용자가 정한 것만 파일에 남는다).
- 메뉴 → 설정에 「클립보드 즉시 메모 단축키 바꾸기…」(부제 「지금은 ⌥⌘V」). 기존 항목의 부제는 「빠른 입력 — 지금은 ⌥⌘N」으로 — 둘이 되고부터는 무엇의 단축키인지 말해 줘야 한다. 녹음 패널 머리에도 그 이름이 선다(`HotkeyRecorder.begin(current:title:apply:)`).
- 메뉴의 「클립보드 즉시 메모」 항목 오른쪽 표기가 지금 조합을 따른다. 등록 실패(다른 앱 선점)는 빠른 입력처럼 메뉴 머리에 ⚠︎ 한 줄.
- 두 단축키를 같은 조합으로 못 만든다 — 한쪽이 조용히 죽는 것을 그 자리에서 막고 「⌥⌘V 은 빠른 입력이 쓰고 있습니다」로 말한다. `apply` 가 `Bool` 대신 까닭 한 줄(`String?`)을 돌려주게 바꿨다.

## 동작 흐름

시작 → `storedPasteHotkey()` 로 id 2 등록 → 설정 메뉴에서 누르면 → 녹음 패널이 조합을 받아 → 등록 시도(실패하면 쓰던 것을 도로 걸고 까닭 표시) → 성공하면 `settings.update` 로 파일에.

## 검증

- `swift build` 무경고(변경 파일), 전체 Swift 시험 통과. 녹음 패널을 실제로 눌러 보는 손검증은 하지 않았다 — 빠른 입력 것과 같은 길이라 코드 경로만 같음을 확인.