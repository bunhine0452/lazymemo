---
schema_version: 1
type: bug
slug: "layout-prune-grace"
status: done
difficulty: medium
created_at: "2026-09-13T01:38:13+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/LayoutStore.swift"
    op: update
  - path: "Tests/LazyMemoUITests/LayoutPruneTests.swift"
    op: create
related:
  - ref: "20260913/Features_to_add/0039_feature_drawer-folders-list-redesign.md"
    kind: "followup"
tags:
  - "layout"
  - "race"
  - "vault-watcher"
  - "drawer"
  - "mcp-tool"
---
[x] 한꺼번에 들어온 메모의 좌표가 지워져 서랍의 종이가 바탕화면에 선다

## 발생 원인

소개 영상 주행이 메모 아홉 장을 연달아 만들고 좌표(`hidden: true`)를 심었는데, 매번 다른 한 장이 바탕화면에 섰다. `layout.json` 을 뜯어 보니 그 메모만 `hidden=false`. 경로: 파일 감시(`VaultWatcher`)가 쓰는 도중 발화 → `MemoStore.reconcile` 이 아직 다 쓰이지 않은 파일을 못 읽어 목록에서 한 박자 뺌 → `NoteWindowManager.sync` 의 `layouts.prune(keeping: memos ∪ trash)` 가 그 메모의 좌표를 지움 → 다음 reconcile 에 메모가 돌아오면 좌표가 없어 `staysOnDesktop` 이 «날짜 없음 → 종이» 로 읽고 `open(recording: true)` 가 `hidden=false` 를 새로 적음. 아이폰 단축어·MCP 로 여러 장이 한꺼번에 떨어질 때 실제 앱에서도 같은 일이 난다.

## 해결 방법

좌표 정리에 **유예**를 뒀다. `NoteWindowManager.staleLayouts(known:alive:absentSince:now:)` 순수 함수가 「언제부터 안 보였는가」를 들고 있다가 10초(`pruneGrace`)를 넘긴 것만 지운다. 도로 보이면 잊는다. `LayoutStore.memoIDs` 를 추가해 아는 좌표를 셀 수 있게 했다.

## 검증

- `LayoutPruneTests` 4개: 첫 결석은 봐줌·유예 넘기면 지움·돌아오면 초기화·살아 있는 것은 절대 안 지움.
- 데모 주행을 다시 세 번 돌려 표본 메모가 전부 제자리(바탕화면 둘, 서랍 일곱)인 것을 프레임으로 확인.