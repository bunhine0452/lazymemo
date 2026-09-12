---
schema_version: 1
type: feature
slug: "paper-welcome-and-capture"
status: done
created_at: "2026-09-12T15:18:50+09:00"
session_id: "20260912-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/WelcomeWindow.swift"
    op: create
  - path: "Sources/LazyMemoUI/WelcomeNote.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureChipLayoutTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureBrowseTests.swift"
    op: update
related:
  - ref: "20260831/Features_to_add/1744_feature_lazy-recall-filters-and-recency.md"
    kind: "followup"
tags:
  - "mcp-tool"
---
[x] 종이 질감의 시작 화면과 클릭으로 쓰는 빠른 입력

## 추가 기능
첫 실행에 시작 화면을 표시하고 메뉴에서 다시 열 수 있게 했다. 메모·달력·서랍으로 바로 이동하며 기존 사용자의 메모는 유지한다. 빠른 입력에는 명시적 확정 버튼, 사진·링크·할 일 검색 바로가기, 최근/검색 결과 헤더와 개수, 닫기 버튼을 넣었다. 기존 종이 재질과 키보드 선택·포인터 구분, 삭제 되돌리기를 유지한다.

## 동작 흐름
첫 사용 판별 → 안내 메모 배치 및 시작 화면 → 빠른 입력·달력·서랍 선택. 빠른 입력의 확정 버튼은 기존 onCommit 경로를 사용한다. 20장으로 펼친 결과는 300pt 스크롤 영역에 담고 키보드 선택을 따라간다. Reduce Motion을 존중하며 메모 행을 접근성 버튼으로 바꿨다.

## 검증
전체 649개 테스트 통과 및 git diff --check 통과. 실제 SwiftUI의 라이트·다크 PNG를 렌더해 시작 화면 설명 잘림과 하단 여백 수정 후 재확인했다. release 앱 3.6MB 생성 및 ad-hoc 서명 검증 통과. build/app-polish-ui에 화면, dist/LazyMemo.app에 실행 번들. 스토어 제출 빌드는 아님.