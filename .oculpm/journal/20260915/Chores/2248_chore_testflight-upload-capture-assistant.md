---
schema_version: 1
type: chore
slug: "testflight-upload-capture-assistant"
status: done
difficulty: low
created_at: "2026-09-15T22:48:26+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
  - ref: "20260915/Chores/2130_chore_testflight-upload-assistant-quality.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] b3cc4e7 을 아이폰·맥 TestFlight 에 올렸다

사용자 지시(「테스트플라이트에도 올려줘」)로 `ios/scripts/archive.sh` → `archive.sh mac`. 워킹트리에 남은 다른 세션의 미커밋 변경(l10n·플래너·MenuBarController 의 스토어 판 가드)은 아카이브에 포함된다.

## 검증
- iOS: `** ARCHIVE SUCCEEDED **` → `Upload succeeded` (22:46). 맥: `** ARCHIVE SUCCEEDED **` → `Upload succeeded` (22:48).
- Xcode 27 의 CoreSimulator 구판 경고는 전과 같고 업로드에 영향 없음.

## 실기기에서 볼 것 (사용자)
- 맥: ⌥⌘N 상자에 머리 줄이 없고 × 만 있는지. 「9월 30일에 @홍대입구 친구랑 밥 먹기로 했어」 ⌘↵ → 시각 되묻기 → 「12시야」 → 달력에 남는지. 「치과 언제였지?」 → 답+근거. 목록 줄을 ↓ 로 고르고 「금요일 10시에 다시 알려줘」 → 결과 줄+되돌리기. 종이 우클릭 「이 메모에게 시키기…」가 상자를 여는지. 메뉴에 「메모에게 묻기…」가 없는지.
- 폰: 기존 ✦ 시트 그대로(펜 융합은 후속). 모델 없이 시키기가 되는지.