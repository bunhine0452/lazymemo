---
schema_version: 1
type: feature
slug: "design-philosophy-and-ui-overhaul"
status: done
difficulty: superhigh
created_at: "2026-08-28T19:38:17+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/KoreanDateParser.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/MemoAge.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Stream/StreamModel.swift"
    op: create
  - path: "Sources/LazyMemoUI/Stream/StreamView.swift"
    op: create
  - path: "Sources/LazyMemoUI/Stream/StreamWindowController.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCapturePanel.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/KoreanDateParserTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoAgeTests.swift"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "design-philosophy"
  - "ui-overhaul"
  - "korean-date-parser"
  - "stream"
  - "patina"
  - "nspanel"
  - "bug-fix"
  - "swiftui"
  - "mcp-tool"
---
[x] 디자인 철학 확립과 UI 대격변 — 격자를 흐름으로, 유리를 종이로, 한국어 날짜 인식

사용자 요청으로 디자인 철학을 문장으로 세우고 UI 를 구조부터 다시 만들었다. 설계문서 §14 를 철학 문서로 다시 썼다. 함께 보고된 팝오버 위치 버그도 고쳤다.

## 철학 — 「흐릿하게 남는다」

네 문장으로 정했고, `Theme.swift` 가 그 구현이다.

1. **완성을 요구하지 않는다** — 쓰다 만 것이 정상 상태다
2. **시간이 유일한 구조다** — 게으른 사람이 받아들이는 유일한 구조는 "언제"뿐이다
3. **오래된 것은 스스로 물러난다** — 정리하지 않아도 화면이 정돈된다
4. **앱은 자기를 드러내지 않는다** — 기본 상태는 글자와 종이뿐이다

이전 라운드의 UI 는 유능했지만 관습적이었다. 둥근 카드, 월 격자, 검색창 — 어느 메모 앱이어도 되는 화면이었고, 아이콘의 "흐지부지" 라는 생각이 UI 어디에도 없었다.

## 대격변 넷

**캘린더를 버리고 「흐름」으로.** 월 격자는 조망 도구인데, 게으른 사람이 알고 싶은 것은 "이번 달 지도"가 아니라 "다음에 뭐가 오나"다. 오늘부터 아래로 흐르는 목록이고, 일정 없는 날은 아예 그리지 않는다 (철학 1 — 빈 칸을 보이는 것은 "채워라"라고 말하는 것이다). 상단 점 스트립이 조망을 맡되 **일이 있는 날과 오늘에만 숫자를 적는다** — 전부 숫자면 밀도 신호가 묻히고, 전부 점이면 "15일이 무슨 요일이지"에 답하지 못한다.

**한국어 날짜를 앱이 읽는다** (`KoreanDateParser`). "내일 오후 3시 치과" 가 곧 일정이 된다. LLM 없이, 네트워크 없이. §1 의 "정리를 대신 해준다"가 UI 에서 처음 실현되는 지점이다. 칩에는 인식한 원문이 아니라 **해석한 결과**를 보이고("내일"이라고 되쓰면 확인이 안 된다), 인식한 조각은 본문에서 덜어낸다("내일 오후 3시 치과"는 내일이 지나면 거짓말이 된다).

**바램** (`MemoAge`). 시간이 지난 메모가 조용히 물러난다. 예외 둘이 규칙을 사람 편으로 만든다 — 고정한 메모는 바래지 않고(사용자가 직접 앞에 두라고 말한 것), 다가오는 일정은 언제 적었든 또렷하다.

**크롬 제거.** 메모에서 머리글·아이콘 줄·색 점을 전부 없앴다. 색은 테두리와 왼쪽 위에서 번지는 잉크로만 드러난다. 조작은 포인터가 올 때 내용 **위에 겹쳐** 뜬다.

## 고친 버그 — 팝오버가 엉뚱한 자리에

사용자 보고: 메뉴바 아이콘을 누르면 팝업이 동떨어진 곳에 떴다.

위치를 고치는 대신 **접근을 바꿨다.** `NSPopover` 를 메뉴바 아이콘에 매달면 아이콘이 어디 있느냐에 따라 위치가 흔들리고, 메뉴바가 붐벼 아이콘이 숨겨지면 엉뚱한 자리에 뜬다. 게다가 주 경로는 단축키이고 그때 시선은 메뉴바가 아니라 화면 가운데 있다.

`NSPanel` 로 바꾸고 **위치를 우리가 정한다** — 마우스가 있는 화면의 위쪽 3분의 1(Spotlight 자리). 버그가 고쳐진 것이 아니라 버그가 생길 수 있는 구조가 없어졌다.

## 알아낸 것 — 유리는 세 번 다 틀렸다

가장 값진 발견. 메모 → 흐름 → 빠른 입력 순으로 `glassEffect` 를 시도했다가 **세 번 다 되돌렸다.** 반투명한 면 위에서 글이 씻겨 나간다.

특히 빠른 입력에서는 오래 헤맸다. 글자가 아예 안 보여서 칩과의 가로 공간 경쟁을 의심하고, 폰트 굵기를 의심하고, 모델 값을 로그로 찍어 확인까지 했는데 값은 멀쩡했다. `Text` 뒤에 빨간 배경을 깔아 보고서야 알았다 — **글자는 계속 거기 있었고 배경과 같은 색으로 씻겨 있었다.**

그래서 철학 문장 하나를 고쳤다. 처음엔 "읽는 면은 종이, 지나가는 것은 유리" 였는데, 지금 치고 있는 글자가 있는 곳이야말로 가장 읽혀야 하는 자리다. **재질은 하나 — 종이.** 떠 있다는 느낌은 투명도가 아니라 그림자와 크기와 자리가 만든다.

## 알아낸 것 — 화면 밖 렌더의 한계 셋

`ImageRenderer` 로 실제 뷰를 확인하는 통로에 함정이 셋 있었고 전부 우회했다. `NSViewRepresentable` 은 안 그려지고(→ `Text` 로 대체), `ScrollView` 안의 내용도 안 그려지며(→ 스크롤 없이 편다), `LazyVStack` 은 실체화되지 않는다(→ `VStack`). 환경값 `rendersStatically` 하나로 흐른다.

## 검증

- 테스트 **96개** 통과 (한국어 날짜 14개, 바램 6개 신규).
- `verify-notes` · `verify-mcp` · `verify-restore` 전부 통과.
- 성능: RSS **92.0MB** (예산 100MB), idle CPU 0.0%. 재디자인 도중 99.9MB 까지 갔다가 레이어를 정리해 되돌렸다.
- UI: `build/ui/*.png` 로 메모 두 종·빠른 입력·흐름을 라이트/다크로 확인.
- **육안 확인 대기** — 실제 화면에서의 인상, 그리고 팝업이 이제 제자리에 뜨는지.