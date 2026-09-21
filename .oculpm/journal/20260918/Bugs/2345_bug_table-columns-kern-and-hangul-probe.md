---
schema_version: 1
type: bug
slug: "table-columns-kern-and-hangul-probe"
status: done
difficulty: medium
created_at: "2026-09-18T23:45:13+09:00"
session_id: "20260918-004"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MarkdownStyler.swift"
    op: update
  - path: "Tests/LazyMemoUITests/TableAlignmentTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/KoreanTypingVisibilityTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MarkdownScannerFuzzTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MarkdownScannerTests.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
related:
  - ref: "20260918/Bugs/2207_bug_app-look-long-memo-top-tables-manifest.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1921_feature_long-memo-readability.md"
    kind: "followup"
tags:
  - "mac"
  - "editor"
  - "markdown"
  - "mcp-tool"
---
[x] 표의 열을 kern 으로 맞췄다 — 글자는 그대로; 「한글이 가끔 안 보인다」는 회귀 시험 넷을 두고도 재현 못 함

사용자(맥): 「표 마크다운 렌더링이 제대로 안 되며, 메모의 한글들이 가끔 보이지 않는 버그가 있는데 확인해봐」. (esc 로 안 사라지는 웹 결과는 병렬 에이전트가 — 별도 일지.)

## 발생 원인

- **표**: 0.9.1 은 세로선을 마커로 감춰 「구분  금액 / 시급  10,320원」처럼 열이 흐트러졌다. 파일이 정본이라(§15.1) 탭으로 글자를 바꿀 수 없고, TextKit 1 에서 한 문단을 칸으로 나누는 길(`NSTextTable`)도 없다.
- **한글**: 감추기는 글꼴을 0.01pt 로 줄이는 것이라, 감출 것이 아닌 글자에 그 글꼴이 남으면 사라진다. 0.9.0 의 「고친 줄만 다시 깔기」와 조합(marked text)의 상호작용을 의심했다.

## 해결 방법

- 열마다 가장 넓은 칸을 꾸민 뒤의 실제 글꼴로 재어 **칸의 마지막 글자에 `.kern`** 을 얹는다 — 글자·길이·커서 자리는 그대로, 다음 세로선이 같은 x 에 선다. 세로선은 새 `.tablePipe` 로 옅게만(감추면 커서 든 줄만 세로선 너비만큼 밀려 6.9pt 어긋났다 — 시험이 잡았다). `| --- |` 줄은 문단 높이 6pt 로 얇은 틈. 한 줄을 고쳐도 표 덩이 전체를 다시 깐다(`tableBlock`). 맞춘 표가 종이 폭을 넘으면 접히지 않게 그대로 둔다.
- 한글: 사람이 치는 차례를 그대로 흉내 내는 시험을 두었다 — 굵게 마커 뒤·제목 뒤 Return·사진 참조 뒤·체크/링크 줄을 오가며·조합 중 되밀기·긴 글 붙인 뒤 무작위 40번, 블록 구조 12종 × (포커스·커서 줄마다·포커스 없음·되밀린 뒤), 그리고 스캐너 무작위 2000줄에서 `.syntax` 에 한글이 드는지. **전부 초록** — 편집기의 감추기 경로에서는 재현되지 않는다. 사진 alt 글(`![설명](…)`)이 통째로 감춰지는 것은 규칙대로다.

## 검증

- 맥 전체 1057 초록(새 시험 12), 폰 스모크 23/23. 표 메모를 띄워 창 캡처로 확인 — 열이 맞고 세로선 옅고 구분 줄이 틈이 됐다; 세 열짜리는 260pt 종이에서 접히던 것이 폭 넘김 규칙으로 그대로 선다.

## 메모

- 한글 건은 사용자에게 되물을 것: 어느 화면(바탕화면 종이·빠른 입력·서랍·폰), 어떤 메모(사진·링크·가는 길 절이 있는지), 다시 보이게 하는 손짓(클릭·스크롤·다시 열기)이 무엇인지. 후보로 남은 것: 나이 바램(최저 0.72 라 안 보일 정도는 아님), 「## 가는 길」 절 바로 아래 `- ` 줄이 절로 먹히는 것, 테마 색.