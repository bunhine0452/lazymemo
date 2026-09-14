---
schema_version: 1
type: chore
slug: "ios-store-screenshots"
status: done
difficulty: low
created_at: "2026-09-13T11:59:23+09:00"
session_id: "20260913-006"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/scripts/uitest.sh"
    op: update
related: []
tags:
  - "ios"
  - "app-store"
  - "screenshots"
  - "mcp-tool"
---
[x] 아이폰 스토어 스크린샷 5장 — 6.9″ 시뮬레이터, 키보드 안내 덮개 제거

`LAZYMEMO_SIM="iPhone 17 Pro Max" ./ios/scripts/uitest.sh --shots` → 1320×2868 (App Store 6.9″ 규격) 5장을 `dist/store/ios/{pen,list,editor,datesheet,calendar}.png` 에 모았다 (`dist/` 는 gitignore).

첫 번째 찍은 것은 펜 화면 키보드 위에 시뮬레이터의 「밀어서 입력」 안내(Continue)가 덮여 있었다. `uitest.sh` 가 시험 전에 `defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true` 를 시뮬레이터에 적어 두게 했다 — fastlane snapshot 이 쓰는 같은 열쇠.

남는 것: 시뮬레이터엔 iCloud 가 없어 「이 기기에만 · iCloud 꺼짐」 부제가 찍힌다. 정직한 문장이라 그대로 두되, 실기기에서 다시 찍으면 「iCloud」 로 바뀐다.

## 검증

5장 전부 1320×2868, 키보드 덮개 없음을 눈으로 확인.