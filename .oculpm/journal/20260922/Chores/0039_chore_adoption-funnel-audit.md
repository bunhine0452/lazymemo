---
schema_version: 1
type: chore
slug: "adoption-funnel-audit"
status: done
created_at: "2026-09-22T00:39:20+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/research/adoption-audit-2026-09-22.md"
    op: create
related: []
tags:
  - "research"
  - "adoption"
  - "distribution"
  - "mcp-tool"
---
[x] 사용자 유입·설치 조사

## 조사 결과
GitHub API에서 9/7~20 저장소 조회 24회·순방문 2명, 전체 ZIP 다운로드 14회, v0.9.0~0.9.3 다운로드 각각 0회를 확인했다. 원격 소개 원고의 숨겨진 스토어 버튼·Homebrew 우선·미공증 안내, 동명 검색 결과, 로컬 5단계 안내를 검토했다. 발견·설치 병목을 우선 가설로 정리하고 사용자 만족도·재사용은 미확인으로 구분했다.

## 검증
GitHub 읽기 전용 API·원격 원고·공개 검색·로컬 코드와 일지를 교차 확인했다. Pages 실응답과 ASC/TestFlight 지표는 미확보다. 사용자 실험은 수행하지 않아 recall-field 상태는 유지했다.