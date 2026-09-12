---
schema_version: 1
type: chore
slug: "release-v0-4-0"
status: done
difficulty: low
created_at: "2026-09-13T01:42:02+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
related:
  - ref: "20260913/Features_to_add/0039_feature_drawer-folders-list-redesign.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0137_feature_demo-tour-recording.md"
    kind: "followup"
  - ref: "20260912/Chores/1557_chore_release-v0-3-0.md"
    kind: "followup"
tags:
  - "release"
  - "site"
  - "version"
  - "mcp-tool"
---
[x] v0.4.0 배포 — 폴더·초안·첫소리·소개 영상을 한 판으로 내보내고 소개 페이지를 다시 그린다

## 동기

사용자가 「배포 고고 + 랜딩페이지 디자인 업그레이드 + 깃허브에 동작 동영상」을 요청. 0.3.0 이후 이 세션의 작업(서랍 폴더 전면 개편, 빠른 입력 초안 보존·첫소리 찾기, 좌표 정리 유예, 데모 주행) 을 한 판으로 묶었다.

## 변경 요약

- 판 0.3.0 → 0.4.0 (`Info.plist` CFBundleVersion 4, `Version.swift`). 리드미 머리에 `site/media/demo.gif` 와 「이번 판 — 0.4.0」 여섯 항목.
- 커밋 셋: `feat:` (앱 코드 전부 + 일지), `site:` (소개 페이지·영상·스크린샷), `chore:` (판·리드미). 태그 `v0.4.0` 푸시.
- 로컬에서 `package-release.sh` 로 번들이 서명·묶이는지 먼저 확인(1.7MB zip)한 뒤 태그를 밀었다.

## 검증

- pages 워크플로 성공(외부 요청 검사 포함). release 워크플로 결과는 아래 「메모」.
- 시험 676개 통과, `verify-drawer.sh`·`verify-mcp.sh` 통과.

## 메모

- 저장소 워킹트리에 남은 미추적 파일(`.oculpm/agents/_template.md.bak`, 20260912 릴리스 일지)은 다른 세션의 것이라 손대지 않았다.