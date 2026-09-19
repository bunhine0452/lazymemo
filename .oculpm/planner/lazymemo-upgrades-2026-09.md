---
oculpm_plan: v1
id: lazymemo-upgrades-2026-09
title: "업그레이드 로드맵 2026-09 — 안전망부터, 폰에서도 「앱을 열지 않는다」까지"
status: active
created: 2026-09-16
updated: 2026-09-16
owner: claude-code
---

2026-09-16 조사에서 나온 방안을 권한 비용·의존 순으로 묶었다. 이미 다른 플랜에 있는 것(로컬 비서·알림 실기기·스토어 제출)은 넣지 않았다. 순서는 권장이고, 각 phase 안의 항목은 독립적이다. 기준은 셋 — 첫 실행에 아무것도 묻지 않는다 · 파일이 정본이고 서버가 없다 · 앱은 자기를 드러내지 않는다.

## 엔지니어링 안전망 — 나머지 전부의 바닥 {#safety}
- [x] push·PR CI — .github/workflows/ci.yml 이 macos-26 에서 scripts/test.sh 를 돌린다 (지금은 태그 릴리스·pages 만). SwiftPM artifacts 캠시, 같은 ref 는 앞 것 취소, 문서·일지만 바뀜 땐 건너뛴다 {#ci-push}
- [~] 릴리스를 Developer ID 서벅·공증으로 — build-app.sh 의 LAZYMEMO_SIGN_IDENTITY·NOTARY_PROFILE 경로를 release.yml 이 탄다(인증서·프로필은 secrets). cask 의 검역 딝지 떼기와 README 「미공증」 문단 삭제, homebrew-core 문 열기 {#notarize}
- [ ] 800줄 한계 초과 — CalendarView.swift 1035·MenuBarController.swift 880·PreviewRenderer.swift 864 를 결 따라 나눈다 (달력은 판형·펜 자국·드래그) {#split-large-files}
- [ ] MetricKit 진단 — 충돌·행 로그를 기기 안에 모아 「진단 내보내기」 메뉴. 서버 없음, 프라이버시 표에 한 줄 {#metrickit}
- [ ] MCP resources — 오늘 일정·메모 하나를 리소스로 내놓아 Claude Desktop 이 도구 호출 없이 문맥으로 첨부한다 (main.swift 에 케이스 하나) {#mcp-resources}
- [ ] macOS 26 Writing Tools 가 NSTextView 에 이미 켜져 있는지 확인 — App Store 판(claude 없음)의 ✧ 다듬기 대체로 안내만 하면 되는지 {#writing-tools-check}

## 드러내지 않는 통합 — 권한 0, 반나앝씩 {#quiet-integration}
- [x] Core Spotlight 색인 — MemoIndex 갱신 지점에서 제목·본문을 CSSearchableIndex 로. 맥·폰 둘 다, 열면 그 메모 {#spotlight}
- [-] 중복 알림 — 빠른 입력 도중 FTS 로 「비슷한 메모가 있다」 한 줄. LLM 없이, 측정 없이 키 입력을 막지 않는다 {#dup-hint}
- [ ] 집중 모드 필터 — SetFocusFilterIntent 로 「업무」집중이면 그 폴더 종이만 바탕화면에. 폴더는 자리가 아니라 칸이라는 서랍 철학 유지 {#focus-filter}

## 폰에서도 「앨을 열지 않는다」 {#phone-no-open}
- [ ] App Intents — 「lazymemo 에 적기」·「오늘 뭐 있어」를 인텐트로. Siri·단축어·액션 버튼(iPhone 15 Pro)·맥 Spotlight. 같은 Inbound 파서를 지나는 정식 문 — iCloud 폴더에 .md 떨구는 우회로를 대체 {#app-intents}
- [ ] 잠금 화면 컨트롤(ControlWidget 「적기」→펜) + 홈 위젯(「지금」 세 장 읽기 전용, Recall.swift 선정 그대로). RECALL_PLAN 「다음 실험」을 실행으로 {#lock-widget}

## 사진과 소리가 글이 된다 {#photo-text}
- [ ] 사진 OCR — 붙인 사진의 글자를 Vision 으로 읽어 FTS 에 넣고 NaturalDateParser 에 태운다. 「찍으면 일정이 된다」. 기기 안에서만, 한국어 지원 확인 {#photo-ocr}
- [ ] 폰에서 사진 붙이기 — MOBILE_DESIGN §16 의 「다음 판」. 카메라→OCR→일정이 한 동작이 되게 photo-ocr 과 벙미 {#phone-photo-attach}
- [ ] 받아쓰기 — SpeechTranscriber(온디바이스) 눌러서 말하기만, 상시 청취 없음. supportedLocales 에 ko 가 있는지 먼저. 권한을 언제 묻는지 정한 뒤 (플랜 jarvis 의 #voice-entry 와 같은 것 — 한 곳에서만 진행) {#dictation}

## 로컬 비서가 생기면 다시 열 수 있는 것 {#assistant-more}
- [ ] 폴더 제안 — 서랍에 넣을 때 「장보기?」 촩 하나. 자동 적용 없음. 보류된 {#opt-g} 의 전제(한국어 형태소 없음)가 바뀜 뒤 재개 {#folder-suggest}
- [ ] 사진 읽는 비서 — LiteRT-LM 이미지 입력 지원 spike 부터. 확인 전 약속 금지 {#photo-assistant}
- [ ] 주간 되돌아보기 — 「이번 주 뭐 했지」. 브리핑 검색 계층 재사용 {#weekly-review}

## 문서가 스스로 적어 둔 미결 {#open-issues}
- [ ] iCloud 쓰기 조정 — MemoVault.swift:109 의 oculpm-defer 를 NSFileCoordinator 로 선제 닫기 (스토어 제출 전) {#file-coordinator}
- [ ] 수천 장 그림 — 500/2000장 fixture 벤치를 verify-performance.sh 에. 24개 상한 질문에 숫자로 답한다 (DESIGN §13) {#scale-bench}
- [ ] 오늘의 낙서장 + 빠른 입력 @오늘/@어제 필터 — pro-lazy-ux 토의의 [ ] 두 개 {#scratchpad-filters}
- [x] 되풀이 낱말 「격주」「평일」 — 요일을 들지 않으므로 Recurrence 의 설계 원칙(주기만 말한다) 안 {#recurrence-words}
- [ ] 충돌 합치기 — 늦은 승·진 것 휴지통 대신 줄 단위 3-way 병합 (ConflictSettlement.swift) {#merge-conflict}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-16T15:20:12+09:00 | #ci-push | claude-code | ☐→~ |  | 시작 — 권장 순서 1번 |
| 2026-09-16T15:22:53+09:00 | #ci-push | claude-code | ~→x | .oculpm/journal/20260916/Features_to_add/1522_feature_ci-on-push-and-pr.md | ci.yml 작성, 로컬 829 테스트 그린. 첫 실제 실행은 push 뒤 확인 필요 |
| 2026-09-16T15:42:25+09:00 | #spotlight | claude-code | ☐→x | .oculpm/journal/20260916/Features_to_add/1541_feature_spotlight-index-mac-ios.md | LazyMemoSpotlight 모듈, 맥·폰 배선, 8 테스트. 실기기 손검증 남음 |
| 2026-09-16T15:42:33+09:00 | #dup-hint | claude-code | ☐→- | .oculpm/journal/20260916/Features_to_add/1541_feature_spotlight-index-mac-ios.md | 이미 있다 — 빠른 입력이 치는 동안 기존 메모를 걸러 보인다(구 검색→낱말 랭킹 폴백). 조사 때 놓침 |
| 2026-09-16T16:14:14+09:00 | #notarize | claude-code | ☐→~ | .oculpm/journal/20260916/Features_to_add/1613_feature_release-developer-id-notarize.md | 파이프라인 완성·로컬 서명 검증. 남은 것: 사용자가 시크릿 5개 넣고 태그 → 첫 공증 판 → cask 딱지 떼기·README 문단 삭제 |
| 2026-09-20T01:44:13+09:00 | #recurrence-words | claude-code | ☐→x | .oculpm/journal/20260920/Features_to_add/0143_feature_recurrence-words-biweekly-weekdays.md | 격주·평일 — 요일 없는 주기 둘, 주말에 적은 평일은 월요일부터. 시험 1077 초록 |
<!-- oculpm:plan-log end -->
