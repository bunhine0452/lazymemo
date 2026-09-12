---
schema_version: 1
type: feature
slug: "drawer-folders-list-redesign"
status: done
difficulty: high
created_at: "2026-09-13T00:39:58+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "fe0a240b-4d1d-4212-8030-d5c7eb993490"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MemoFolders.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoMCP/MemoTools.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerRow.swift"
    op: create
  - path: "Sources/LazyMemoUI/Drawer/DrawerPaper.swift"
    op: delete
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerGeometry.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerContents.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerKeys.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoFoldersTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoFileTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerPickingTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/DrawerKeysTests.swift"
    op: update
  - path: "scripts/verify-mcp.sh"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related:
  - ref: "20260913/Features_to_add/0000_feature_capture-draft-persist-and-initials.md"
    kind: "followup"
  - ref: "20260912/Refactors/1535_refactor_cream-forest-visual-redesign.md"
    kind: "followup"
tags:
  - "drawer"
  - "folders"
  - "redesign"
  - "mcp"
  - "mcp-tool"
---
[x] 서랍 — 이름 있는 폴더 여러 개, 겹친 무더기에서 목록으로 전면 개편

## 추가 기능

사용자가 서랍(「폴더 기능」)을 기능·디자인 모두 거절했다. 갈림길 둘을 물어 확정: **이름 있는 폴더 여러 개** + **닫힌 서랍은 바탕화면에 작게 상주**. 설계문서 §16.1(「폴더 하나·이름 없음」)과 §16.2(겹친 무더기)를 뒤집었고 §16.11 에 근거를 적었다.

- **데이터**: `Memo.folder` (frontmatter `folder:` 한 줄). `MemoFolders`(Core) 가 이름 정규화·설정 차례 ∪ 메모 이름표·이름 바꾸기·장수 세기·거르기를 순수 함수로 든다. 차례와 빈 폴더는 `Settings.folders`. `MemoService/MemoStore.create·update(folder:)`.
- **MCP**: `create_memo`·`update_memo` 에 `folder`, `list_memos` 에 `folder` 필터, 새 도구 `list_folders`. 응답 JSON 에 `folder` 포함. 도구 7→8개.
- **서랍 화면** (`DrawerView`·`DrawerRow` 신설, `DrawerPaper` 삭제): 닫힌 서랍은 168×48 탭(「서랍 N」, 끌어다 놓으면 「놓으면 들어옵니다」). 펼치면 위에서부터 찾기 줄 → 폴더 띠(전체·폴더들·+ 새 폴더) → 목록(색·제목·둘째 줄·시각, 넘치면 스크롤) → 바닥 줄. 줄에 손을 얹으면 꺼내기·폴더·지우기, 줄을 누르면 아래로 펼쳐 본문과 조작. 줄을 칩으로 끌어 옮기기(`draggable`/`dropDestination`), 칩 우클릭으로 이름 바꾸기·지우기, 인라인 이름 상자. 종이 우클릭에 「서랍에 넣기 ▸ 폴더」.
- **모델** (`DrawerModel`): `selectedFolder`(접어도 남는다), `expanded`(옛 zoomed), `isNamingFolder`/`renamingFolder`, `move`·`createFolder`·`renameFolder`·`deleteFolder`·`stepFolder`(Tab). 폴더를 보는 중에 들어온 종이는 그 폴더로. 이름 바꾸기·지우기는 바탕화면에 나와 있는 종이의 이름표까지 따라가고, 파일 쓰기가 비동기라 옛 이름은 `retired` 로 마지막 이름표가 떨어질 때까지 감춘다. esc 겹: 고르기 → 이름 적기 → 찾기 → 펼친 줄 → 짚은 자리 → 폴더 → 서랍.
- **판형** (`DrawerGeometry`): 줄 50pt·펼침 +148pt·최소 3줄, `listCeiling(fitting:)` 으로 화면 상한, 넘치면 스크롤. 자라는 방향(§16.4)과 `landingSpot` 은 그대로.

## 동작 흐름

종이 × 또는 끌어놓기 → `layout.hidden` → `DrawerContents.holds` (규칙 불변) → 폴더는 `memo.folder` 로 칸만 정한다. 「폴더에 넣기」 = `setFolder` + `onClose`. 꺼내면 이름표는 남아 다시 넣으면 같은 칸.

## 검증

- `scripts/test.sh` 672개 / 102 스위트 통과 (서랍 시험 3파일 전면 재작성, `MemoFoldersTests`·`MemoFile` 폴더 왕복 추가).
- `scripts/verify-drawer.sh` 실제 창: 모서리고정·제자리복귀·계획크기 모두 true.
- `scripts/verify-mcp.sh` 통과 (폴더 왕복·`list_folders`·폴더 필터 3항목 추가, 개수 검사 갱신).
- `scripts/render-ui.sh build/folder-ui` 로 drawer·landing·open·expanded·folder·naming·searching·nothing-found·picked 9장 눈으로 확인. 정적 렌더가 `ScrollView`·`Menu`·`contextMenu`·`dropDestination` 을 못 그려 `rendersStatically` 분기를 넣었다.

## 메모

- 철학 4(도구를 드러내지 않는다)와 부딪히는 자리(늘 보이는 찾기 줄·폴더 띠)는 §16.11 에서 인정하고 근거를 적었다.
- 미커밋. `DrawerPaper.swift` 삭제만 `git rm` 으로 스테이지됨.