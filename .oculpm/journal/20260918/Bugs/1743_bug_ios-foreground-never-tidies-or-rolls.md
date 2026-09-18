---
schema_version: 1
type: bug
slug: "ios-foreground-never-tidies-or-rolls"
status: done
difficulty: verylow
created_at: "2026-09-18T17:43:25+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
related: []
tags:
  - "ios"
  - "tidy"
  - "recurrence"
  - "bug-hunt"
  - "mcp-tool"
---
[x] 폰이 앞으로 올 때 정리를 안 돌렸다 — 되풀이가 안 걸어가고 다 체크한 목록이 안 물러났다

## 발생 원인

`MemoStore.tidy()`(휴지통 30일·되풀이 걸어가기·끝난 것 물러나기·첨부 정리)는 폰에서 `store.start()` 한 번만 돌았다. 맥은 `DayClock` 이 자정마다 부르지만 폰에는 그 자리가 없고, `AppModel.foreground()` 는 `reconcile()` 만 했다. 폰은 며칠씩 켜진 채 잠들어 있으니 「매주 화요일 분리수거」가 지난 회차에 멈춰 있고, 다 체크한 목록이 사흘이 지나도 목록에 남았다 — 맥이 같이 켜져 있을 때만 iCloud 로 건너온 결과를 봤다.

## 해결 방법

`foreground()` 에서 `reconcile()` 다음에 `store.tidy()`. 전부 idempotent 라 켤 때의 `start()` 와 겹쳐 돌아도 해가 없다.

## 검증

- iOS 시뮬레이터 빌드 통과(`xcodebuild … -derivedDataPath .build/ios build`, 증분).
- `tidy()` 자체는 `TidySweepTests`·`AttachmentSweepTests` 가 덮는다. 폰 실기기 확인은 다음 배포 손검증에서.