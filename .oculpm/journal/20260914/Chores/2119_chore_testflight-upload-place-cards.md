---
schema_version: 1
type: chore
slug: "testflight-upload-place-cards"
status: done
difficulty: verylow
created_at: "2026-09-14T21:19:37+09:00"
session_id: "20260914-005"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260914/Features_to_add/2115_feature_ios-place-cards-map-app-handoff.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mcp-tool"
---
[x] 88e4026 을 아이폰 TestFlight 에 올렸다

다른 세션이 수십 파일에 걸쳐 문자열 분리(localization) 작업을 미커밋으로 진행 중이라, 공유 트리에서 아카이브하면 그 미완 변경이 빌드에 섞인다. `git worktree add --detach <스크래치패드> HEAD` 로 HEAD 만 뽑아 거기서 `ios/scripts/archive.sh` 를 돌렸다. 맥 판은 이 커밋에 동작 변화가 없어 올리지 않았다.

## 검증
- `** ARCHIVE SUCCEEDED **`, iCloud·App Group entitlement 확인, `Upload succeeded`.
- 폰에서 볼 것: 장소 붙은 메모의 자리 카드, 자리 둘인 메모의 쓸어 넘기기, 카카오맵·네이버 지도 단추가 실제 앱을 여는지(시뮬레이터에선 못 봤다).