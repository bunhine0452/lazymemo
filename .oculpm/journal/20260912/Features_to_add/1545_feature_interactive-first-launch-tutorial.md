---
schema_version: 1
type: feature
slug: "interactive-first-launch-tutorial"
status: done
created_at: "2026-09-12T15:45:29+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
  - path: "Sources/LazyMemoUI/WelcomeNote.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
related:
  - ref: "20260912/Features_to_add/1518_feature_paper-welcome-and-capture.md"
    kind: "followup"
tags:
  - "mcp-tool"
---
[x] 첫 실행 4단계 체험 튜토리얼 추가

## 추가 기능
기존 시작 화면을 빠른 입력·자연어 날짜·서랍 보관과 복원·시작 안내의 네 단계로 교체했다. 이전/다음, 건너뛰고 메모 적기, 완료 후 메모 또는 달력 열기를 제공한다. 연습 내용은 저장하지 않음을 명시한다.

## 동작 흐름
기존 greeted 및 메모 수 기반 첫 실행 판별을 유지한다. 메뉴에서 재실행할 수 있고 닫았다가 다시 열면 새 상태와 현재 단축키로 시작한다. 입력은 비어 있으면 연습 확정을 막고 날짜 연습에는 실제 NaturalDateParser를 사용한다. 서랍은 로컬 체험 상태만 전환한다. 첫 안내 메모의 휴지통 위치도 수정했다.

## 검증
전체 649개 테스트 통과. 네 단계 라이트·다크 렌더에서 배치 확인, 정적 렌더의 네이티브 입력 필드 제한은 기존 rendersStatically 환경으로 처리 후 재확인. git diff --check 통과. 실제 마우스/키보드 전체 흐름의 GUI 자동화 검증은 수행하지 않았다.