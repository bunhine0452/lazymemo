---
schema_version: 1
type: chore
slug: "testflight-upload-recall-photos"
status: done
difficulty: low
created_at: "2026-09-15T02:17:37+09:00"
session_id: "mcp-20260915-021737"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
  - ref: "20260915/Bugs/0148_bug_phone-shows-mac-photos.md"
    kind: "followup"
  - ref: "20260914/Chores/2119_chore_testflight-upload-place-cards.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] c6ab541 을 아이폰·맥 TestFlight 에 올렸다 — 다시 보기·알림·「지금」 띠·폰 사진 판

워킹트리에 미커밋 소스 변경이 없어(다른 세션의 planner 두 파일만) 본 트리에서 `ios/scripts/archive.sh` → `ios/scripts/archive.sh mac` 을 차례로 돌렸다. 판 문자열은 ASC 버전 페이지와 맞춰 둔 그대로(iOS `0.1.0`, macOS `0.4.0`) — 빌드 번호는 ASC 가 올린다. 이 아카이브가 App Store 용 `LazyMemo-macOS` Xcode 타깃의 첫 빌드 확인이기도 하다 (`LazyMemoReminders` 의존 포함).

## 검증
- iOS: `** ARCHIVE SUCCEEDED **`, iCloud·App Group entitlement ✓, `Upload succeeded`.
- 맥: `** ARCHIVE SUCCEEDED **`, iCloud ✓ · App Sandbox ✓ · LazyMemoAppStoreBuild ✓, `Upload succeeded`.
- 실기기에서 볼 것: More → 알림 켜기(권한 창 한 번) → 메모 종 → 「한 시간 뒤」 → 잠금 화면 알림 → 눌러서 메모 열림 · 맥 종이 우클릭 「다시 보기…」와 설정 「알림…」 · 맥에서 붙인 사진이 폰 종이 머리에 뜨는지(iCloud 자리표 내려받기).