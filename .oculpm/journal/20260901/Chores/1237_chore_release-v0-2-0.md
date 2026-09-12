---
schema_version: 1
type: chore
slug: "release-v0-2-0"
status: done
difficulty: medium
created_at: "2026-09-01T12:37:32+09:00"
session_id: "20260901-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
related: []
tags:
  - "release"
  - "ci"
  - "homebrew"
  - "mcp-tool"
---
[x] v0.2.0 배포 — 쌓여 있던 미커밋 몸통을 한 판으로 내보낸다

## 동기

`main` 의 HEAD 가 이미 나간 v0.1.0 그대로였고, v0.1.0 이후의 작업 전부(장소·문 넷·서랍·앱 내 판 갈이·EventKit·반복·게으른 찾기·종이 위의 Claude·두꺼운 종이)가 **워킹트리에만** 있었다. 추적 안 되는 새 파일이 40개가 넘었다.

## 갈라 커밋할 수 없었던 이유

`MenuBarController` 하나가 `InboundDoor`·`DrawerWindowController`·`Updater`·`EventKitFeed` 를 함께 부른다. 어느 하나만 떼어 커밋하면 그 커밋에서 빌드가 깨진다. 여러 세션에 걸친 작업이 파일 사이에 섞여 있어 원래의 커밋 경계를 복원할 수도 없었으므로, **몸통 하나 + 판 올리기 하나**로 두 커밋을 냈다. 작업 단위별 까닭은 일지에 이미 있으므로 커밋 본문에서 그쪽을 가리킨다.

## 변경 요약

- `Info.plist` `CFBundleShortVersionString` 0.1.0 → 0.2.0 (`CFBundleVersion` 1 → 2)
- `Version.swift` 0.1.0 → 0.2.0 — 태그·plist·Swift 셋이 같은 판이어야 워크플로가 시작된다 (§12.3)
- `e030f1d` 몸통, `d1593ba` 판 올리기, 태그 `v0.2.0`

## 검증

배포 전: 시험 604개 통과, `build-app.sh` 로 번들 조립·심볼 스트립·ad-hoc 서명 검증(3.4M), 시크릿 스캔 무소득, `dist/`·`build/`·`private/` 는 모두 무시 목록에 있음을 확인.

배포 후: 릴리스 워크플로 초록(2m39s, 「탭을 못 갱신했다」 단계는 건너뜀 = 탭 갱신 성공). **나간 바이트를 직접 받아 확인했다** — 자산 sha256 `aa841721…` 이 탭 cask 의 값과 일치(문서가 경고하는 「초록인데 설치가 안 되는」 상태가 아니다), `ditto` 로 푼 뒤 `codesign --verify --deep --strict` 통과, 번들과 `lazymemo-mcp --version` 이 모두 0.2.0. Pages 사이트도 같은 푸시로 재배포 성공.