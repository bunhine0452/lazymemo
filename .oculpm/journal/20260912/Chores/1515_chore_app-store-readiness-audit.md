---
schema_version: 1
type: chore
slug: "app-store-readiness-audit"
status: done
created_at: "2026-09-12T15:15:27+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/APP_STORE_READINESS.md"
    op: create
related: []
tags:
  - "mcp-tool"
---
[x] 무료 Mac App Store 출시 준비 상태와 개선 우선순위 기록

## 변경 내용
실제 저장소와 Apple 공식 심사 지침을 대조하여 샌드박스·외부 폴더 북마크·외부 CLI·배포 서명·개인정보·메타데이터의 미완 항목을 정리했다. 현재 로컬 앱을 제출 가능한 빌드로 오인하지 않게 구분하고, 무료 핵심 기능의 제품 방향을 기록했다.

## 검증
build-app.sh, AppPaths, VaultMover, ClaudeRunner, Updater 구현을 확인했다. Apple App Review Guidelines 2.4.5 및 App Sandbox 공식 문서 링크를 포함했다.