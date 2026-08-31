---
schema_version: 1
type: refactor
slug: pro-stationery-icon-and-ui-polish
status: done
created_at: 2026-08-29T19:57:00+09:00
session_id: "manual-20260829-195700"
agent:
  id: antigravity
  version: gemini-3.7-flash
language: ko
verified_by_user: false
files_touched:
  - path: scripts/make-icon.swift
    op: update
  - path: Resources/AppIcon.icns
    op: update
  - path: Sources/LazyMemoUI/Resources/MenuBarIcon.png
    op: update
  - path: Sources/LazyMemoUI/Resources/PaperGrain.png
    op: update
  - path: Sources/LazyMemoUI/Calendar/CalendarView.swift
    op: update
  - path: Sources/LazyMemoUI/Views/Theme.swift
    op: update
related:
  - .oculpm/planner/lazymemo-comfort-v2.md
  - .oculpm/discussion/lazymemo-pro-lazy-ux/discussion.md
tags: [icon, stationery, hig, ui-polish, calendar, theme]
---

[x] AI 느낌 없는 정통 Apple HIG 프로페셔널 문구류 아이콘 및 UI 콘트라스트 개편

## 동기
기존 앱 아이콘은 단조로운 보라색 배경과 평면적인 카드 형태로 인해 인공적이거나 아마추어적으로 보였다. 또한 캘린더 요일 헤더의 불투명도가 낮아 가독성이 떨어졌다. 이를 macOS HIG 규격의 묵직한 슬레이트 베이스플레이트, 300g 코튼 페이퍼 질감, 브라스 클립 디테일, 2중 물리 섀도우를 갖춘 프로페셔널 디자인으로 전면 쇄신한다.

## 변경 요약
1. `scripts/make-icon.swift`:
   - 배경: 보라색 그라데이션에서 묵직한 슬레이트 네이비 데스크 톤으로 변경 + Apple 정품 1px 마이크로 이너 베벨 림 라이트.
   - 종이 카드: 2차 물리 섀도우(Contact AO + Ambient Drop Shadow) + 섬세한 도트 그리드 + 사실적 접힌 모서리(Fold) 음영 + 상단 브라스 와이어 클립 추가.
   - 만년필 잉크 획: 딥 프러시안 잉크 첫 줄 + 테이퍼드 웜 앰버 둘째 줄.
2. `Sources/LazyMemoUI/Views/Theme.swift`:
   - `Theme.accent`를 슬레이트 네이비 계열(`Color(red: 0.18, green: 0.26, blue: 0.38)`)로 일치.
3. `Sources/LazyMemoUI/Calendar/CalendarView.swift`:
   - 요일 헤더 폰트 크기 및 투명도 조정(0.44/0.28 → 0.85/0.65)으로 다크/라이트 모드 시인성 대폭 향상.

## 검증
- `./scripts/make-icon.sh` 실행 및 `build/icon/comparison.png` 육안 검증 (16px~512px 전 해상도 선명도 및 완성도 확인).
- `./scripts/render-ui.sh` 실행 및 `build/ui/calendar.png`, `note.png` 렌더링 육안 확인.
- `./scripts/test.sh` 단위 테스트 334개 전체 통과.
