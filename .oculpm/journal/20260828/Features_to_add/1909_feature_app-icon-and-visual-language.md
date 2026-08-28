---
schema_version: 1
type: feature
slug: "app-icon-and-visual-language"
status: done
difficulty: high
created_at: "2026-08-28T19:09:54+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/make-icon.swift"
    op: create
  - path: "scripts/make-icon.sh"
    op: create
  - path: "scripts/render-ui.sh"
    op: create
  - path: "Resources/AppIcon.icns"
    op: create
  - path: "Sources/LazyMemoUI/Resources/MenuBarIcon.png"
    op: create
  - path: "Sources/LazyMemoUI/Views/Theme.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "Package.swift"
    op: update
  - path: "scripts/build-app.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "icon"
  - "coregraphics"
  - "design-system"
  - "swiftui"
  - "imagerenderer"
  - "performance"
  - "dark-mode"
  - "visual-design"
  - "mcp-tool"
---
[x] 아이콘과 시각 언어 — 코드로 그린 아이콘, 유리를 걷어낸 UI, 레이어가 곧 메모리

사용자 요청으로 아이콘을 새로 만들고 UI 전체를 하나의 언어로 다시 그렸다. 설계문서에 §14(시각 언어)를 추가했다.

## 추가 기능

`scripts/make-icon.swift`(CoreGraphics 아이콘 생성기) · `Theme.swift`(디자인 토큰) · `MemoTextArea`(편집 영역) · `PreviewRenderer`(실제 뷰를 PNG 로) · 세 뷰 재작성.

## 아이콘 — 세 번 버리고 얻은 것

**최종안: 쓰다 만 메모.** 종이 위 첫 줄은 반듯하고, 둘째 줄은 끝으로 갈수록 가늘어지며 흘러내린다. 게으름을 **그릇의 모양이 아니라 글씨의 태도**로 말한다.

렌더해서 눈으로 보고 세 번 버렸다.

- **굵은 `Z` 획**(잠·게으름) — 알파벳으로만 읽힌다. 폰트 회사 로고 같고 "메모"가 사라진다.
- **아랫변이 처진 종이** — 둥근 사각형의 아래가 처지면 사람은 그것을 **말풍선**으로 읽는다.
- **굵기가 일정한 흘림선** — 갈고리(✓)나 물결(~)이 된다.

그래서 흘림선은 stroke 가 아니라 **직접 만든 가변 굵기 도형**이다. 3차 베지에 중심선을 따라가며 법선 방향으로 폭을 보간해 채울 도형을 만든다. `CGContext` 의 stroke 는 굵기가 일정해서 이 표현을 못 한다.

판 모서리는 초타원(n=5)이다. `CGPath(roundedRect:)` 의 원형 모서리는 시스템 아이콘 옆에서 미묘하게 어색하다.

**디자인 파일이 아니라 코드가 원본이다.** 저장소에 출처를 알 수 없는 바이너리를 넣지 않고, 색·비례 변경이 diff 로 남는다.

## UI — 유리를 걷어냈다

원칙 넷을 `Theme.swift` 에 고정했다: 조작 버튼은 hover 때만 · 색은 신원이지 장식이 아니다 · 글자 넷/여백 다섯 · 0.18초 이내의 조용한 움직임.

**가장 큰 결정: 읽는 면에서 유리를 뺐다.** 처음엔 메모와 캘린더에 `glassEffect` 를 씌웠는데, 렌더해 보니 본문이 두 모드 모두 흐릿했다. 이유가 둘이다 — 반투명한 면 위의 글은 흐려지고(메모는 오래 읽는 물건이다), 바탕화면 사진이 무엇이든 글이 읽혀야 하는데 유리는 그 통제권을 배경에 넘긴다. 앱 아이콘이 종이인 것과도 같은 이야기다. 유리가 옳은 곳은 잠깐 떴다 사라지는 빠른 입력 팝오버 하나다.

색은 처음에 위 가장자리 3pt 띠로 두었다가 **테두리로 옮겼다.** 띠가 카드의 둥근 모서리를 따라가지 못해 밖으로 삐져나왔고, 맞추려면 카드 전체를 `clipShape` 해야 했다. 창이 겹칠 때 실제로 보이는 것은 가장자리이므로 테두리가 같은 일을 더 잘한다.

## 알아낸 것 1 — 레이어 수가 곧 메모리 예산이다

재디자인 직후 메모 10장 RSS 가 88.8MB → **99.9MB** 로 뛰었다. 예산 100MB 를 0.1MB 차이로 통과한 것은 운이지 여유가 아니다.

원인은 창마다 늘어난 레이어 둘이었다.

- 종이색과 세척색을 도형 두 개로 겹침 → **색을 미리 섞어 도형 하나로** (`NSColor.blended`)
- 색 띠를 모서리에 맞추려는 카드 전체 `clipShape` → **띠를 없애고 색을 테두리로**

고치니 **87.7MB**, 재디자인 전보다 나아졌다. 시각 결정이 곧 메모리 결정이다.

## 알아낸 것 2 — 동적 NSColor 는 대입만으로 해석되지 않는다

다크 모드에서 종이가 흰색으로 나왔다. `performAsCurrentDrawingAppearance` 블록 안에서 `.textBackgroundColor` 를 **변수에 대입**했는데, 그것은 여전히 동적 색이라 나중에 라이트로 해석된다. 블록 안에서 `usingColorSpace(.sRGB)` 로 **그 자리에서 변환**해야 한다.

## 알아낸 것 3 — ImageRenderer 는 NSViewRepresentable 을 못 그린다

화면 기록 권한이 없어 UI 를 볼 방법이 없었다. `ImageRenderer` 로 실제 뷰를 그리게 했더니 편집기 자리에 빨간 금지 표시가 찍혔다 — AppKit 표현체는 화면 밖 렌더가 안 된다. `MemoTextArea` 가 환경값 `rendersStatically` 를 보고 같은 글꼴·여백의 `Text` 로 대체한다.

라이트 모드 뷰를 어두운 바탕에 합성했더니 명암이 뒤집혀 보여 한 번 헛짚었다. 지금은 각 외관을 제 배경 위에 나란히 낸다.

## 알아낸 것 4 — 비동기 Task 안의 NSApp.terminate 는 멈춘다

렌더 모드가 종료되지 않아 2분 타임아웃에 걸렸다. `NSApp.terminate(nil)` 을 부른 뒤 `applicationShouldTerminate` 가 **아예 호출되지 않는다.**

⌘Q 도 같은 경로라 제품 버그를 의심해 따로 확인했다 — 앱 번들에 종료 Apple Event 를 보내니 **정상 종료되고 `layout.json` 도 기록됐다.** 즉 이것은 비동기 Task 안에서 부를 때만 생기는 문제이고, 저장할 것이 없는 렌더·측정 모드는 `exit(0)` 으로 바꿨다.

## 검증

- 테스트 76개 통과. `verify-notes` / `verify-restore` / `verify-mcp` 전부 통과.
- 성능 재측정: **RSS 87.7MB, idle CPU 0.0%**. 빠른 입력 지연 중앙값 **7.6ms**.
- 아이콘: `build/icon/comparison.png` 로 256~16px 과 메뉴바 템플릿(라이트/다크)을 확인.
- UI: `build/ui/*.png` 로 메모 두 종·빠른 입력·캘린더를 라이트/다크로 확인.
- ⌘Q 경로: 메모 창 3개가 뜬 상태에서 종료 Apple Event → 정상 종료 + `layout.json` 기록 확인.
- **육안 확인은 여전히 대기** — 실제 화면에서의 인상과 메뉴바 아이콘 모양.