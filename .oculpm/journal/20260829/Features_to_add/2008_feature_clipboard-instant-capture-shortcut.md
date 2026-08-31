---
schema_version: 1
type: feature
slug: clipboard-instant-capture-shortcut
status: done
created_at: 2026-08-29T20:08:15+09:00
session_id: "manual-20260829-200815"
agent:
  id: antigravity
  version: gemini-3.7-flash
language: ko
verified_by_user: false
files_touched:
  - path: Sources/LazyMemoUI/QuickCapture/Hotkey.swift
    op: update
  - path: Sources/LazyMemoUI/QuickCapture/HotkeyManager.swift
    op: update
  - path: Sources/LazyMemoUI/QuickCapture/ClipboardCapture.swift
    op: create
  - path: Sources/LazyMemoUI/MenuBar/MenuBarController.swift
    op: update
  - path: Tests/LazyMemoUITests/ClipboardCaptureTests.swift
    op: create
  - path: README.md
    op: update
related:
  - .oculpm/planner/lazymemo-comfort-v2.md
  - .oculpm/discussion/lazymemo-pro-lazy-ux/discussion.md
tags: [clipboard, hotkey, quick-capture, zero-friction, shortcuts]
---

[x] 클립보드 원키 즉시 캡처 (⌥⌘V) 단축키 및 메뉴 연동

## 추가 기능
게으른 사용자가 웹 브라우저나 문서에서 텍스트/이미지를 복사(⌘C)한 뒤, 창을 열고 타이핑할 필요 없이 **`⌥⌘V` 단축키 한 번으로 바탕화면에 즉시 메모나 일정으로 저장**되도록 하는 기능을 추가했다.

## 동작 흐름
1. `HotkeyManager`에 다중 단축키(ID 기반) 등록 지원을 추가하고, `Hotkey.paste`(`⌥⌘V`)를 기본 글로벌 단축키로 등록.
2. `ClipboardCapture`:
   - `NSPasteboard`에서 이미지 데이터(PNG/TIFF/JPEG)가 있으면 `AttachmentStore`에 자동 저장하고 `![](attachments/<ulid>.<ext>)` 마크다운 생성.
   - 텍스트가 있으면 `NaturalDateParser`로 날짜/시간을 자동 추출하여 `due`/`at` 메타데이터를 채움.
   - 일정이면 달력에 알리고(`announce(day)`), 일반 메모면 바탕화면 종이가 잠깐 앞으로 떠올랐다 내려앉음(`windows.announce(memo)`).
   - 클립보드가 비어있거나 공백뿐이면 불필요한 빈 메모 생성을 방지.
3. 메뉴바 상태 메뉴에 "클립보드 즉시 메모 (`⌥⌘V`)" 항목 추가.

## 검증
- `Tests/LazyMemoUITests/ClipboardCaptureTests.swift` 4개 단위 테스트 신설 (일반 텍스트, 일정 포함 텍스트, 이미지 캡처, 빈 클립보드 무시).
- `./scripts/test.sh` 단위 테스트 338개 전체 통과.
