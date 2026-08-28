---
schema_version: 1
type: feature
slug: "real-paper-markdown-photos-links"
status: done
difficulty: superhigh
created_at: "2026-08-28T20:40:17+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/LinkLabel.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/AttachmentStore.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoPalette.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCapturePanel.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "scripts/make-icon.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MarkdownScannerTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "paper-design"
  - "skeuomorphism"
  - "markdown"
  - "nstextview"
  - "attachments"
  - "links"
  - "bug-fix"
  - "privacy"
  - "mcp-tool"
---
[x] 진짜 종이 디자인과 편집기 — 마크다운 즉시 꾸밈, 사진 붙여넣기, 링크 임베딩

사용자 지적 셋을 처리했다. ① 메뉴바 아이콘을 눌러도 빠른 입력이 안 뜬다 ② 디자인이 나쁘다, 유리 말고 **현실의 노트**처럼 만들어라 ③ 사진 붙여넣기·마크다운 즉시 포맷·링크 임베딩을 지원하라.

## 고친 버그 — 클릭해도 창이 안 떴다

`QuickCapturePanel.resignKey()` 에서 곧바로 `orderOut` 하고 있었다. 메뉴바 아이콘 클릭이 끝나면서 상태바 창이 키를 되가져가고, 그 순간 우리 창이 자기를 닫아 버린다. 뜨자마자 사라지니 "안 뜬다" 로 보인다.

`resignKey` 재정의를 걷어내고 `hidesOnDeactivate` 에 맡겼다 — 다른 앱으로 넘어가면 사라지고, 우리 앱 안에서 포커스가 옮겨 다니는 동안에는 살아 있다. `.transient` 도 뺐다 (Space 이동·Mission Control 에서 창이 사라진다). 그리고 클릭은 토글이 아니라 **표시**로 바꿨다 — 토글이면 "안 떴나?" 싶어 한 번 더 눌렀을 때 도로 닫혀 고장난 것처럼 보인다.

## 진짜 종이

미니멀하게 비워 둔 화면이 "구리다" 는 지적은 맞았다. 성격이 없었다. 현실의 종이가 물건으로 보이는 이유 넷을 다 흉내 냈다.

- **온 면이 색이다.** 접착 메모지는 가장자리만 노란 것이 아니다. 색을 테두리에만 두던 규칙을 버리고 문구점 종이 색(카나리아·라임·하늘·라일락·장미·마닐라)을 면 전체에 깔았다.
- **표면이 고르지 않다.** 잡티와 가로 섬유로 이루어진 타일 텍스처를 코드로 만들어(`--texture`) 아주 옅게 덮었다. 위치에 의존하지 않는 잡음만 써서 이음매가 생기지 않는다.
- **위쪽이 다르다.** 접착제가 붙은 띠가 미묘하게 짙게 비친다.
- **아래가 들린다.** 바닥에 닿는 쪽에 그늘이 진다.

여기에 **괘선**을 넣었다. `NSTextView` 의 줄 높이를 못 박고 같은 간격으로 줄을 그어 글이 줄 위에 앉는다. 그리고 **모서리 반경을 16에서 3으로 줄였다** — 종이는 각져 있고, 둥글릴수록 UI 카드로 보인다. 이 한 줄이 인상을 가장 크게 바꿨다.

바램(`MemoAge`)도 종이답게 고쳤다. 투명도를 낮추는 대신 **마닐라색 쪽으로 누레진다.** 잉크는 그만큼 사라지지 않는다 — 물러나는 것과 안 보이는 것은 다르다.

다크 모드에서도 종이는 종이다. 색을 바꾸지 않고 밝기만 낮춘다(0.88) — 어두운 방의 종이다.

## 마크다운 즉시 꾸밈

**글자를 바꾸지 않는다.** `**굵게**` 를 치면 그 자리에서 굵어지지만 파일에는 여전히 `**굵게**` 가 저장된다. `MarkdownScanner`(Core, 테스트 가능)가 구간만 계산하고 `MarkdownStyler`(UI)가 그 위에 속성을 입힌다. 원문을 건드리는 순간 D4·한글 조합·되돌리기가 한꺼번에 무너진다.

마커는 지우지 않고 흐리게 눌러 둔다 — 지우면 커서가 갈 곳을 잃는다. 다만 `](https://…)` 같은 긴 마커는 색만 죽여서는 시끄러워 **글자 크기까지 줄였다.** 그러면 링크 이름만 남은 것처럼 보인다.

조합 중에는 다시 꾸미지 않는다. 속성을 통째로 다시 까는 동안 조합 밑줄이 지워지기 때문이다.

## 사진

`AttachmentStore` — `<Vault>/attachments/<ulid>.<ext>` 에 **진짜 파일**로 저장하고 본문에는 상대 경로 참조만 남긴다. 붙여넣기 판의 png·jpeg·heic·tiff 중 있는 것을 그대로 옮긴다(재인코딩하면 화질과 용량을 괜히 잃는다). 본문은 사용자와 LLM 이 쓰는 값이라 `..` 나 `/` 로 시작하는 경로는 열어 주지 않는다.

**그림은 글 아래에 붙는다.** 글줄 사이에 끼우려면 "글자를 바꾸지 않는다" 를 어기고 원문을 숨기는 편법이 필요하고, 그러면 커서와 되돌리기가 어긋난다. 종이에 사진을 붙이는 것도 대개 글 아래다.

## 링크 — 네트워크 없는 임베딩

붙여넣은 URL 이 마크다운 링크가 되고 파랗게 밑줄 쳐져 한 번 눌러 열린다.

**이름은 주소 자체에서만 만든다** (`LinkLabel`). 페이지를 열어 제목을 가져오면 보기에는 좋지만 §9.3 의 "기본 상태에서 네트워크를 쓰지 않는다" 가 그 순간 깨진다. 메모를 적는 것만으로 바깥에 요청이 나가서는 안 된다. `github.com/lazymemo` 만 봐도 사람은 무엇인지 안다.

클릭 규칙은 **편집 중이 아니면 열고, 쓰는 중이면 커서**다 (⌘클릭은 언제나 열기). 언제나 열면 링크 글자를 고칠 수 없고, 언제나 커서만 놓으면 붙여넣은 링크가 장식이 된다.

## 알아낸 것 — 미리보기가 꾸밈까지 보여주게 만들기

정적 렌더가 평범한 `Text` 로 대체하면 배치는 봐도 마크다운 꾸밈이 맞는지 알 수 없다. 같은 `MarkdownStyler` 를 태워 `NSTextStorage` 를 만든 뒤 `Text(AttributedString(storage))` 로 건네니, 미리보기가 실제 편집기와 같은 것을 그린다. 이 덕분에 마커 크기와 링크 꼬리 처리를 눈으로 보고 고쳤다.

## 검증

- 테스트 **115개** 통과 (`MarkdownScanner` 11, `AttachmentStore` 4, `LinkLabel` 4 신규). 한글이 섞인 구간이 어긋나지 않는지, 코드 안의 별표가 강조로 잡히지 않는지, Vault 밖 경로를 거절하는지를 못 박았다.
- `verify-notes` · `verify-mcp` · `verify-restore` 통과.
- 성능: RSS **93.8MB** (예산 100MB), idle CPU 0.0%. 속성 문자열이 얹혀 여유가 6MB 로 줄었다 — 다음에 무엇을 더할 때 먼저 재야 한다.
- `build/ui/note-plain.png` 에 제목·체크박스 취소선·굵게·인용·링크·붙인 사진이 한 장에 나온다.
- **육안 확인 대기** — 실제 붙여넣기 동작과 메뉴바 클릭.