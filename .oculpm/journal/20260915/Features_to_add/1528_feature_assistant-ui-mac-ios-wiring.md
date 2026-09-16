---
schema_version: 1
type: feature
slug: "assistant-ui-mac-ios-wiring"
status: done
difficulty: high
created_at: "2026-09-15T15:28:01+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/AssistantView.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/ModelPanel.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/ActionWords.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/Words.swift"
    op: create
  - path: "Sources/LazyMemoAssistantUI/Resources/en.lproj/Localizable.strings"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Assistant/AssistantWindow.swift"
    op: create
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo/AppModel.swift"
    op: update
  - path: "ios/LazyMemo/AssistantEnvironment.swift"
    op: create
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "docs/STORE_LISTING.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260915/Features_to_add/1518_feature_model-download-store-litert-provider.md"
    kind: "followup"
tags:
  - "jarvis"
  - "assistant"
  - "ui"
  - "ios"
  - "mac"
  - "privacy"
  - "mcp-tool"
---
[x] 비서 화면 — 맥·폰 공용 LazyMemoAssistantUI(모델 받기·묻기·시키기·오늘·적용/되돌리기), 맥 메뉴 「메모에게 묻기…」·App Store 판 다듬기 로컬화, 폰 ✦ 버튼·「이 메모에게 시키기」, 개인정보·스토어·README 문구

## 추가 기능

**`LazyMemoAssistantUI`** (Core·Assistant·LocalLiteRT 의존, 맥·폰 공용 SwiftUI)
- `AssistantModel`(@MainActor @Observable): ModelStore·LiteRTProvider·Coordinator·ActionExecutor 를 한 손에. 상태 = availability·다운로드 진행/오류·phase(idle/thinking/done/failed)·answer·evidence·proposal·receipt·briefItems. `ask`/`command`/`brief`/`tidy(memoID)`/`apply(confirmedTrash:)`/`undo`/`cancel`/`suspend`. 브리핑 캐시는 로컬 날짜+시간대+근거 지문+템플릿 판을 열쇠로 UserDefaults 에(기기별, 동기화 안 함).
- `ModelPanel`: 없으면 이름·크기(2.59GB)·「기기 안에서 처리, 인터넷은 받을 때만, Wi-Fi 권장」·받기; 받는 중이면 진행·취소; 있으면 지우기(확인).
- `AssistantView`: 묻기/시키기 세그먼트, 입력, 「오늘」 버튼. 답 + 누를 수 있는 근거 칩(→ 메모 열기), 브리핑 ≤3 (「지금 띠의 차례는 그대로」 각주), 제안은 `ActionWords` 가 말로(정확한 시각 표시) → 「적용/아니요」, 휴지통은 confirmationDialog, 적용 뒤 「되돌리기·메모 열기」.

**맥** — `AssistantWindow`(NSHostingView), 메뉴 「메모에게 묻기…」(설정 위). AppDelegate 가 `AssistantModel(service: store.service, support:)` 를 만들고, `claude` 가 없으면(App Store 판) `NoteModel.LocalTidy` 를 창 관리자에 넣어 종이의 ✧ 다듬기가 이 기기의 모델로 간다(`#local-tidy`). `MemoStore.service` 를 public 으로.

**폰** — `AppModel.Session.assistant`, `background()` 에서 `suspend()`(생성 취소·모델 해제, 명세 §6). 목록 툴바 ✦ 「메모에게 묻기」 → 시트; 편집기 ✦ 「이 메모에게 시키기」 → `selected` 로 시트(EnvironmentKey 로 전달). pbxproj 에 `LazyMemoAssistantUI` 링크, `EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64`(LiteRT 시뮬레이터 슬라이스가 arm64 뿐).

**문구** — PRIVACY 표(ko/en)에 「이 기기의 비서」 행: 메모는 안 나감, 모델 파일만 「받기」 때 HF 에서, iCloud·백업 밖, 앱 안에서 삭제. STORE_LISTING 심사 메모 문단, README 「이 기기의 비서 (선택, 미리보기)」 절.

## 검증

- `swift build` 전체 통과, `scripts/test.sh` 802/119 통과.
- iOS 시뮬레이터 빌드 `BUILD SUCCEEDED`(generic 대상, x86_64 제외 뒤).
- 맥 헤드리스 메뉴(`LAZYMEMO_MENU=1`, 임시 vault)에 「메모에게 묻기…」 표시 확인.
- 실모델 배관은 `RealModelTests` 로 확인(앞 일지). **실기기·GUI 손검증은 TestFlight 에서 사용자가** — 특히 폰 다운로드 이어받기·백그라운드 해제·M1 메모리.
- 미완: 브리핑은 아침 자동 생성 없이 「오늘」 버튼으로만(명세 §6 「앱 전경에서 첫 유효 브리핑」의 자동 트리거는 후속), 맥 종이에서 「이 메모에게 시키기」 진입점 없음(창에서 묻기만).