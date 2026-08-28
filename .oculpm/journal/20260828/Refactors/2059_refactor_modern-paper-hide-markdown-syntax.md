---
schema_version: 1
type: refactor
slug: "modern-paper-hide-markdown-syntax"
status: done
difficulty: high
created_at: "2026-08-28T20:59:48+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Stream/StreamView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "design"
  - "skeuomorphism"
  - "markdown"
  - "live-preview"
  - "dot-grid"
  - "dark-mode"
  - "mcp-tool"
---
[x] 촌스러움 걷어내기 — 리갈패드에서 좋은 노트로, 마크다운 기호는 커서 줄에서만

사용자 지적: "메모장 디자인이 촌스럽다."

맞는 말이었다. 앞선 요청("현실 세계의 노트처럼")을 **노란 리갈패드**로 해석한 것이 잘못이었다. 진한 카나리아 노랑 바탕에 파란 가로 괘선은 현실의 종이가 아니라 **2011년의 스큐어모피즘**이고, 옛 메모 앱의 인상이 그대로 떠오른다.

## 동기

"현실의 종이"를 문자 그대로 흉내 내면 촌스러워진다. 기준을 **좋은 노트**(무지·로이텀·필드노트)로 바꿨다. 종이의 감각은 남기되 시대를 옮긴 것이다.

## 변경 요약

| | 버린 것 | 지금 |
|---|---|---|
| 바탕 | 진한 카나리아 노랑 | 미색 오프화이트 (다크는 따뜻한 숯색) |
| 색 | 온 면을 물들임 | 종이에 7% 스밈 + 도트 그리드 색 |
| 결 | 파란 가로 괘선 | **도트 그리드** — 지금 문구류의 언어이고 글을 줄에 맞출 의무도 없다 |
| 모서리 | 3pt (너무 날카로움) | 5pt |
| 여백 | 14pt | 20pt — 싸구려 메모지는 글이 가장자리에 붙어 있다 |
| 결 세기 | 0.30 | 0.16 |

**다크 모드에서 종이를 밝게 두지 않는다.** 어두운 화면에 흰 판이 박히면 눈이 아프다. 검은 문구류가 실제로 있고 그쪽이 낫다 — 따뜻한 숯색 종이에 미색 잉크. 이를 위해 종이색과 잉크색을 `NSColor(name:dynamicProvider:)` 로 바꿨다.

## 마크다운 기호를 커서 줄에서만 보인다

두 번째 촌스러움은 **본문에 마크다운 원문이 그대로 보이는 것**이었다. `##`, `- [ ]`, `**`, 그리고 두 줄로 접히는 `](https://…)` 와 ULID 가 박힌 `![](attachments/01M143…)`. 코드 편집기처럼 보였다.

Bear·Obsidian 방식으로 고쳤다. **기호는 커서가 놓인 줄에서만 나타난다.** 다른 줄에서는 제목이 그냥 큰 글씨로, 링크가 이름만으로, 이미지 참조는 아무것도 남기지 않는다(그림은 아래에 붙으므로).

감추는 방법이 요점이다 — **글자를 지우는 것이 아니라 보이지 않을 만큼 작은 글꼴(0.01pt)을 입힌다.** 파일은 그대로고, 그 줄로 커서를 옮기면 마커가 되돌아와 고칠 수 있다. `MarkdownScanner` 의 "원문을 건드리지 않는다" 규칙을 지키면서 같은 결과를 얻는다.

체크박스는 `- ` 만 감춰 `[ ]` `[x]` 를 남긴다. 고정폭 글꼴에서 그 자체가 체크상자로 읽히는데, 앞에 붙임표가 있으면 다시 마크다운 원문으로 보인다.

커서가 줄을 옮길 때 다시 칠하도록 `textViewDidChangeSelection` 을 붙였다. 다시 칠하는 도중 선택이 바뀌어 되돌아 들어오는 것을 막는 플래그를 뒀다.

## 알아낸 것 — 동적 색은 SwiftUI 환경을 모른다

다크 모드에서 종이만 밝은 채로 잉크가 같이 밝아져 글이 보이지 않았다. `NSColor(Paper.surface).usingColorSpace(.sRGB)` 가 **그리는 시점의 외관**으로 굳는데, 그것이 SwiftUI 의 `colorScheme` 환경과 다를 수 있다(화면 밖 렌더가 그렇다). 반드시 해당 외관 안에서(`performAsCurrentDrawingAppearance`) 해석해야 한다. 앞서 한 번 겪고 고친 함정인데 팔레트를 갈아엎으며 되살아났다.

## 검증

- 테스트 115개 통과, `verify-notes` 통과.
- 성능: RSS **94.4MB** (예산 100MB), idle CPU 0.0%.
- `build/ui/note-plain.png` — 제목·체크박스·인용·링크·사진이 마크다운 기호 없이 깨끗하게 나온다. 라이트는 미색 종이, 다크는 숯색 종이.
- **육안 확인 대기** — 실제 화면에서의 인상, 그리고 커서를 줄에 올렸을 때 기호가 되돌아오는지.