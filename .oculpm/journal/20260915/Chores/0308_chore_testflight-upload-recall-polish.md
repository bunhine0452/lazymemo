---
schema_version: 1
type: chore
slug: "testflight-upload-recall-polish"
status: done
difficulty: verylow
created_at: "2026-09-15T03:08:56+09:00"
session_id: "20260915-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Features_to_add/0300_feature_recall-polish-and-intro-videos.md"
    kind: "followup"
  - ref: "20260915/Chores/0217_chore_testflight-upload-recall-photos.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] ab923bc 를 아이폰·맥 TestFlight 에 올렸다 — 「지금」 차례·「봤어요」·사진 줄·접힌 안내 판

사용자 요청으로 내 변경만 명시 경로로 stage 해 커밋(`ab923bc`)한 뒤, 빌드 캐시를 비운 상태에서 `ios/scripts/archive.sh` → `ios/scripts/archive.sh mac` 을 돌렸다. 다른 세션의 planner 두 파일과 미추적 `_template.md.bak`·`lazymemo-on-device-llm/` 은 손대지 않았다.

## 검증
- iOS: `** ARCHIVE SUCCEEDED **`, iCloud·App Group entitlement ✓, `Upload succeeded` (03:06).
- 맥: `** ARCHIVE SUCCEEDED **`, iCloud ✓ · App Sandbox ✓ · LazyMemoAppStoreBuild ✓, `Upload succeeded` (03:08).
- 실기기에서 볼 것: 「지금」 카드의 「봤어요」 → 「나머지」로 돌아가는지 · 알림을 켠 뒤 다시 보기 시트의 안내가 접히는지 · 사진 메모 줄의 「사진 1장」 · 맥에서 같은 날 「한 시간 뒤」로 미룬 종이가 그 시각에 다시 나오는지.