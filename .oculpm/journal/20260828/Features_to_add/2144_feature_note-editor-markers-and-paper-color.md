---
schema_version: 1
type: feature
slug: "note-editor-markers-and-paper-color"
status: done
difficulty: high
created_at: "2026-08-28T21:44:36+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/LineMarker.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/HoverSensor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Stream/StreamView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/LineMarkerTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "ux"
  - "design"
  - "markdown"
  - "textkit"
  - "color"
  - "render"
  - "mcp-tool"
---
[x] 메모장 디자인 — 줄머리 표시를 여백에 그리고, 종이 색이 실제로 구별되게

사용자의 요구: "디자인도, 이 앱의 메모장까지도 편안해야 한다." 추측하지 않고 `render-ui.sh` 로 실제 화면을 그려 놓고 봤다.

## 추가 기능

**1. 줄머리 표시를 여백에 그린다 (`LineMarker`)**

렌더를 보니 `- [x] 우유` 가 화면에 `[x] 우유` 로 남아 있었다. `- ` 만 감추고 대괄호는 그대로라, "마크다운 즉시 꾸밈"이 반만 지켜져 오히려 더 어색했다. 불릿은 흔적도 없이 사라져 목록이 목록으로 안 읽혔고, 인용은 그냥 문단이 됐다.

정본이 마크다운이라(D4) 글자를 바꿔 끼울 수는 없다. 그래서 마커 글자를 감추고 **문단 들여쓰기로 비운 왼쪽 여백에 직접 그린다** — 체크상자, 글머리 점, 인용 세로선. 원문은 파일에 그대로 있고, 커서가 그 줄에 오면 되돌아온다.

**2. 체크상자를 눌러서 뒤집는다**

다 한 일을 알리려고 `[ ]` 를 `[x]` 로 글자를 고치게 하는 것은 이 앱이 가장 싫어할 종류의 불편이다. 창에 포커스가 없어도 눌린다 — 바탕화면의 종이는 지나가다 툭 누르는 물건이다. `shouldChangeText` 를 거치므로 되돌리기도 이어진다.

**3. 종이 색이 실제로 구별된다**

여섯 색을 나란히 렌더해 보니(`palette.png`) 빛 모드에서 **전부 같은 흰 종이**였다. 잉크를 그대로 섞으면 색마다 밝기가 달라져 파랑·보라는 회색으로 죽고 노랑만 색으로 읽힌다. 잉크의 밝기를 먼저 맞춘 뒤 섞도록 바꾸고, 세기를 두 번 오르내리며 "구별은 되되 문구점 형광 메모지로 넘어가지 않는" 자리를 잡았다. 점 그리드도 잉크 색으로 찍어 종이를 어둡게 하지 않고 색을 더한다.

**4. 곁다리 두 개** — 제목 아래 숨 쉴 자리(`paragraphSpacing`), 그리고 「흐름」에서 "오늘은 비어 있습니다" 제거(빈칸을 채우라고 말하지 않는다, 철학 1).

## 동작 흐름

`MarkdownStyler` 가 마커 구간을 감추고 문단 들여쓰기를 넣은 뒤 내용 구간에 `.lineMarker` 속성을 붙인다 → `MemoNSTextView.draw` 가 그 속성을 훑어 여백에 그린다 → `mouseDown` 은 종이 끌기·커서보다 **먼저** 체크상자를 본다.

## 검증

- `swift build` 무경고 · `./scripts/test.sh` **121개 통과** (새 `LineMarkerTests` 6개 포함 — 표시 개수·여백 안에 있는지·제 줄과 세로가 맞는지·눌러서 뒤집히는지·빗나간 클릭 무시·원문 보존).
- `verify-performance.sh` RSS 99.1MB / idle CPU 0% — 예산 이내. `verify-notes.sh` 창 레벨 정상.
- `render-ui.sh` 로 `editor.png`(실제 `NSTextView` 를 그대로 떠낸 것) · `palette.png` · `note.png` · `stream.png` 를 눈으로 확인.
- 좌표는 눈대중을 믿지 않고 **렌더 PNG 를 픽셀로 재어** 맞췄다: 표시 중심 66.0/88.5/112.5 대 글자 중심 66.0/87.8/111.8 (오차 1pt 미만).

## 메모

**세 번 틀렸고 세 번 다 렌더를 눈으로 봐야만 드러났다.** ① 줄 상자를 텍스트 컨테이너 좌표로 쓰고 `textContainerInset` 을 안 더해 표시가 통째로 한 줄 위. ② 눈높이를 라틴 x-높이로 계산 — 한글에는 x-높이가 없고 그리는 글꼴도 한글 대체 글꼴이다. ③ 글꼴을 `NSTextView.font` 로 조회 — 그것은 **첫 글자의 글꼴**이고 첫 줄이 `## 제목` 이면 감춘 `## `(0.01pt)를 물고 와 계산이 0 이 된다.

세 번째가 특히 고약하다. 빌드도 테스트도 통과하고 화면도 얼핏 멀쩡하다.

그리고 이번에 **내가 넣은 `HoverSensor` 가 렌더 파이프라인을 깨뜨렸다** — `ImageRenderer` 는 `NSViewRepresentable` 을 못 그리고 뷰 전체를 금지 표시로 바꾼다. 그 덕에 렌더를 열어 본 것이 오히려 다행이었다. `rendersStatically` 환경값으로 화면 밖 렌더에서는 감지기를 빼도록 고쳤고, 같은 이유로 편집기는 `NSTextView` 를 직접 떠내는 경로를 새로 냈다 (`MemoTextEditor.makeTextView` 를 앱과 렌더가 공유한다 — 설정이 갈라지면 확인 자체가 거짓말이 된다).