---
schema_version: 1
type: feature
slug: "app-store-update-routing"
status: done
created_at: "2026-09-12T15:14:08+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Update/InstallSource.swift"
    op: update
  - path: "Sources/LazyMemoUI/Update/Updater.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/UpdateCheckTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/UpdaterTests.swift"
    op: update
related: []
tags:
  - "mcp-tool"
---
[x] App Store 배포본의 외부 업데이트를 차단

## 추가 기능
App Store 영수증 또는 LazyMemoAppStoreBuild 빌드 표식을 통해 배포 경로를 구분한다. 스토어 배포본은 GitHub 확인·설치를 실행하지 않고 관련 메뉴도 숨긴다.

## 동작 흐름
설치 경로 판별 → allowsExternalUpdates 정책 → 자동·수동 업데이트 확인 차단. 첫 영수증 발급 전은 Info.plist 빌드 표식으로 보호한다. 샌드박스 및 서명 구성 자체는 별도 출시 작업으로 남는다.

## 검증
전체 648개 테스트 통과. 영수증 우선순위, 영수증 이전 빌드 표식, 수동 요청에도 네트워크 미호출 회귀 테스트 포함.