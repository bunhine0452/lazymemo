---
schema_version: 1
type: bug
slug: "hangul-hidden-was-link-cards-eating-paper"
status: done
difficulty: medium
created_at: "2026-09-19T00:12:33+09:00"
session_id: "20260919-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextArea.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Digest.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/DigestTests.swift"
    op: update
related:
  - ref: "20260918/Bugs/2345_bug_table-columns-kern-and-hangul-probe.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1920_feature_mac-paper-fits-content.md"
    kind: "followup"
tags:
  - "mac"
  - "editor"
  - "paper"
  - "mcp-tool"
---
[x] 「한글이 가끔 안 보인다」의 정체 — 링크 카드 둘이 글 칸을 먹고 스크롤러는 숨어 잘린 줄이 사라진 글로 보였다

사용자가 그 메모를 보내 줬다(다이어트 정리 메모 — 표·출처 둘·퍼센트 인코딩된 긴 주소). 줄바꿈을 복원해 임시 보관함에 넣고 종이를 창 단위로 찍자 바로 보였다.

## 발생 원인

- 출처 둘 → 링크 카드 두 장(각 두 줄+그림)이 종이 아래 250pt 를 차지 → 글 칸이 짧아져 「출처」 절이 카드 위 경계에서 잘렸다. 스크롤러는 `autohidesScrollers` 라 안 보이니 사람 눈에는 «글이 사라졌다». 종이는 이미 화면의 70%(665pt)까지 자란 뒤라 더 못 컸다.
- 겹친 것 둘: 한국어 주소의 퍼센트 인코딩(`%EB%8B%A4…`)이 다섯 줄을 먹었고, 표 열 맞춤(0.9.2)의 폭이 첫 배치 전 컨테이너 size(천만 pt)로 재어져 긴 칸 하나가 다른 줄의 세로선을 수천 pt 밀어 혼자 다음 줄에 떨어뜨렸다.

## 해결 방법

- 링크가 둘 이상이면 카드를 한 줄짜리로(18pt 그림·제목 우선·호스트) — 60pt.
- `MemoTextEditor.onOverflowChange`: 클립 뷰 bounds·스크롤 뷰 frame·문서 뷰 frame 을 듣고 「보이는 칸 아래에 글이 더 있는가」를 종이에 알린다 → `NoteView` 가 바닥에 작은 ︾ 를 세운다. 알림이 AppKit 배치 도중에 와 SwiftUI 상태 갱신이 버려지던 것은 다음 턴으로 넘겨서. 페이드 대신 화살표인 이유: 종이는 색이 스미고 테마가 갈려 바탕색을 지어 덮을 수 없다.
- `Digest.sourceLine` 이 `- [제목](주소)` 를 적는다 — 종이·폰이 링크 기호를 감춰 제목 한 줄, 카드와 클릭에 주소.
- 표 폭은 텍스트 뷰의 실제 폭으로, 모르면 맞추지 않고, 폭이 정해지거나 바뀌면 표가 있는 글만 다시 깐다(`realignTablesIfWidthChanged`). 종이 폭을 넘는 표는 옅은 세로선 그대로.

## 검증

- 같은 메모를 다시 띄워 캡처: 「출처」까지 보이고, 카드 둘이 두 줄, 바닥에 ︾, 표는 세로선 혼자 떨어지는 줄 없음. 맥 전체 1057 초록, 폰 스모크 23/23.

## 메모

- 앞선 일지(2345)의 회귀 시험 12개는 감추기 경로가 아니었음을 증명한 셈 — 그대로 둔다.
- 남은 것: 정리 메모처럼 문단이 길고 표가 넓으면 종이가 폭을 안 늘린다(PaperFit 의 «한 문단이 평균 2줄 이상» 규칙이 표 줄에는 안 걸림). 다음에 볼 것.