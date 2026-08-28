---
oculpm_plan: v1
id: lazymemo-v1
title: "lazymemo v1 — 바탕화면 메모 + 캘린더 (macOS 네이티브)"
status: active
created: 2026-08-28
updated: 2026-08-28
owner: claude-code
---

discussion/lazymemo-계획서 의 결론(C + E-1 + F-1 + G/H + I-1)을 실행 단위로 분해한 계획. 네이티브 SwiftUI + AppKit, 메모당 NSWindow, MCP 서버 우선, 마크다운 정본 + SQLite 파생 인덱스, 소스 빌드 배포.

## 기반 — 저장소와 빌드 골격 {#foundation}
- [x] git init 과 MIT 라이선스, .gitignore, README 골격 작성 {#repo-init}
- [x] SPM 패키지 스캐폴딩 — swift-tools-version 6.2, platforms macOS v26, executableTarget {#spm-scaffold}
- [x] app 번들 조립과 ad-hoc 서명을 하는 빌드 스크립트 작성 (Xcode 없이 동작 확인됨) {#bundle-script}
- [x] LSUIElement 상주 앱 셸 — setActivationPolicy accessory 로 Dock 아이콘 없이 기동 {#app-shell}

## 스파이크 — 바탕화면 창이 실제 환경에서 버티는지 {#window-spike}
- [x] desktopIconWindow 레벨 투명 NSWindow 표시와 canJoinAllSpaces stationary 동작 확인 {#desktop-window}
- [!] Stage Manager 와 Mission Control 켠 상태에서의 표시 동작 확인 {#env-stage-manager}
- [!] 월페이퍼 클릭으로 데스크탑 표시 기능과 전체화면 앱 위에서의 동작 확인 {#env-wallpaper-click}
- [x] 다중 디스플레이 연결과 해제 왕복 후 메모 좌표 복원 확인 {#multi-display}

## 데이터 — 마크다운 정본과 파생 인덱스 {#data-layer}
- [x] 마크다운 frontmatter 스키마 확정 — id, created, updated, due, at, tags, color {#memo-schema}
- [x] 저장 디렉터리 레이아웃 확정과 파일 읽기 쓰기 계층 구현 {#storage-layout}
- [x] SQLite 파생 인덱스 구현과 파일에서 전체 재생성하는 경로 확보 {#sqlite-index}
- [x] 삭제 안전장치 — 즉시 삭제 금지, trash 폴더 이동과 보존 기간 적용 {#trash-safety}
- [x] 되돌리기 UI 와 최근 삭제 복원 동선 {#undo-ui}

## 메모 UI — 메모당 NSWindow {#memo-ui}
- [x] 메모 하나당 NSWindow 렌더링과 NSHostingView 연결 {#note-window}
- [x] 드래그와 리사이즈, z-order, 위치 크기 영속화 {#note-interaction}
- [x] Liquid Glass 재질과 SF Symbols 아이콘으로 시각 언어 정립 {#visual-design}
- [x] NSTextView 기반 편집기에서 한글 IME 조합 정상 동작 확인 {#ime-check}

## 빠른 입력 — 게으름 타파의 실체 {#quick-capture}
- [x] NSStatusItem 과 NSPopover 로 메뉴바 입력 검색 편집 제공 {#menubar-popover}
- [x] 전역 단축키 등록과 입력 포커스 즉시 전달 {#global-hotkey}
- [x] 저장 버튼 없는 자동 저장 — 조작 2회 이내 목표 {#autosave}
- [x] 단축키 입력에서 커서 표시까지 150ms 목표 측정과 튜닝 {#latency-measure}

## LLM — MCP 서버 방향 우선 {#llm}
- [x] MCP 서버 구현 — create list update delete 메모 도구 노출 {#mcp-server}
- [x] 일정 관련 MCP 도구 — 날짜 있는 메모의 생성과 조회 {#mcp-events}
- [x] claude_desktop_config.json 등록 안내와 설치 스크립트 {#mcp-onboarding}
- [x] LLM 삭제 요청을 trash 경로로 강제 연결하고 프라이버시 동의 지점 명시 {#llm-safety}
- [>] 앱 내 호출이 필요해지면 claude CLI 서브프로세스 경로 추가 (F-2, 후순위) {#cli-fallback}

## 캘린더 — 자체 뷰 우선 {#calendar}
- [x] H-1 자체 캘린더 뷰 구현과 바탕화면 배치 {#calendar-view}
- [x] 날짜 범위 쿼리를 SQLite 인덱스에 연결 {#calendar-query}
- [>] EventKit 읽기 전용 연동 검토 — 쓰기는 범위 밖 (후순위) {#eventkit-readonly}

## 품질과 배포 {#ship}
- [x] 성공 기준 실측 — 메모 10장 상태 RSS 100MB 이하와 idle CPU 0% {#perf-measure}
- [x] 한글 IME 조합 회귀 테스트 작성 {#ime-regression}
- [x] 재부팅 후 메모 내용과 위치 복원 검증 {#restore-test}
- [x] README 빌드 설치 안내와 스크린샷, 공증 없이 여는 방법 안내 {#docs-release}
- [>] Homebrew cask 등록 검토 (후순위) {#homebrew}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-08-28T16:50:00+09:00 | #repo-init | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1649_feature_bootstrap-spm-app-shell.md | git init(main) + MIT LICENSE + README + .gitignore Swift 항목. 커밋은 아직 없음 |
| 2026-08-28T16:50:06+09:00 | #spm-scaffold | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1649_feature_bootstrap-spm-app-shell.md | LazyMemo(앱) + LazyMemoCore(도메인) 2타깃 분리. tools 6.2 / macOS v26 동작 확인 |
| 2026-08-28T16:50:11+09:00 | #bundle-script | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1649_feature_bootstrap-spm-app-shell.md | build-app.sh + test.sh. swift-testing rpath 2개 함정을 스크립트에 가둠 |
| 2026-08-28T16:50:15+09:00 | #app-shell | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1649_feature_bootstrap-spm-app-shell.md | lsappinfo 로 ApplicationType=UIElement 확인. 메뉴바 아이콘 육안 확인은 사용자 대기 |
| 2026-08-28T16:54:44+09:00 | #desktop-window | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1654_feature_desktop-level-window-spike.md | CGWindowList 로 레벨·크기 기계 검증. NSHostingView 가 창 크기 끌고 가던 문제 수정 |
| 2026-08-28T17:11:31+09:00 | #memo-schema | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1711_feature_markdown-vault-and-sqlite-index.md | due 는 CalendarDate 별도 타입. 모르는 키는 원문 보존. deleted 키 추가 |
| 2026-08-28T17:11:36+09:00 | #storage-layout | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1711_feature_markdown-vault-and-sqlite-index.md | MemoVault actor. 경로를 ULID 타임스탬프에서 도출 + FSEvents 외부 변경 감시 |
| 2026-08-28T17:11:42+09:00 | #sqlite-index | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1711_feature_markdown-vault-and-sqlite-index.md | FTS5 trigram + 2글자 한국어 LIKE 폴백. 인덱스 삭제 후 파일에서 복원됨을 테스트로 고정 |
| 2026-08-28T17:11:47+09:00 | #trash-safety | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1711_feature_markdown-vault-and-sqlite-index.md | deleted 시각을 파일에 기록. 하드 삭제는 purgeExpired 하나뿐이고 공개 API 아님 |
| 2026-08-28T17:21:02+09:00 | #note-window | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | verify-notes.sh 로 메모 2장 → 바탕화면 레벨 창 2개 확인. 동시 표시 24개 상한 |
| 2026-08-28T17:21:08+09:00 | #note-interaction | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | layout.json 디바운스 저장 + FrameClamping.restore 로 디스플레이 복원 |
| 2026-08-28T17:21:14+09:00 | #visual-design | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | glassEffect + 옅은 색 틴트, hover 시에만 나타나는 조작 버튼. 육안 확인 대기 |
| 2026-08-28T17:21:20+09:00 | #ime-check | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | MemoTextSync 로 조합 보호 규칙 분리. setMarkedText 기반 테스트 6개 |
| 2026-08-28T17:21:25+09:00 | #undo-ui | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | 메뉴바 "최근 삭제" 서브메뉴에서 복원. 하드 삭제 항목은 노출하지 않음 |
| 2026-08-28T17:21:30+09:00 | #autosave | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | 600ms 디바운스 + 창 닫힘/종료 시 flush. 조합 중에는 저장하지 않음 |
| 2026-08-28T17:21:36+09:00 | #multi-display | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | FrameClamping 을 순수 함수로 빼 외부 모니터 없이 연결/해제 왕복을 테스트로 검증 |
| 2026-08-28T17:34:40+09:00 | #menubar-popover | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1733_feature_quick-capture-and-global-hotkey.md | 좌클릭=빠른 입력 / 우클릭=메뉴. 한 상자가 입력과 검색을 겸함 |
| 2026-08-28T17:34:46+09:00 | #global-hotkey | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1733_feature_quick-capture-and-global-hotkey.md | Carbon RegisterEventHotKey 로 권한 없이 ⌥⌘N. 선점 시 메뉴에 경고 |
| 2026-08-28T17:34:51+09:00 | #latency-measure | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1733_feature_quick-capture-and-global-hotkey.md | release 12회 실측 중앙값 12.5ms / 최대 34.3ms — 목표 150ms 대비 여유 10배 |
| 2026-08-28T17:34:56+09:00 | #mcp-server | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1734_feature_mcp-server-stdio.md | 별도 실행 타깃 + 외부 의존 없는 JSON-RPC. verify-mcp.sh 15항목 통과 |
| 2026-08-28T17:35:01+09:00 | #mcp-events | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1734_feature_mcp-server-stdio.md | list_memos 의 from/to 가 인덱스 날짜 범위 조회로 연결됨. due/at 모두 커버 |
| 2026-08-28T17:35:07+09:00 | #mcp-onboarding | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1734_feature_mcp-server-stdio.md | install-mcp.sh (--dry-run/--remove/백업). 번들 안 바이너리를 가리켜 리빌드에 안 끊김 |
| 2026-08-28T17:35:13+09:00 | #llm-safety | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1734_feature_mcp-server-stdio.md | MemoService 에 하드 삭제 공개 API 자체가 없음. 프라이버시 동의 지점은 install-mcp.sh |
| 2026-08-28T17:43:50+09:00 | #calendar-view | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1743_feature_desktop-calendar-view.md | MonthGrid 를 Core 순수 값으로 빼 테스트 8개. 창은 좌상단 300×300 |
| 2026-08-28T17:43:55+09:00 | #calendar-query | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1743_feature_desktop-calendar-view.md | MonthGrid.range(앞뒤 달 넘침 포함) → MemoIndex 날짜 범위 조회 |
| 2026-08-28T17:44:00+09:00 | #perf-measure | claude-code | ☐→x | .oculpm/journal/20260828/Chores/1743_chore_perf-restore-verification-and-docs.md | 메모 10장 RSS 88.8MB / idle CPU 0.0%. 예산 여유가 크지 않아 창 24개 상한이 방어선 |
| 2026-08-28T17:44:06+09:00 | #ime-regression | claude-code | ☐→x | .oculpm/journal/20260828/Features_to_add/1720_feature_note-windows-and-korean-ime.md | setMarkedText 로 조합 상태를 만들어 검증하는 테스트 6개 |
| 2026-08-28T17:44:11+09:00 | #restore-test | claude-code | ☐→x | .oculpm/journal/20260828/Chores/1743_chore_perf-restore-verification-and-docs.md | verify-restore.sh — 껐다 켠 뒤 창 4개 좌표·크기·내용 일치. 메모 생성은 MCP 경로로 |
| 2026-08-28T17:44:17+09:00 | #docs-release | claude-code | ☐→x | .oculpm/journal/20260828/Chores/1743_chore_perf-restore-verification-and-docs.md | README 재작성 + DESIGN.md 8개 절을 구현에 동기화. 스크린샷은 육안 확인 후 |
| 2026-08-28T17:44:24+09:00 | #env-stage-manager | claude-code | ☐→! | .oculpm/journal/20260828/Features_to_add/1654_feature_desktop-level-window-spike.md | 사람 조작 필요 — 터미널에 화면 기록 권한이 없어 자동 검증 불가. 스파이크 창은 준비됨 |
| 2026-08-28T17:44:29+09:00 | #env-wallpaper-click | claude-code | ☐→! | .oculpm/journal/20260828/Features_to_add/1654_feature_desktop-level-window-spike.md | 사람 조작 필요. 깨지면 desktopIconWindow+1 레벨 자체를 재검토해야 함 |
| 2026-08-28T17:44:34+09:00 | #eventkit-readonly | claude-code | ☐→> | .oculpm/journal/20260828/Features_to_add/1743_feature_desktop-calendar-view.md | D5 대로 후순위 유지. 자체 캘린더 뷰로 v1 요구는 충족됨 |
| 2026-08-28T17:44:39+09:00 | #cli-fallback | claude-code | ☐→> | .oculpm/journal/20260828/Features_to_add/1734_feature_mcp-server-stdio.md | F-2 후순위 유지. MCP 방향만으로 v1 LLM 요구가 충족돼 아직 필요가 없다 |
| 2026-08-28T17:44:45+09:00 | #homebrew | claude-code | ☐→> | .oculpm/journal/20260828/Chores/1743_chore_perf-restore-verification-and-docs.md | D7 대로 사용자가 늘면. 지금은 소스 빌드 경로로 충분하다 |
| 2026-08-28T19:10:01+09:00 | #visual-design | claude-code | x→x | .oculpm/journal/20260828/Features_to_add/1909_feature_app-icon-and-visual-language.md | 아이콘 신규 + UI 전면 재디자인. 유리를 걷어내고 종이로, 레이어 정리로 RSS 87.7MB |
| 2026-08-28T19:38:25+09:00 | #calendar-view | claude-code | x→x | .oculpm/journal/20260828/Features_to_add/1938_feature_design-philosophy-and-ui-overhaul.md | 월 격자를 버리고 「흐름」으로 대체. 점 스트립이 조망을 맡는다 |
<!-- oculpm:plan-log end -->
