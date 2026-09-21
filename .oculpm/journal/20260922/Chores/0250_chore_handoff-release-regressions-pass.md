---
schema_version: 1
type: chore
slug: "handoff-release-regressions-pass"
status: done
difficulty: medium
created_at: "2026-09-22T02:50:24+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "README.md"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "site/index.html"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
  - path: "docs/research/usage-observation-2026-09-22.md"
    op: create
related:
  - ref: "20260922/Features_to_add/0247_feature_memo-state-done-archived-missed.md"
    kind: "followup"
  - ref: "20260922/Features_to_add/0136_feature_conflict-copies-people-can-recover.md"
    kind: "followup"
tags:
  - "release"
  - "regression"
  - "handoff-bundle-6"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 인계서 묶음 1~5 통합 회귀 — 최신 소스로 맥 1,142·폰 스모크 27·확장/위젯 빌드·검증 스크립트·문구 정합성 (묶음 6 앞부분)

인계서 §5 묶음 6 `#release-regressions` 의 이 세션 몫. 다섯 묶음(둘은 병렬 세션)을 한 워킹트리에서 합친 뒤 **모든 시험을 새로 빌드해 돌렸다** — `--skip-build` 는 낡은 바이너리를 돌린다는 것을 묶음 1 에서 한 번 봤다.

## 한 것

- **Core·입력·알림·파일 이행 회귀** — `./scripts/test.sh` 전체 **1,142개 통과** (Core 563/81 스위트·UI 87·Reminders 23·Places 23·WidgetsCore 25·Assistant 411·LiteRT 8·Spotlight 2). 알려진 결함 셋(R01~R03)은 현재 소스에서 **실패 → 수정 → 통과**의 기록이 묶음 1 일지에 있다. 새 시험: 안전 정리 13·초안 실패 1·영수증 5·상자 저장 실패 2·30문장 회귀와 결과 카드 8·상태 계약 12·충돌 복구 11·맥 메뉴 상태 3.
- **폰** — 시뮬레이터(iPhone 17) 스모크 **27개 전부 통과** (앱·공유 확장·위젯 확장 빌드 포함). 새 계약으로 고쳐 쓴 셋(가는 길 권함·공유 시트 권함·첫 실행)과 새 하나(놓친 것·완료·보관).
- **맥 실제 앱** — `verify-tidy.sh`(6장 중 4장 남고 2장 치움)·`verify-state.sh`(놓친 것 요약·보관·완료)·`verify-capture-paste/delete/dismiss.sh` 통과. `render-ui.sh` 로 `capture-trouble`·`capture-left`·`capture-ask` 밝은/어두운 판 확인. 검증 주행(`LAZYMEMO_*`)에서는 첫 메모 한 줄이 서지 않게 했다 — 스크립트가 개발 기계의 표를 먹지 않도록.
- **문구 정합성** — README(⌘⏎ 는 늘 적음·⌥⌘⏎ 비서·처음 켜면·끝난 것/완료/보관·「지금」과 놓친 것·가는 길 권함·영수증), 폰 안내 다섯 장, 맥 시작하기 01, 소개 페이지 ko/en(비서는 ✦·가는 길은 권함·물러남 규칙). `check-l10n.sh` — 내 모듈 빠짐 0 (렌더 표본 문장은 원래 빠져 있던 것).
- 사용 관찰 과제·기록 양식 `docs/research/usage-observation-2026-09-22.md` (외부에 보내지 않음).

## 안 한 것 (§8 의 남은 줄)

- 큰 글자·VoiceOver·Reduce Motion 의 실제 흐름, 폰 어두운 테마 화면 — 이번 세션엔 안 봤다.
- 실기기: 잠금·앱 종료·알림 열기·양 기기 오프라인 변경·재연결·완료 반영 — `lazymemo-recall#recall-device`. 시뮬레이터 성공을 대체 증거로 쓰지 않는다.
- 스토어 원고(`store-shots`·심사 텍스트)는 손대지 않았다 — `lazymemo-app-store`.
- 커밋하지 않았다 — 워킹트리에 다른 세션의 미커밋 변경(폰 달력·움직임·SmokeTests 46줄·MOBILE_DESIGN·토의 문서)이 함께 있어 사용자가 갈라 커밋하도록 두었다.

## 검증

위 숫자 그대로. 마지막 전체 시험은 맥 절반(병렬 세션)까지 합친 뒤에 돌렸고, 폰 스모크는 묶음 4 폰 변경 뒤에 다시 돌렸다.