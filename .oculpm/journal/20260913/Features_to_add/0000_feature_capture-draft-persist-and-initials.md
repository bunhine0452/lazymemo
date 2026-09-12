---
schema_version: 1
type: feature
slug: "capture-draft-persist-and-initials"
status: done
difficulty: medium
created_at: "2026-09-13T00:00:38+09:00"
session_id: "mcp-20260913-000038"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/HangulInitials.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/CaptureDraftStore.swift"
    op: create
  - path: "Sources/LazyMemoCore/AppPaths.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerSearch.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/CaptureDraftStoreTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/HangulInitialsTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureDraftTests.swift"
    op: create
  - path: "README.md"
    op: update
  - path: "docs/APP_STORE_READINESS.md"
    op: update
related:
  - ref: "20260912/Chores/1515_chore_app-store-readiness-audit.md"
    kind: "followup"
  - ref: "20260912/Features_to_add/1518_feature_paper-welcome-and-capture.md"
    kind: "followup"
tags:
  - "quick-capture"
  - "draft"
  - "hangul-initials"
  - "search"
  - "mcp-tool"
---
[x] 빠른 입력 — 초안이 껐다 켜도 남고, 첫소리로도 찾는다

## 추가 기능

사용자가 「개선점을 판단해 더 완벽하게」를 요청. 0.3.0 전체를 훑어 두 곳의 약속 어김을 골랐다.

1. **초안이 프로세스와 함께 죽었다.** README 는 「적던 글은 상자가 기억한다」고 약속하는데 메모리에만 있어서, 판 갈이(앱이 스스로 닫혔다 뜬다)·재부팅·크래시에 세 줄 적어 둔 것이 사라졌다. App Store 점검 문서의 품질 항목이기도 했다. `CaptureDraftStore` 가 파생물 자리(`support/capture-draft.txt`)에 400ms 디바운스로 적고, 상자를 닫을 때와 앱이 끝날 때는 즉시 적으며, 확정(`clear`)하면 파일을 지운다. 메모가 아니라 초안이라 검색어가 메모로 쌓이지 않는다는 원칙은 그대로다.
2. **찾는 상자가 둘인데 규칙이 달랐다.** 서랍은 `ㅈㅂㄱ` 첫소리로 찾는데 빠른 입력은 인덱스(FTS trigram)만 봐서 안 됐다. 첫소리 규칙을 `HangulInitials`(Core)로 내리고 `DrawerSearch` 가 위임하며, `QuickCaptureModel.search` 는 질의가 통째로 초성이면 인덱스를 건너뛰고 메모리의 메모를 훑는다. `#체크 ㅈㅂㄱ` 처럼 거름 조건과도 겹친다.

## 동작 흐름

- 켤 때 `QuickCaptureModel.init` 이 `draft.restored` 를 `query` 에 도로 든다 → `prepareForShow` 가 글이 있으면 **다시 찾는다** (예전엔 빈 상자일 때만 목록을 새로 지어, 도로 든 글 아래 목록이 비어 있었다).
- 타자 → `query.didSet` → `draft.remember` (디바운스) · 닫기 → `flushDraft` · ⌘⏎ → `clear` → `forget` · 종료 → `AppDelegate.applicationShouldTerminate` → `menuBar.flushCaptureDraft()`.
- 초성 질의 → `HangulInitials.matches(title+body)` 로 `store.memos` 거르기, 차례는 인덱스와 같다(고정 먼저·최근순).

## 검증

- `scripts/test.sh` 662개 / 101 스위트 전부 통과 (새 시험 13개: `CaptureDraftStoreTests`·`HangulInitialsTests`·`CaptureDraftTests`).
- 실제 앱: 임시 Vault 의 `support/capture-draft.txt` 에 두 줄을 심고 `LAZYMEMO_CAPTURE=0 LAZYMEMO_DISMISS=1` 로 띄움 → 진단에 `draft=19자`, 상자 높이 223pt(두 줄 반영), 나간 뒤 파일 그대로.

## 메모

- 남은 후보(안 함): 단축키 충돌은 이미 메뉴가 적는다 · 메모 수천 장 인덱스 전략은 설계문서 §13 미결 그대로 · 샌드박스 북마크는 App Store 제출 때.