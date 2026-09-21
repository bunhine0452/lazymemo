---
oculpm_plan: v1
id: lazymemo-polish-2026-09-18
title: "다듬기 2026-09-18 — 웹 답을 잘 정리한 메모로, 큰 메모에 맞는 종이, 부드러운 모션, 위젯 재설계, 테마"
status: done
created: 2026-09-18
updated: 2026-09-21
owner: claude-code
---

사용자 요청 여섯 — ① 비서가 어떤 질문에도 정확히 답하고 웹 검색을 잘 정리한 메모로 남긴다 ② 큰 메모·붙인 글에 종이 크기가 유연하게 맞는다 ③④ 조작이 불편하지 않고 모션이 부드럽고 최적화되어 있다 ⑤ 위젯 디자인을 정교하게 재설계한다 ⑥ 테마를 여럿 두고 사용자가 커스터마이징한다. 병렬 세션이 영역별로 나눠 맡는다.

## 비서 — 정확한 답과 잘 정리된 메모 {#assistant}
- [x] 웹 검색 결과의 페이지 본문을 읽어 근거로 삼는다(발췌만이 아니라) — 키 없음, 용량·시간 상한, 실패 시 발췌로 {#web-page-evidence}
- [x] 어떤 질문에도 정확히 — 검색어 정제·재검색·여러 근거 종합·출처 인용, 모델이 넘어지면 결과 그대로 {#web-answer-accuracy}
- [x] 「정리해서 남기기」가 구조 있는 마크다운 메모를 낸다 — 제목·핵심·세부·출처, 어떤 데이터든 보기 편하게 {#web-digest-memo}

## 종이 크기 — 큰 메모·붙인 글에 맞춘다 {#paper-size}
- [x] 맥 종이가 붙인 글·긴 메모에 맞춰 화면 한도 안에서 자란다 — 사람이 정한 크기는 존중, layout.json 정본 유지 {#mac-paper-fit-content}
- [x] 긴 메모의 편집·읽기가 매끄럽다 — 큰 글에서 스타일링·스크롤 성능, 폰 목록 줄의 미리보기 {#long-memo-readability}

## 조작과 모션 — 불편하지 않고 부드럽다 {#motion-ux}
- [x] 맥 모션 감사와 정리 — 서랍·빠른 입력·달력·종이의 곡선·시간 통일, reduceMotion 존중, 렌더 최적화 {#motion-audit-mac}
- [x] 폰 모션 감사와 정리 — 목록·달력·펜·「지금」 띠의 전환, 스프링 통일, 프레임 낭비 제거 {#motion-audit-ios}
- [x] 조작 경로 손검증에서 나온 걸림 수정 — 손 횟수 줄이기, 상태 피드백 {#ux-walkthrough-fixes}

## 위젯 재설계 {#widgets}
- [x] 위젯 설계 문서 — HIG 원문 근거, 가족별 정보 위계·글자·여백 결정 {#widget-redesign-doc}
- [x] 「지금」·「다음 약속」·「달력」·「적기」 얼굴 재구현 — 홈·잠금·맥 알림 센터, 빈 상태·다크·대비 높임 {#widget-redesign-impl}

## 테마 — 여럿, 그리고 커스터마이징 {#themes}
- [x] 테마 카탈로그(Core) — 종이·잉크·강조·하이라이트 묶음 여럿, 라이트·다크·대비 높임 각각, settings.json 에 저장 {#theme-catalog}
- [x] 맥 — Theme/Paper 가 카탈로그를 읽고 즉시 바뀐다, 설정 창에 고르기·커스터마이징(강조색·종이색·글자 크기) {#theme-mac}
- [x] 폰 — 같은 카탈로그, 설정 자리에 고르기·커스터마이징 {#theme-ios}
- [x] 위젯 — 고른 테마를 settings.json 에서 읽어 같은 색으로 {#theme-widgets}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-18T19:09:55+09:00 | #web-page-evidence | claude-code | ☐→x | .oculpm/journal/20260918/Features_to_add/1909_feature_web-page-evidence-and-digest-memo.md | PageReader — 앞 3쪽·8초·1MB·쿠키없음, article/main·링크열 걷기, EUC-KR, 실패 시 발췌 |
| 2026-09-18T19:10:02+09:00 | #web-answer-accuracy | claude-code | ☐→x | .oculpm/journal/20260918/Features_to_add/1909_feature_web-page-evidence-and-digest-memo.md | 검색어 정제·빈손이면 재검색·종합 프롬프트·예산 512·claude CLI 어댑터(꽂는 한 줄은 AppDelegate 쪽) |
| 2026-09-18T19:10:08+09:00 | #web-digest-memo | claude-code | ☐→x | .oculpm/journal/20260918/Features_to_add/1909_feature_web-page-evidence-and-digest-memo.md | Digest — 제목·핵심·세부(표/번호/할일)·출처·꼬리, 틀은 앱·가운데만 모델, 모델 없어도 같은 자리 |
| 2026-09-18T19:12:47+09:00 | #widget-redesign-doc | claude-code | ☐→x | .oculpm/journal/20260918/Chores/1911_chore_widget-design-doc.md | docs/WIDGET_DESIGN.md 171줄 — HIG 원문 인용, 가족별 위계·여백·과녁 |
| 2026-09-18T19:12:54+09:00 | #widget-redesign-impl | claude-code | ☐→x | .oculpm/journal/20260918/Features_to_add/1912_feature_widget-redesign-precise-comfortable.md | 네 얼굴 재구현 — 색 획·고정 칸·흐르는 남은 시간·펜 자국 오늘·홈의 「봤어요」. 두 플랫폼 빌드 OK, 시험 20 통과 |
| 2026-09-18T19:21:23+09:00 | #mac-paper-fit-content | claude-code | ☐→x | journal/20260918/Features_to_add/1920_feature_mac-paper-fits-content.md | PaperFit — 윗변 고정, 화면 70% 천장, 긴 줄에만 560 폭, 사람이 정한 크기 존중 |
| 2026-09-18T19:21:28+09:00 | #long-memo-readability | claude-code | ☐→x | journal/20260918/Features_to_add/1921_feature_long-memo-readability.md | 꾸밈을 고친 줄만 — 297ms→1ms, 커서·⌫·그리기도 좁힘, 폰 목록 긴 글 넉 줄 |
| 2026-09-18T19:32:34+09:00 | #theme-catalog | claude-code | ☐→x | journal/20260918/Features_to_add/1932_feature_theme-catalog-and-customization.md | Core 카탈로그 8벌 + overrides + App Group 거울, 대비 시험 |
| 2026-09-18T19:32:40+09:00 | #theme-mac | claude-code | ☐→x | journal/20260918/Features_to_add/1932_feature_theme-catalog-and-customization.md | ThemeStore + 설정 창 「테마」 절, 즉시 바뀜(손검증). AppDelegate attach 한 줄 남음 |
| 2026-09-18T19:32:46+09:00 | #theme-ios | claude-code | ☐→x | journal/20260918/Features_to_add/1932_feature_theme-catalog-and-customization.md | ThemeModel + ThemeSettingsView 시트, 빌드 통과. StackView 메뉴 한 줄은 오케스트레이터 |
| 2026-09-18T19:44:58+09:00 | #theme-widgets | claude-code | ☐→x | 20260918/Features_to_add/1944_feature_widget-theme-follow-choice.md | WidgetTheme.paper 가 ThemeChoice 읽음; 타임라인 리로드 연결은 미완(범위 밖) |
| 2026-09-18T19:52:07+09:00 | #motion-audit-mac | claude-code | ☐→x | journal/20260918/Refactors/1950_refactor_one-motion-vocabulary.md | Motion 낱말 셋 + 달력 격자 Equatable(84번 서식 제거) + 서랍 호버 줄 안으로 |
| 2026-09-18T19:52:14+09:00 | #motion-audit-ios | claude-code | ☐→x | journal/20260918/Bugs/1951_bug_frame-cost-and-hit-targets.md | 폰도 같은 Motion 낱말 · 목록/달력의 매 body 훑기 제거 · 스모크 6건은 남의 themedUIColor 크래시 |
| 2026-09-18T19:52:20+09:00 | #ux-walkthrough-fixes | claude-code | ☐→x | journal/20260918/Bugs/1951_bug_frame-cost-and-hit-targets.md | 과녁 44(봤어요·시각 칩·가는 길) · 날 고르기/달 넘김 햅틱 · 합성 마우스로 서랍 경로 재검증 |
| 2026-09-22T01:20:25+09:00 | #motion-audit-ios | claude-code | x→x |  | 후속 — 달 넘김 판 body 8→1, 속도 잇는 스프링, 회귀 시험 추가 |
<!-- oculpm:plan-log end -->
