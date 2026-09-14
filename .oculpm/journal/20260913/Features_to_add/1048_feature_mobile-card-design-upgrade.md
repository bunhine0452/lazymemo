---
schema_version: 1
type: feature
slug: "mobile-card-design-upgrade"
status: done
created_at: "2026-09-13T10:48:00+09:00"
session_id: "20260913-005"
agent:
  id: "codex"
  version: "gpt-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/Theme.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
related:
  - ref: "20260913/Features_to_add/0400_feature_phone-ui-second-edition.md"
    kind: "followup"
tags:
  - "ios"
  - "design"
  - "swiftui"
  - "mcp-tool"
---
[x] 모바일 메모 디자인 업그레이드

## 추가 기능
따뜻한 종이와 포레스트 색을 유지하면서 메모 행을 둥근 카드로 정돈했다. 제목 아래 미리보기와 날짜·장소 아이콘을 두고 고정 메모는 은은한 테두리로 구분한다. 다크·대비 높임 카드 색을 지원한다.
폴더 칩에 아이콘과 선택 접근성 상태, 44pt 높이를 적용했다. 빈 목록·빈 폴더·검색 결과 없음 안내를 추가하고 지우기 터치 영역을 44pt로 넓혔다. 날짜·장소 칩은 켜짐/꺼짐을 읽어 준다.

## 동작 흐름
기존 입력·검색·편집·동기화 로직은 유지한다. 최초 캡처에서 검색 빈 화면 안내가 키보드 위 칩과 겹쳐 검색 중에는 아이콘을 빼고 여백을 줄였다. 최종 다크 캡처에서 겹침이 해소됨을 확인했다.

## 검증
- iOS 시뮬레이터 Debug 빌드 성공, 기존 SmokeTests 6개 모두 통과.
- 라이트 ShotTests 및 수정 후 다크 ShotTests 성공. 목록·입력 캡처를 직접 확인했고 build/mobile-design에 보관했다.
- git diff --check 통과. 실기기·접근성 최대 글자 크기 손검증은 하지 않았다.