---
schema_version: 1
type: chore
slug: "convenience-audit-research-note"
status: done
difficulty: medium
created_at: "2026-09-17T13:11:39+09:00"
session_id: "20260917-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/research/convenience-audit-2026-09-17.md"
    op: create
related: []
tags:
  - "research"
  - "ux"
  - "convenience"
  - "hig"
  - "mcp-tool"
---
[x] 편의성 감사 연구 노트 `docs/research/convenience-audit-2026-09-17.md`

## 무엇을

사용자 요청 「앱의 편의성을 높이기 위해 연구」. 코드는 건드리지 않고 연구 노트만 썼다. 앞선 두 감사(discussion lazy-comfort·pro-lazy-ux)와 어제 로드맵(planner lazymemo-upgrades-2026-09)에 없는 것만 적었다.

- 방법: 맥·폰 조작 경로를 코드로 따라 걸어 손 횟수를 셌다(`NoteView`·`MenuBarController`·`RecallViews`·`SystemReminderQueue`·`NowBand`·`StackView`·`CalendarView`·`DateSheet`·`WelcomeWindow`·`CapturePrompt`) · 시연 영상 프레임 육안 · HIG(Notifications·Settings·Menu bar·Live Activities) 데이터 엔드포인트와 WWDC25 260·230 트랜스크립트, 뉴스룸 · Quick Note·Drafts·Antinote·Things·Reminders.
- 결론 한 문장: 적는 길은 이미 최단(맥 2키·폰 2탭)이고, 걸리는 곳은 **떠오른 순간** — 배너에 동작이 없고(`categoryIdentifier` 없음), 맥의 나온 종이에 「왜·미루기」가 없고, 「다시 보기」 칩이 저장까지 두 번이며(폰 `DateSheet` 는 즉시 적용 — 불일치), 폰 「지금」·목록에 달력 탭의 「미루기」가 없다.
- 그다음: 설정 하위 메뉴 15줄(코드 머리말 「몇 개뿐」이 낡음) → 설정 창 · 첫 실행 04 에 「로그인할 때 시작」 · 메뉴바 아이콘 드롭 · 안내 문구 시키기 예.
- 애플 26: Spotlight 액션(배경 인텐트 + OpensIntent; GitHub 판 메타데이터 여부 확인 필요) · AlarmKit 출발 카운트다운(권한 1개, 쓸 때만) · 아이폰 Live Activity 가 맥 메뉴바에(맥 코드 없이) · 대화형 위젯.
- 우선순위 표(§5)와 부딪힘 판정(§6), 못 찾은 것(§7)을 노트에 남겼다. 플랜 항목은 만들지 않았다 — 사용자가 고르면 upgrades 플랜에 얹는다.

## 검증

- 노트의 코드 인용(파일·줄)은 전부 이 세션에서 grep/sed 로 읽은 자리. 원문 인용은 2026-09-17 에 읽은 페이지에서 그대로.
- 앱을 띄우지 않았고 실기기 손검증 없음 — 사람 눈이 필요한 항목(§2.7)은 그렇게 적었다.

## 메모

- 시연 영상 프레임(`scratchpad/frames`)은 세션 스크래치패드에만 두었다 — 저장소에 넣지 않았다.