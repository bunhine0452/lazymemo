---
schema_version: 1
type: feature
slug: "settings-window-grouped-form"
status: done
difficulty: medium
created_at: "2026-09-18T16:51:30+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Settings/SettingsScreen.swift"
    op: create
  - path: "Sources/LazyMemoUI/Settings/SettingsWindow.swift"
    op: create
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/HotkeyRecorder.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NSViewSearch.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "scripts/render-settings.sh"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260917/Chores/1311_chore_convenience-audit-research-note.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1541_feature_spotlight-index-mac-ios.md"
    kind: "followup"
tags:
  - "mac"
  - "settings"
  - "ux"
  - "hig"
  - "swiftui"
  - "l10n"
  - "mcp-tool"
---
[x] 설정을 창으로 — 「lazymemo 설정」(⌘,) 한 판, 여섯 묶음과 바닥 글, 문구 손질

## 추가 기능

사용자: 「설정 디자인과 문구를 업그레이드해줘」(메뉴바 → 설정 하위 메뉴 화면을 붙여서). 하위 메뉴는 「항목이 몇 개뿐」이던 때의 결정인데 열넷이 됐고 줄마다 두 줄 설명이 붙어 화면 반을 차지했으며, 켜고 끄는 것·여는 것·상태만 적은 것이 같은 모양으로 섞였다.

**창으로 옮겼다.** 메뉴에는 「설정…」(⌘,) 한 줄. 근거는 HIG Settings(macOS) 원문 — "When people choose the Settings item … your custom settings window opens" · "Command-Comma" · 판이 하나면 제목은 *App Name Settings* → 「lazymemo 설정」 · 최소화·확대 단추 없음 · "Minimize the number of settings … hard to find a particular setting". `Form(.grouped)` 한 판, 묶음은 **무엇을 건드리는가**로: 입력(단축키 둘은 키캡 + 「바꾸기…」, 로그인 시작) · 종이(투명도 segmented, 링크 카드) · 메모가 있는 곳(경로 + 열기·옮기기…, iCloud 상태/단추) · 자리(가면 꺼내기, 지금 여기 권한 상태, 가는 길 묻기) · 함께 보기(시스템 일정, Spotlight) · 알림(켜짐/꺼짐 + 설정…), 판에 따라 Claude · 업데이트. 앞선 판의 부제(«기기 밖으로 나가지 않습니다» 류)는 묶음의 **바닥 글**로 — 줄은 «이름 — 스위치» 하나로 통일되고 §9.3 의 «무엇이 나가는가» 는 켜는 자리 밑에 그대로.

**문구**: 「가면 떠오르게 하기」→「적어 둔 자리에 가면 그 종이 꺼내기」· 「시스템 캘린더 함께 보기」→「달력에 시스템 일정 함께 보기」· 「알림…」→「이 기기에서 알림 — 켜짐/꺼짐 · 설정…」. 나머지는 이 앱의 낱말 그대로. 영어 표 33줄 추가, 하위 메뉴가 쓰던 23줄 정리.

## 동작 흐름

값의 주인이 제각각(설정 파일·`LoginItem`·`SpotlightCenter`·`PlaceWatcher`·`Updater`·`ReminderCenter`)이라 창은 **사진 한 장**(`SettingsState`)을 본다 — `MenuBarController.settingsSnapshot()` 이 찍고, 손을 대면(`SettingsActions`, 전부 컨트롤러의 기존 손) `SettingsScreenModel.perform` 이 다시 찍는다(+600ms 뒤 한 번 더 — 시스템에 묻는 것은 답이 늦다). 권한 창·Finder 에 다녀오면 `didBecomeActive` 에 한 번 더. 단축키 녹음 뒤 `HotkeyRecorder.close` 가 앱을 물러나게 하던 것은 설정 창이 열려 있으면 안 한다(`keepsAppActive`). 창은 SwiftUI 가 크기를 정한 **다음 턴**에 화면에 맞춘다(`fit` — 화면보다 길면 판이 스크롤). `MenuBarController` 는 하위 메뉴·항목 짓기·토글 셀렉터가 빠져 972→약 900줄.

## 검증

- `swift build` ✓ · `./scripts/test.sh` 956 초록 · `./scripts/check-l10n.sh` LazyMemoUI 빠짐 0 (남은 23 빠짐은 PreviewRenderer·DemoTour 의 예전 시연 문장 — 이 변경과 무관).
- `./scripts/render-settings.sh` — `LAZYMEMO_SETTINGS=<png>` 로 창이 스스로 그린 그림 두 장(위·끝). 여덟 묶음 전부 확인, 폴더 줄 한 줄 유지.
- 합성 마우스로 「링크를 카드로 펼치기」를 눌러 `settings.json` 에 `embedsLinks: false` 가 적히고 스위치가 꺼지는 것을 확인(창이 키가 되면 강조색이 든다). 사람 손 없이 뜬 앱은 활성화되지 못해 창이 남의 창 뒤에 서므로 검증 때만 창을 올린다(`liftedForVerification`).
- 사람 눈: 메뉴 → 설정…, ⌘, · 단축키 바꾸기 뒤 창으로 돌아오는가 · 「옮기기…」·「iCloud 로 동기화…」 뒤 값이 새로 찍히는가.

## 메모

- 알림은 아직 별도 창(`RecallWindow.settings`)이다 — 설정 창 안에 「설정…」 단추로 잇는다. 나중에 판 안으로 들일 수 있다.
- 「메모 폴더 열기」·「시작하기 및 사용 안내…」는 메뉴에 그대로 — 설정이 아니라 일이다(HIG: task-specific options stay in place).