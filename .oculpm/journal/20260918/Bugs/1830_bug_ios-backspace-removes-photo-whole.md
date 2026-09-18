---
schema_version: 1
type: bug
slug: "ios-backspace-removes-photo-whole"
status: done
difficulty: low
created_at: "2026-09-18T18:30:50+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
related:
  - ref: "20260918/Bugs/1824_bug_mac-photo-reference-always-hidden.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/2140_feature_ios-hide-machine-lines-photo-remove.md"
    kind: "followup"
tags:
  - "ios"
  - "editor"
  - "photo"
  - "mcp-tool"
---
[x] 폰에서 ⌫ 가 감춘 사진 참조의 `)` 를 떼면 경로가 날것으로 드러났다 — 참조를 한 덩이로 뗀다

사용자: 「폰도 같이 고쳐」 (맥의 같은 결함 뒤).

## 발생 원인

`PaperTextView` 는 참조를 감추고 커서를 밀어내지만(17일), 글 끝의 커서는 참조 **바로 뒤**다 — 파일은 끝 줄바꿈 없이 읽히므로(`MemoFile.decode`) 참조가 마지막 줄이면 늘 그렇다. 거기서 ⌫ 는 `)` 하나를 떼고, `)` 가 빠진 참조는 스캐너가 더는 사진으로 읽지 않아 감춤이 풀리며 40자 경로가 드러났다.

## 해결 방법

`PaperTextView.Coordinator` 에 `textView(_:shouldChangeTextIn:replacementText:)` — 지우기(빈 대체문)가 참조에 걸치면 `MachineLines.deletion` 으로 참조 전체를 잡고(`selectedRange`) `deleteBackward()` 를 다시 부른 뒤 `false`. 안쪽 호출은 이미 넓힌 구간이라 그대로 지나가므로 되돌리기·`textViewDidChange`(꾸밈·모델 반영) 흐름이 표준 그대로다. 조합 중(`markedTextRange`)엔 손대지 않는다.

## 검증

- 시뮬레이터(iPhone 17) XCUITest `testBackspaceRemovesAPhotoWhole`: 사진 메모 열고 글 끝 누른 뒤 ⌫ 한 번 → 사진 카드 사라짐 → 「덧」 치면 그 줄에 보임 → 파일이 `명함 사진\n덧\n`, `attachments/` 없음. 스크린샷 `/tmp/lazymemo-photo-backspace.png` 로 날것 없음 확인.
- 이웃 시험 `testMachineLinesAreHiddenAndTypingLandsBeforeTheRoute`·`testRemovingAPhotoFromItsCard` 도 통과.

## 메모

- 처음 시험은 ⌫ 둘(빈 줄→사진)로 적었다가 틀렸다 — 폰은 파일을 끝 줄바꿈 없이 읽어 첫 ⌫ 가 곧 사진이다. 맥 시험은 초기 글에 줄바꿈을 명시해서 둘이었다.