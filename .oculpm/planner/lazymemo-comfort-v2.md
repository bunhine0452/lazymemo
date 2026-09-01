---
oculpm_plan: v1
id: lazymemo-comfort-v2
title: "lazymemo v2 — 편안함 감사 후속: 새는 것 막고, 앱에 시계를 달고, 스무 장 너머를 연다"
status: done
created: 2026-08-29
updated: 2026-08-31
owner: claude-code
---

2026-08-29 조작·디자인 감사(코드 전량 + build/ui 렌더 육안)에서 나온 19건을 실행 단위로 분해한 계획. 뿌리는 셋이다 — ① 손이 키보드를 덮어쓰는 자리가 있고, ② 앱이 시간에 따라 스스로 하는 일이 하나도 없으며(Sources 전체에 타이머 0개), ③ 목록이 8장·5장에서 끊겨 그 너머로 가는 길이 없다. discussion/lazymemo-lazy-comfort 의 {#next-*} 후보를 이 계획이 이어받는다.

## 새는 것부터 막는다 — 데이터를 잃는 결함 {#stop-the-bleeding}
- [x] 빠른 입력에서 포인터가 목록을 스치기만 해도 ⌘⏎ 가 «적기 끝»에서 «남의 메모 열기»로 바뀌는 것 (QuickCaptureView.swift:173) {#capture-hover-selection}
  - [x] hover 는 조준까지만 — 줄을 벗어나면 그 선택을 도로 놓는다 {#hover-clears-on-exit}
  - [x] ⌘⏎ 와 ⌘⌫ 는 키보드로 고른 것만 본다 — 가리키기만 한 메모가 열리거나 지워지지 않게 {#commit-reads-keyboard-only}
  - [x] 목록이 요즘 것↔찾은 것으로 갈릴 때 남아 있던 인덱스를 무효화 (엉뚱한 메모를 가리키는 것을 막는다) {#invalidate-stale-index}
  - [x] 회귀 시험 — 스치고 ⌘⏎ 하면 내 글이 저장되는가, 스치고 ⌘⌫ 하면 글자가 지워지는가 {#hover-selection-tests}
- [x] 저장 실패가 화면에 나오지 않는다 — MemoStore.lastError 는 쓰기만 하고 아무도 읽지 않는다 {#surface-save-errors}
  - [x] 메뉴 첫머리에 ⚠︎ 한 줄로 마지막 실패를 적고, 다시 성공하면 스스로 사라지게 {#menubar-error-line}
  - [x] NoteModel.persistBody 의 빈 catch — 종이가 «아직 안 적혔다»를 스스로 말하게 {#note-save-failure-mark}

## 앱에 시계를 단다 — 부품 하나로 넷을 푼다 {#the-clock}
- [x] 자정과 다가오는 일정 시각에 깨는 단일 시계 부품 (지금 Sources 전체에 타이머가 0개다) {#day-clock}
- [x] 자정에 today 가 갱신되고 달력·나이·미루기로 전파되게 — CalendarModel.today 가 let 이라 자정 뒤 어제에 머문다 {#today-propagation}
  - [x] 손으로 그린 동그라미·「오늘」 버튼·dayTitle·InkDrying 기준점이 함께 넘어간다 {#calendar-today-refresh}
  - [x] 「미루기」의 notBefore 가 오늘을 가리키게 — 가장 자주 쓰는 동사가 조용히 하루 어긋나 있었다 {#postpone-uses-live-today}
  - [x] MemoAge 가 자정에 다시 계산되게 — 어제 것이 계속 fresh 로 남지 않게 {#memo-age-refresh}
- [x] 휴지통 30일 정리를 시계에 얹는다 — 지금은 기동 시 한 번뿐이라 앱을 안 끄면 무한 보존이다 {#trash-purge-on-clock}
- [x] AttachmentStore.orphans() 를 실제로 부른다 — 구현해 놓고 앱 어디서도 안 부르고 있다 (빠른 입력에서 붙였다 esc 한 사진이 영구히 남는다) {#orphan-attachments}
- [x] at 이 적힌 메모가 그 시각에 스스로 떠오르게 — riseBriefly 를 쓰므로 알림 권한을 요구하지 않는다 {#surface-at-time}
  - [x] 자리를 비웠을 때 놓친 것을 달력 머리에 모아 둔다 {#missed-list}

## 재부팅을 넘긴다 — 안 켜지면 나머지는 의미가 없다 {#survive-reboot}
- [x] 로그인할 때 시작 — SMAppService.mainApp 등록과 설정 메뉴의 켬/끔 (권한 불필요) {#login-item}
- [x] 첫 실행에 바탕화면에 안내 종이 한 장 — 별도 온보딩 화면을 만들지 않는다 (discussion #next-welcome-note) {#welcome-note}

## 스무 장 너머 — 목록이 8장·5장에서 끊긴다 {#beyond-twenty}
- [x] 빠른 입력 목록에 «… 외 N장 더» 한 줄 — 누르거나 끝에서 ↓ 를 한 번 더 누르면 넓어진다 {#capture-more}
- [x] 검색 결과 5개 상한을 넓히고 넘친 것이 있다는 사실을 화면에 적는다 {#search-limit-raise}
- [x] 끝난 것이 스스로 물러난다 — 다 체크한 목록과 지난 일정을 일정 기간 뒤 숨김으로 (삭제가 아니다) {#auto-tidy}
  - [x] 무엇을 며칠 뒤 치우는지 규칙을 LazyMemoCore 에 두고 시험으로 못 박는다 {#tidy-rule}
  - [x] «치워 둔 N장» 을 메뉴에 적고 한 번에 되돌리는 길을 둔다 — 사라졌다고 오해하면 실패다 {#tidy-visible-undo}

## 손이 걸리는 자리 {#operation-polish}
- [x] 바탕화면 종이가 창 단위 전환기(AltTab 류)에 줄줄이 선다 — 메모 열 장이면 알트탭에 열 칸이 생긴다 {#notes-in-window-switcher}
- [x] 겹쳐 뜨는 조작 줄이 첫 줄을 덮는다 — 260pt 종이에서 캡슐이 110pt라 읽으려고 올린 포인터가 제목을 가린다 {#controls-overlap}
- [x] 빠른 입력 목록의 붉은 휴지통 다섯 개가 세로 기둥을 이룬다 — 가장 반복되는 요소가 가장 위험한 조작이 되지 않게 {#capture-trash-column}
- [x] 메뉴 목록만 시스템 파랑으로 강조된다 (MemoRow.draw) — 빠른 입력과 같은 종이색 낱말로 {#menu-highlight}
- [x] 종이의 휴지통만 인라인 되돌리기가 없다 — 창이 사라지고 화면에 흔적이 하나도 안 남는다 {#note-inline-undo}

## 달력을 규칙 안으로 {#calendar-rules}
- [x] 달력 줄에서 지우는 길 — 「미루기」·「종이로」는 있는데 지우기만 없어 §6 의 «지우는 길이 셋»이 여기서 뚫려 있다 {#calendar-row-delete}
- [x] 달력에서 일정을 읽으려고 누르면 layout.json 에 «꺼내 뒀다»로 기록돼 종이가 영구히 남는다 — 보는 것과 꺼내는 것을 가른다 {#calendar-read-not-place}

## 종이 언어 다듬기 {#paper-language}
- [x] 다크 모드에서 여섯 색이 다시 같은 종이가 된다 — 빛 모드에서 했던 palette 검사를 다크에서도 하고 스밈·채도 상한을 따로 잡는다 {#dark-palette}
- [x] 달 격자의 잉크 얼룩이 인쇄 얼룩처럼 보인다 — 1개와 4개가 구별되게 폭과 대비를 올린다 {#ink-bleed-legible}
- [x] 요일 줄이 8.5pt·불투명도 0.28 이라 미색 종이 위에서 표시가 아니라 흔적이 된다 {#weekday-contrast}
- [x] SwiftUI 쪽에 accessibilityLabel 이 한 건도 없다 — QuietButton 을 VoiceOver 가 «trash» 로 읽는다 {#swiftui-a11y}

## 문서와 코드를 맞춘다 {#docs-truth}
- [x] 설계문서 §5.1 이 «설정으로 이동 가능» 이라 적었지만 Settings 에는 그 항목이 없다 — 설정에 넣거나 문서에서 뺀다 {#vault-location}
- [x] 이 계획으로 달라진 것을 DESIGN.md·README 에 반영하고 discussion/lazymemo-lazy-comfort 를 닫는다 {#doc-sync}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-08-29T17:28:24+09:00 | #hover-clears-on-exit | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1728_bug_capture-hover-stole-keyboard-choice.md | pointed: ULID? 를 새로 두고 줄을 벗어나면 놓는다 |
| 2026-08-29T17:28:30+09:00 | #commit-reads-keyboard-only | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1728_bug_capture-hover-stole-keyboard-choice.md | commit·deleteSelected·힌트 줄이 selectedID 만 본다. 화면도 색/무채로 갈랐다 |
| 2026-08-29T17:28:36+09:00 | #invalidate-stale-index | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1728_bug_capture-hover-stole-keyboard-choice.md | 선택 근거를 인덱스에서 ULID 로. clampSelection → dropSelectionIfGone |
| 2026-08-29T17:28:41+09:00 | #hover-selection-tests | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1728_bug_capture-hover-stole-keyboard-choice.md | CaptureHoverTests 7건 신설. 옛 clamp 기대는 결함이라 뒤집었다 (268개 통과) |
| 2026-08-29T17:34:29+09:00 | #menubar-error-line | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1734_bug_save-failures-never-reached-screen.md | lastError→Trouble(doing/detail). 쓰기 넷을 recording 으로 감싸고 메뉴 첫머리가 읽는다 |
| 2026-08-29T17:34:35+09:00 | #note-save-failure-mark | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1734_bug_save-failures-never-reached-screen.md | NoteModel.isUnsaved + 꼬리 위 「아직 안 적혔습니다」 + 3초·3회 재시도 |
| 2026-08-29T17:45:27+09:00 | #day-clock | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | DayClock 신설 — NSCalendarDayChanged + 다음 자정까지의 잠, 두 길. tick 은 날짜가 바뀔 때만 일한다 |
| 2026-08-29T17:45:32+09:00 | #calendar-today-refresh | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | CalendarModel.today 를 var 로. 오늘을 보고 있었으면 고른 날도 따라간다 |
| 2026-08-29T17:45:38+09:00 | #postpone-uses-live-today | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | CalendarDayChangeTests 가 8/30→8/31 로 기준이 넘어가는 것을 못 박는다 |
| 2026-08-29T17:45:43+09:00 | #memo-age-refresh | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | NoteModel.asOf 를 뷰가 읽는다 — Date() 를 뷰에서 부르면 다시 그려질 이유가 없었다 |
| 2026-08-29T17:45:49+09:00 | #trash-purge-on-clock | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | MemoStore.tidy() 로 묶어 start() 와 하루마다 부른다 |
| 2026-08-29T17:45:55+09:00 | #orphan-attachments | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1745_feature_day-clock-app-finally-knows-time.md | discardOrphans/purgeTrashed 신설. 안전장치 셋 — 휴지통 메모의 사진도 참조 · 7일 유예 · 지우지 않고 옮긴다 |
| 2026-08-29T17:52:03+09:00 | #missed-list | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1751_feature_due-time-surfaces-the-paper.md | 모양이 바뀌었다 — 별도 목록 대신 꺼낸 종이가 그대로 남는다. 놓친 것이 곧 화면의 종이 |
| 2026-08-29T17:53:54+09:00 | #calendar-read-not-place | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1753_bug_calendar-read-click-moved-the-place.md | reveal(keepingPlace:) 로 달력만 자리를 안 옮긴다. 메뉴·빠른 입력은 낱말대로 꺼내는 일이 맞다 |
| 2026-08-29T17:57:23+09:00 | #login-item | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1757_feature_survive-reboot-login-item-welcome.md | SMAppService + 설정 맨 위 스위치. 기본값 꺼짐 — 켜짐으로 둘지는 사용자 결정 대기 |
| 2026-08-29T17:57:29+09:00 | #welcome-note | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1757_feature_survive-reboot-login-item-welcome.md | 온보딩 화면 대신 메모 한 장. greeted + memoCount 둘을 함께 봐서 두 번 안 놓는다 |
| 2026-08-29T18:24:02+09:00 | #notes-in-window-switcher | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1823_bug_notes-stood-in-window-switcher.md | NSWindow→NSPanel + accessibilitySubrole=AXFloatingWindow. hidesOnDeactivate 끄는 것이 짝이다 |
| 2026-08-29T19:13:06+09:00 | #tidy-rule | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1913_feature_tidy-finished-memos-retreat.md | Tidy 규칙 Core 에, 경계 9건 시험 |
| 2026-08-29T19:13:11+09:00 | #tidy-visible-undo | claude-code | ☐→x | .oculpm/journal/20260829/Features_to_add/1913_feature_tidy-finished-memos-retreat.md | 메뉴 «치워 둔 N장 — 까닭» + 도로 꺼내기, verify-tidy.sh |
| 2026-08-29T19:21:34+09:00 | #controls-overlap | claude-code | ☐→x | .oculpm/journal/20260829/Bugs/1921_bug_controls-no-longer-cover-title.md | ×는 위, 나머지 넷은 아래 — 첫 줄 덮는 폭 92pt→6pt |
| 2026-08-29T19:57:00+09:00 | #weekday-contrast | antigravity | ☐→x | .oculpm/journal/20260829/Refactors/1957_refactor_pro-stationery-icon-and-ui-polish.md | 요일 폰트 10.5/9.5pt + 불투명도 0.85/0.65로 상향, 프로페셔널 HIG 아이콘 개편 |
| 2026-08-31T13:06:12+09:00 | #capture-more | claude-code | ☐→x | .oculpm/journal/20260831/Features_to_add/1304_feature_capture-list-beyond-twenty.md | «… 외 N장 더» + 끝에서 ↓ 한 번 더. listed 를 pool 의 계산 속성으로 |
| 2026-08-31T13:06:18+09:00 | #search-limit-raise | claude-code | ☐→x | .oculpm/journal/20260831/Features_to_add/1304_feature_capture-list-beyond-twenty.md | 화면 5/20줄과 세어 오는 200줄을 갈랐다 — 남은 수를 정직하게 적는다 |
| 2026-08-31T13:06:25+09:00 | #capture-trash-column | claude-code | ☐→x | .oculpm/journal/20260831/Refactors/1305_refactor_paper-words-in-the-dark.md | 평상시엔 종이 잉크색, 붉은색은 그 휴지통에 손이 닿았을 때만. RowTrash 로 공용화 |
| 2026-08-31T13:06:31+09:00 | #menu-highlight | claude-code | ☐→x | .oculpm/journal/20260831/Refactors/1305_refactor_paper-words-in-the-dark.md | MemoRow.highlightFill — 그 메모의 종이색 20%. 글자 색은 함께 뒤집지 않는다 |
| 2026-08-31T13:06:37+09:00 | #note-inline-undo | claude-code | ☐→x | .oculpm/journal/20260831/Features_to_add/1304_feature_undo-lines-where-you-deleted.md | justDeleted 로 창이 8초 남는다. prune 이 휴지통의 자리까지 남겨 되살린 종이가 제자리로 |
| 2026-08-31T13:06:44+09:00 | #calendar-row-delete | claude-code | ☐→x | .oculpm/journal/20260831/Features_to_add/1304_feature_undo-lines-where-you-deleted.md | 줄 끝에 RowTrash + 바닥의 되돌리기. 지우기와 「종이로」는 다른 동사라 안 묶었다 |
| 2026-08-31T13:06:52+09:00 | #dark-palette | claude-code | ☐→x | .oculpm/journal/20260831/Refactors/1305_refactor_paper-words-in-the-dark.md | PaperTint.light/.dark 로 스밈·채도·밝기를 갈랐다. 가장 닮은 두 장의 거리를 시험이 잰다 |
| 2026-08-31T13:06:59+09:00 | #ink-bleed-legible | claude-code | ☐→x | .oculpm/journal/20260831/Refactors/1305_refactor_paper-words-in-the-dark.md | 폭 0.11+0.22s, 세기 0.30+0.58s. 1개와 4개가 1.4배 이상 갈리는 것을 시험이 못 박는다 |
| 2026-08-31T13:07:05+09:00 | #swiftui-a11y | claude-code | ☐→x | .oculpm/journal/20260831/Refactors/1305_refactor_paper-words-in-the-dark.md | SpokenHelp — 붙어 있던 도움말을 「—」로 갈라 이름과 힌트로. 새 낱말을 만들지 않았다 |
| 2026-08-31T13:07:11+09:00 | #vault-location | claude-code | ☐→x | .oculpm/journal/20260831/Features_to_add/1305_feature_vault-can-actually-move.md | 문서에서 빼지 않고 설정에 넣었다 — 빼면 «옮기면 동기화» 약속의 구멍이 그대로 남는다 |
| 2026-08-31T13:07:18+09:00 | #doc-sync | claude-code | ☐→x | .oculpm/journal/20260831/Chores/1306_chore_docs-catch-up-with-code.md | DESIGN §5.1·§6·§8·§8.2·§14.10·§14.11 + README. lazy-comfort 는 결론 쓰고 resolved |
<!-- oculpm:plan-log end -->
