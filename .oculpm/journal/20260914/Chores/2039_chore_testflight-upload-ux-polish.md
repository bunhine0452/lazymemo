---
schema_version: 1
type: chore
slug: "testflight-upload-ux-polish"
status: done
difficulty: verylow
created_at: "2026-09-14T20:39:46+09:00"
session_id: "20260914-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260914/Bugs/1934_bug_ux-polish-search-empty-calendar-marks.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "mcp-tool"
---
[x] c130fe1 을 아이폰·맥 TestFlight 에 올렸다

「앱 업데이트해줘」 — /Applications 의 LazyMemo.app 은 TestFlight 가 깐 샌드박스 판(영수증·root 소유)이라 ad-hoc 빌드로 덮지 않고, 같은 길(`ios/scripts/archive.sh`, `archive.sh mac`)로 새 빌드를 올렸다. 빌드 번호는 App Store Connect 가 매긴다(manageAppVersionAndBuildNumber). 판 번호는 그대로 iOS 0.1.0 · macOS 0.4.0.

## 검증
- 두 업로드 모두 `Upload succeeded` / `** EXPORT SUCCEEDED **`. 맥 아카이브는 iCloud entitlement·App Sandbox·LazyMemoAppStoreBuild 셋 확인.
- 처리가 끝나면 TestFlight 앱에서 새 빌드로 갈아 설치해 손검증 목록(`docs/APP_STORE_READINESS.md`)을 이어 간다 — 이 판에서 새로 볼 것: 폰 달력의 점·옅은 원, 날짜 시트가 크게 열리는 것, 찾기 중 각주 한 줄, 맥 서랍 줄의 시각 중복 없음.