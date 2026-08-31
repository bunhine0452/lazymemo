---
schema_version: 1
type: chore
slug: "shrink-build-output"
status: done
difficulty: low
created_at: "2026-08-31T12:13:06+09:00"
session_id: "20260831-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/build-app.sh"
    op: update
  - path: "scripts/clean.sh"
    op: create
  - path: "scripts/shrink-png.py"
    op: create
  - path: "scripts/make-icon.sh"
    op: update
  - path: "Resources/AppIcon.icns"
    op: update
  - path: "Sources/LazyMemoUI/Resources/PaperGrain.png"
    op: update
  - path: "Sources/LazyMemoUI/Resources/MenuBarIcon.png"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "build"
  - "bundle-size"
  - "assets"
  - "tooling"
  - "mcp-tool"
---
[x] 빌드가 남기는 부피 줄이기 — 번들 5.2MB→2.5MB, 작업 폴더 839MB→173MB

## 동기

프로젝트 폴더가 839MB 였다. 무엇이 무거운지 재보니 두 자리가 따로 있었다.

**배포되는 앱(5.2MB)** — `swift build -c release` 가 내놓은 `LazyMemo` 실행 파일이 3.84MB 인데 `size -m` 으로 열어 보니 `__TEXT` 는 1.44MB 뿐이었다. 나머지 2.3MB 는 심볼 테이블(34,828개)이었다. 디버거만 읽는 이름표가 번들의 절반을 차지하고 있었다. 아이콘 `AppIcon.icns` 도 614KB 로, `lazymemo-mcp`(950KB) 다음으로 큰 파일이었다.

**작업 폴더(839MB)** — `.build` 가 791MB 이고 그중 615MB 가 `ModuleCache`(debug 344MB + release 271MB) 였다. swift 가 프레임워크 모듈을 미리 씹어두는 캐시인데 상한이 없어 혼자 자란다. `index` 51MB 를 더하면 666MB 가 순수 파생 데이터였다.

## 한 일

**심볼 스트립** — `build-app.sh` 에 서명 직전 `strip -rSTx` 를 넣었다. 서명 뒤에 털면 서명이 깨지므로 순서가 중요하다. dSYM 은 `.build` 에 남으므로 크래시 로그 심볼화는 그대로 된다. LazyMemo 3,843,576→1,660,600 · lazymemo-mcp 950,400→552,432 바이트.

**그림 무손실 재압축** — `scripts/shrink-png.py` 를 새로 썼다. ImageIO 가 내보내는 PNG 는 압축을 얕게 건다. 픽셀은 손대지 않고 줄마다 다섯 필터를 다 재본 뒤 절대값 합이 가장 작은 것을 고르고(libpng 휴리스틱) zlib level 9 로 다시 조인다. 아이콘에 쓸모없는 `eXIf` 등 메타데이터 청크는 버리고 색 공간(sRGB)은 남긴다. icns 614,552→352,173(42.7%) · PaperGrain 25,297→16,690(34.0%) · MenuBarIcon 1,008→672(33.3%). `make-icon.sh` 마지막 단계로 붙여, 아이콘을 다시 그려도 압축된 상태가 유지된다.

**캐시 회수** — `scripts/clean.sh`. 기본값은 `ModuleCache` 와 `index` 만 지워 코드 산출물을 남긴다(다음 빌드가 증분). `--all` 이면 `.build`·`build`·`dist` 통째로.

**-Osize 는 선택으로 남겼다** — 별도 scratch-path 로 재보니 `-Xswiftc -Osize -Xlinker -dead_strip` 이 `__text` 를 1,141,468→928,528(18.7%), strip 후 실행 파일을 225KB 더 줄였다. 다만 속도를 내주는 거래이고 이 앱에는 빠른 입력 150ms 예산(설계문서 §11)이 있다. 기본으로 켜지 않고 `LAZYMEMO_OSIZE=1` 환경변수로 두었으며, 켤 경우 `measure-capture.sh` 로 예산을 다시 재라고 주석과 README 에 적었다.

## 검증

`shrink-png.py --verify` 로 압축 전후 PNG 를 각각 언필터링해 픽셀 바이트를 비교 — icns 11개 엔트리와 PNG 2장 모두 완전 동일. `sips` 로 macOS 가 읽는 것도 확인(1024×1024 icns). `build-app.sh release` 재실행 후 `codesign --verify --deep --strict` 통과, 번들 2.5MB. `scripts/test.sh` 338개 테스트 전부 통과. `clean.sh` 로 666MB 회수 뒤 `swift build -c release` 가 0.13s 로 증분 동작하는 것까지 확인.

## 메모

`private/` 4.4MB 는 예전 세션이 스크래치패드 경로(`/private/tmp/…`)를 상대경로로 잘못 써서 프로젝트 안에 생긴 UI 스크린샷 8장이다. git 미추적이고 지워도 되지만 이번 세션에서는 삭제 권한이 막혀 남겨 두었다.