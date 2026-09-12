---
schema_version: 1
type: error
slug: "tutorial-string-build-fix"
status: done
created_at: "2026-09-12T15:44:08+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: update
related: []
tags:
  - "mcp-tool"
---
[x] 튜토리얼 설명 문자열 빌드 오류 수정

## 발생 원인
Swift 한 줄 문자열 내부에 실제 줄바꿈이 들어가 문자열 종료 오류가 발생했다.

## 해결 방법
서랍 설명의 줄바꿈을 Swift 이스케이프로 수정했다.

## 검증
재빌드 성공 및 전체 649개 테스트 통과.