---
oculpm_plan: v1
id: lazymemo-product-value
title: "제품 재설계 — 안전한 기록과 미처리 회수"
status: active
created: 2026-09-22
updated: 2026-09-22
owner: codex
---

2026-09-22 사용자가 조사·의견대로 구현하기로 승인. docs/PRODUCT_IMPLEMENTATION_HANDOFF.md가 실행 명세. 기존 recall 실기기·사용자 검증과 upgrades 파일 조정/OCR은 해당 플랜에서 계속 추적하며 중복 완료 처리하지 않는다.

## 채택과 인계 {#handoff}
- [x] 채택 결정·파일별 구현 순서·회귀 사례·기존 플랜 연결을 인계서로 확정 {#implementation-handoff}

## P0 신뢰를 먼저 복구 {#trust}
- [x] 미래 다시 보기·미완료 체크리스트·명시적 복원과 자동 정리의 충돌 재현 및 수정 {#tidy-recall-safety}
- [x] 초안 보존 실패 표시·재시도와 저장/초안 의미 구분 {#draft-save-status}
- [x] 입력 경로별 로컬 알림 예약 상태 표시와 공유 경로 보완; 실기기 완료는 recall-device {#reservation-receipt}

## P1 예측 가능한 입력 {#capture}
- [x] 기본 확정은 메모 저장, 질문·명령은 명시적 비서 동작; 원문 보존·모델 없는 경로 검증 {#capture-always-saves}
- [x] 저장 뒤 길찾기·시각 질문은 선택 행동으로 분리하고 연속 입력 보장 {#nonblocking-followups}
- [x] 첫 실행부터 실제 자기 메모 저장·재발견; 기존 튜토리얼은 도움말로 {#first-real-note}

## P1 처리 완료까지 한 흐름 {#followthrough}
- [x] 완료·보관·오늘 숨김·반복 회차 상태와 구버전 파일 호환을 구현 전 확정 {#memo-state-contract}
- [x] 놓친 미처리와 지금 세 장·전체 요약·일정/다시 보기 분리 행동 구현 {#unfinished-recall}
- [x] 충돌본을 삭제물과 구분해 발견·비교·복구; 파일 조정은 upgrades/file-coordinator와 연결 {#conflict-recovery}

## 검증과 다음 범위 {#validation}
- [~] 최신 소스 양 플랫폼·위젯·알림·이행 회귀와 문구 정합성 확인; 기기/현장 검증은 기존 recall 플랜 참조 {#release-regressions}
- [!] 핵심 사용 검증 후 OCR 원본 카드와 AI 근거 찾기 확장 판단; 기존 OCR·모델 플랜에서 실행 {#evidence-next-scope}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-22T01:01:50+09:00 | #implementation-handoff | codex | ☐→x | .oculpm/journal/20260922/Chores/0101_chore_product-implementation-handoff.md | 사용자 방향 승인; 구현 인계서·동작 계약·회귀·기존 플랜 연결 완료. 제품 구현 11항목은 미완. |
| 2026-09-22T01:23:53+09:00 | #tidy-recall-safety | claude-code | ☐→x | .oculpm/journal/20260922/Bugs/0123_bug_tidy-overrode-user-intent.md | R01~R03 현재 소스 재현→수정→1,106 시험 통과·verify-tidy 앱 메뉴 확인; R04~R06 상태 모델 몫은 memo-state-contract 로 |
| 2026-09-22T01:36:27+09:00 | #conflict-recovery | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0136_feature_conflict-copies-people-can-recover.md | conflict: 표시·이 판으로/둘 다 남기기 양 플랫폼·11 시험·1,121 통과·맥 메뉴 실확인; 폰 뷰는 문법만, 실기기 iCloud 왕복은 recall-device |
| 2026-09-22T01:42:08+09:00 | #draft-save-status | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0141_feature_draft-trouble-and-reservation-receipt.md | 초안 실패 표시·재시도, 맥 상자는 적힌 뒤 비움; 시험 1,125 통과·렌더 확인 |
| 2026-09-22T01:42:15+09:00 | #reservation-receipt | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0141_feature_draft-trouble-and-reservation-receipt.md | ReservationReceipt·펜/달력/공유/인텐트 영수증, 확장이 같은 id 로 예약; 실기기·시뮬 조작은 미확인(recall-device) |
| 2026-09-22T02:30:29+09:00 | #capture-always-saves | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0230_feature_capture-always-saves-followups-optional.md | ⌘⏎/남기기 늘 적음, 비서는 ⌥⌘⏎·✦; 30문장 회귀·모델 없는 경로 시험 통과 |
| 2026-09-22T02:30:34+09:00 | #nonblocking-followups | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0230_feature_capture-always-saves-followups-optional.md | 결과 카드의 「시각 정하기」「가는 길」, 다음 글은 새 메모; 폰 스모크 26 통과 |
| 2026-09-22T02:30:41+09:00 | #first-real-note | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0230_feature_capture-always-saves-followups-optional.md | 첫 실행은 상자/펜부터, 첫 메모 뒤 한 줄; 안내는 메뉴·더 보기로. 맥 첫 실행 장면은 실제로 안 돌림 |
| 2026-09-22T02:47:43+09:00 | #memo-state-contract | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0247_feature_memo-state-done-archived-missed.md | done:/archived:/kept: 계약을 MemoStateTests 표로 고정, 구형 파일 왕복·회차 리셋(R06)·tidied 미이행 |
| 2026-09-22T02:47:49+09:00 | #unfinished-recall | claude-code | ☐→x | .oculpm/journal/20260922/Features_to_add/0247_feature_memo-state-done-archived-missed.md | 폰 놓친 것·완료·보관(스모크 27) + 맥 메뉴·달력·종이(verify-state, 1,142 시험); 양 기기 동기화 반영 장면은 recall-device |
| 2026-09-22T02:50:32+09:00 | #release-regressions | claude-code | ☐→~ | .oculpm/journal/20260922/Chores/0250_chore_handoff-release-regressions-pass.md | 맥 1,142·폰 스모크 27·확장/위젯 빌드·검증 스크립트·문구 맞춤 완료; 남은 것: 큰 글자·VoiceOver·Reduce Motion·폰 다크·실기기(recall-device) |
| 2026-09-22T02:50:38+09:00 | #evidence-next-scope | claude-code | ☐→! | .oculpm/journal/20260922/Chores/0250_chore_handoff-release-regressions-pass.md | 관찰 과제·기록 양식만 준비(docs/research/usage-observation-2026-09-22.md); 신규 5명 관찰 결과 없이는 OCR/AI 확장 판단 불가 |
<!-- oculpm:plan-log end -->
