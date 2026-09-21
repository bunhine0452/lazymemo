---
schema_version: 1
type: feature
slug: "long-memo-readability"
status: done
difficulty: high
created_at: "2026-09-18T19:21:15+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/LongMemoStylingTests.swift"
    op: create
related:
  - ref: "20260918/Features_to_add/1920_feature_mac-paper-fits-content.md"
    kind: "blocked_by"
  - ref: "20260917/Bugs/2139_bug_mac-photo-reference-reappears-after-save.md"
    kind: "followup"
tags:
  - "performance"
  - "markdown"
  - "editor"
  - "ios"
  - "long-memo"
  - "mcp-tool"
---
[x] 긴 메모에서 타자가 안 밀린다 — 꾸밈을 고친 줄만 다시 깔아 297ms→1ms, 폰 목록은 긴 글을 넉 줄까지

종이를 글에 맞춰 키워 놓고 보니 그 다음 문제가 드러났다: **큰 메모 안에서 글을 못 친다.** 재 보니 2만 3천 자에서 키 한 번에 0.30초가 들었다 — 한 프레임(16ms)의 열여덟 배다.

## 추가 기능

**어디에 드는지부터 쟀다** (`LongMemoStylingTests`, 23,359자):

| 하는 일 | 한 번 | 언제 도는가 |
|---|---|---|
| `MarkdownStyler.apply` 전체 | 297ms | 키를 누를 때마다 |
| 그 중 `MarkdownScanner.spans` | 240ms | 위 + 커서가 움직일 때마다 + ⌫ 마다 |
| 바탕 속성 다시 깔기 | 6ms | |

비용의 8할이 **스캔**이었고, 스캔은 세 곳에서 글 전체를 훑고 있었다.

- **`MarkdownStyler.apply(scope:)`** — 다시 깔 구간을 받는다(기본값 `nil` = 전부라 기존 호출은 그대로다). 마크다운 구간은 `.route` 를 뺀 전부가 **한 줄 안에서 끝나므로**, 고친 줄만 스캔·적용해도 결과가 같다. 구간은 언제나 줄 경계까지 넓힌다(반 줄만 주면 스캐너가 다른 것을 본다). 「가는 길」 절이 본문에 있으면 여러 줄이 한 덩이라 통째로 다시 깐다 — 기계가 적는 절이라 드물고, 드문 쪽이 느린 것이 낫다.
- **`Coordinator` 가 구간을 짚는다** — 친 자리는 커서와 길이 차이로(넣은 글자는 커서 앞에 놓인다), 커서가 옮겨 간 자리는 들고 난 두 줄로, 포커스가 오갈 때는 그 한 줄로. **멀리 떨어진 두 줄은 합치지 않는다**(`regions`) — 먼 곳을 클릭했다고 그 사이 만 자를 다시 깔면 좁힌 뜻이 없다.
- **커서를 사진 밖으로 미는 검사**(`keepCaretOutOfPhotos`)도 커서 줄만 스캔한다. 커서를 밀어내는 것은 커서를 품은 참조뿐이라 답이 같은데, 전에는 **화살표 한 번에 0.24초**를 썼다.
- **⌫ 가 사진을 한 덩이로 떼는 검사**(`MachineLines.deletion`)에는 그 언저리 세 줄만 넘긴다. `MachineLines` 는 건드리지 않고 부르는 쪽에서 창을 좁혔다.
- **여백의 줄머리 표시**(`forEachLineMarker`)는 이번에 그리는 구역의 글자만 본다. 화면 밖 줄의 자리를 물어보는 것만으로도 배치가 깔린다.
- **폰 목록** (`MemoRowView`) — 300자 넘는 본문의 미리보기는 두 줄이 아니라 **넉 줄까지**. 긴 글을 붙인 메모는 제목 한 줄이 링크나 날짜뿐인 일이 흔해, 두 줄로 잘리면 무슨 메모인지 알 수 없다. 짧은 줄은 `lineLimit` 을 올려도 그만큼 안 자라니 칸의 키는 그대로다. 큰 글자(accessibility)는 원래의 셋에서 시작한다.

## 동작 흐름

친다 → `textDidChange` → 커서와 길이 차이로 고친 구간을 짚는다 → `restyle(scope:)` → 그 줄들만 `MarkdownStyler.apply`. 커서만 움직이면 `textViewDidChangeSelection` 이 들고 난 두 줄만.

**함정**: 붙여넣기 한 번에 **선택 알림이 먼저, 글 바뀜 알림이 나중에** 온다. 처음엔 `restyle` 이 길이를 갱신하게 뒀더니 앞의 것이 길이를 먼저 갈아 끼워, 뒤의 것이 「아무것도 안 늘었다」고 읽고 **붙인 줄을 통째로 안 꾸몄다** — 사진 참조 40자가 그대로 드러났다. `PhotoPasteTypingTests`(어제 그 결함을 못박아 둔 시험)가 바로 잡아냈다. 구간을 받아 온 호출은 길이를 건드리지 않고, 전체 갱신만 다시 맞춘다.

## 검증

- 측정: 한 줄 다시 깔기 **1.03ms** (전체 297ms → 288배). `LongMemoStylingTests` 가 16ms 천장을 지킨다 — 전체를 다시 까는 길로 되돌아가면 20배로 넘어 반드시 걸린다.
- **같은 것을 그리는가**: 좁게 깐 결과와 전부 깐 결과의 `NSAttributedString` 이 같다(구간 경계·「가는 길」 절 되돌아가기 각각 1건).
- `swift test` 전부 초록 — 1036건, LazyMemoUITests 377건. 특히 `PhotoPasteTypingTests`·`LineMarkerTests`·`MemoTextSyncTests`·`CapturePasteTests` 그대로 통과.
- 아이폰: `xcodebuild build -scheme LazyMemo-iOS -destination 'iPhone 17'` **BUILD SUCCEEDED** (derived data 는 `.build/ios-paper` 681MB, 끝나고 지웠다).
- `scripts/verify-capture-paste.sh` ✓ — 빠른 입력의 ⌘V 가 여전히 사진을 넣고 조각으로 보인다(꾸밈 경로를 함께 고쳤으므로).

## 메모

- 길이 짚기가 어긋나면(밖에서 글이 통째로 바뀌는 길) 다음 전체 갱신이 고친다 — `updateNSView` 는 언제나 전체로 깐다.
- 폰의 미리보기는 여전히 **본문 한 줄**이다(`Memo.previewLine`). 짧은 줄이 여럿인 긴 메모는 그 한 줄만 보인다 — 여러 줄을 모으려면 Core 의 `Memo.textLines` 를 공개해야 해서 이번에는 두지 않았다.
- 아직 안 한 것: 2만 자에서의 **스크롤** 프레임은 재지 않았다(줄머리 표시만 좁혔다).