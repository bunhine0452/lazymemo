---
oculpm_plan: v1
id: lazymemo-recall
title: "필요할 때 다시 펼쳐주는 lazymemo"
status: active
created: 2026-09-14
updated: 2026-09-14
owner: codex
---

제품 설계와 검증 기준은 docs/RECALL_PLAN.md. 사용자가 승인한 알림 원칙을 반영하며 첫 출시 구현과 출시 후 제품 검증을 구분한다.

## 약속과 설계 {#foundation}
- [x] 제품 계획서 — 대표 경험·알림 정책·출시 기준·후속 실험 {#recall-design}

## 다시 보기 첫 출시 구현 {#build}
- [x] 맥·폰 선택적 로컬 알림과 변경·삭제 예약 대조, 알림에서 메모 열기 {#recall-notifications}
- [x] 메모별 다시 볼 시각 지정·해제와 기기 알림 설정 {#recall-controls}
- [x] 이유가 보이는 지금 세 장과 저장 실패 표시 {#recall-now}
- [x] 단위 테스트·양 플랫폼 빌드·모바일 화면 검증과 사용 문서 {#recall-validation}

## 실기기와 사용자 검증 {#release}
- [ ] 폰 잠금·앱 종료 알림, 거절·재허용, 맥 왕복 동기화 실기기 검증 {#recall-device}
- [ ] 사용자 10명 일주일 검증 — 도움 된 회상·방해·재사용 기록 {#recall-field}
- [~] 검증 뒤 위젯·잠금 화면 입력과 전환 연출 확장 {#recall-capture}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-14T22:09:24+09:00 | #recall-design | codex | ☐→x |  | docs/RECALL_PLAN.md에 제품 결정과 검증 기준 작성 |
| 2026-09-15T01:08:16+09:00 | #recall-notifications | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/0108_feature_recall-notifications-first-release.md | ReminderCenter 대조 엔진 + 가짜 큐 시험 12개 · 실기기 확인은 #recall-device |
| 2026-09-15T01:08:22+09:00 | #recall-controls | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/0108_feature_recall-notifications-first-release.md | 맥 우클릭 「다시 보기…」·설정 「알림…」, 폰 종 단추·More 「알림」 시트 |
| 2026-09-15T01:08:28+09:00 | #recall-now | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/0108_feature_recall-notifications-first-release.md | NowBand 세 장 + NoticeRow 저장·알림 오류, XCUITest·스크린샷 확인 |
| 2026-09-15T01:08:35+09:00 | #recall-validation | claude-code | ☐→~ | .oculpm/journal/20260915/Features_to_add/0108_feature_recall-notifications-first-release.md | swift test 765 · iOS 빌드+UI 시험 2 · l10n 0 빠짐 · 문서 — 맥 번들 실행과 LazyMemo-macOS Xcode 빌드는 미확인(사용자 중단) |
| 2026-09-15T02:17:44+09:00 | #recall-validation | claude-code | ~→x | .oculpm/journal/20260915/Chores/0217_chore_testflight-upload-recall-photos.md | 맥 App Store 타깃 아카이브로 양 플랫폼 빌드 확인 · 폰 스모크 15 · 두 판 TestFlight 업로드 |
| 2026-09-16T23:19:45+09:00 | #recall-capture | claude-code | ☐→~ | .oculpm/journal/20260916/Features_to_add/2319_feature_widgetkit-now-next-write.md | 위젯(지금·다음 약속·적기)·잠금 화면 입력 위젯 구현, 워크트리 브랜치 — 전환 연출·실기기 검증 남음 |
| 2026-09-21T19:01:58+09:00 | #recall-capture | claude-code | ~→~ | .oculpm/journal/20260921/Features_to_add/1901_feature_widget-checkbox-writes-file.md | 위젯 입력 첫 걸음 — 큰 「지금」의 체크상자가 파일에 적는다(시뮬레이터 실기 확인) |
<!-- oculpm:plan-log end -->
