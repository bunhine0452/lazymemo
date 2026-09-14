---
schema_version: 1
type: chore
slug: "recall-product-plan"
status: done
created_at: "2026-09-14T22:09:24+09:00"
session_id: "20260914-005"
agent:
  id: "codex"
  version: "gpt-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/RECALL_PLAN.md"
    op: create
  - path: ".oculpm/planner/lazymemo-recall.md"
    op: create
related:
  - ref: "20260831/Features_to_add/1701_feature_surface-at-agent-surface.md"
    kind: "followup"
tags:
  - "mcp-tool"
---
[x] 다시 펼쳐주는 메모 제품 계획과 알림 원칙 확정

사용자 요청에 따라 대표 경험, 기기별 선택적 알림, 메모별 다시 보기, 지금 세 장, 출시 및 사용자 검증 기준을 정했다. 기존 무알림 원칙은 첫 실행에 묻지 않고 사용자가 켤 때 요청하는 것으로 변경한다. 위젯과 사용자 검증은 후속 단계로 명시했다.

## 검증
기존 Memo.surface와 DueClock, iOS 입력/목록 구조 및 Apple 로컬 알림 문서를 확인했다. 운영 한계와 실기기 검증을 구현 완료와 구분했다.