---
schema_version: 1
type: error
slug: "redesign-calendar-layout-check"
status: done
created_at: "2026-09-12T15:36:37+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Calendar/CalendarLayout.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
related:
  - ref: "20260912/Refactors/1535_refactor_cream-forest-visual-redesign.md"
    kind: "followup"
tags:
  - "mcp-tool"
---
[x] 전면 디자인 검증에서 달력 높이와 시각적 잘림 수정

## 발생 원인
달력 헤더를 64pt로 키우고 격자 몫을 줄이자 6주 달에서만 최소 주 높이가 적용되어 5주 달과 16.24pt 차이가 생겼다. 오늘 타일이 일정 점을 가리고, 팔레트 미리보기는 고정 프레임 밖 패딩 때문에 양끝이 잘렸다. 주요 버튼 글색 변경은 되돌리기에도 잘못 적용됐다.

## 해결 방법
최소 여섯 주 높이를 함께 예약해 월 전환의 흔들림을 없앴다. 오늘 타일 높이와 글자 위치를 줄여 아래 일정 점을 드러내고 팔레트 프레임 안으로 패딩을 옮겼다. 되돌리기는 강조 잉크, 주요 버튼만 크림 글색을 사용한다.

## 검증
전체 649개 테스트 통과. 최종 라이트·다크 달력과 팔레트 PNG에서 일정 점 세 개와 여섯 색 전체 표시 확인. release 앱 3.5MB 빌드 및 ad-hoc 서명 검증 통과.