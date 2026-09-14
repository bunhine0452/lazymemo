---
schema_version: 1
type: chore
slug: "mac-store-screenshots-and-checklist-fix"
status: done
difficulty: medium
created_at: "2026-09-14T17:15:59+09:00"
session_id: "20260914-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/store-shots.sh"
    op: create
  - path: "Sources/LazyMemoUI/Demo/DemoTour.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoTextEditor.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/MemoNSTextView.swift"
    op: update
related:
  - ref: "20260913/Chores/1159_chore_ios-store-screenshots.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md"
    kind: "followup"
tags:
  - "mac"
  - "app-store"
  - "screenshots"
  - "demo"
  - "markdown"
  - "mcp-tool"
---
[x] 맥 스토어 스크린샷 5장 — `./scripts/store-shots.sh` → `dist/store/mac/{capture,desk,drawer,folder,desk-dark}.png`, 전부 2880×1800

## 한 것

`render-ui.sh` 의 산출물은 뷰 조각(빛·어둠 나란히, ✧ 버튼 포함)이라 스토어에 그대로 못 낸다. 소개 영상의 무대(`DemoTour`)를 그대로 빌려 **정지 장면**을 찍는 길을 냈다.

- `DemoTour.shots(into:)` — `run()` 과 같은 무대에서 장면을 세우고 `screencapture -R` 로 무대만 잘라 낸다. 무대가 1440×900pt 라 레티나에서 곧 2880×1800. 장면: 빠른 입력이 「내일 오후 3시」를 읽어 날짜 칩을 단 순간 → 종이 셋 + 달력(9/15 치과 예약이 선택) → 서랍 → 폴더 「집」 → 같은 책상의 어두운 모양(`NSApp.appearance = .darkAqua`, 시스템 설정은 안 건드린다). 달력에 보일 일정 넷을 오늘·이번 주로 심는다.
- 세 번째 종이는 빠른 입력으로 적지 않고 자리를 정해 세운다 — 새 종이의 계단 꼭대기가 `seed` 의 첫 종이와 정확히 겹쳐 가렸다 (계단은 origin 이 같을 때만 비켜 가는데 seed 의 종이는 268 폭이라 origin 이 다르다).
- `AppDelegate` 가 `LAZYMEMO_SHOTS=<dir>` 이면 `run()` 대신 `shots` 를 돈다.
- `scripts/store-shots.sh` — 스크래치 vault 의 `settings.json` 에 `usesClaude:false`(스토어 판엔 ✧ 이 없다)·`showsSystemEvents:false`(달력 권한을 묻지 않고 사용자 일정을 안 섞는다)·`greeted:true` 를 적고 띄운다.

**찍다가 드러난 결함 하나.** 첫 장에서 초록 종이의 마지막 줄만 `- [ ] 식빵` 원문이었다 — `site/media/demo-poster.jpg` 에도 그대로 찍혀 있었다. `MemoTextEditor.Coordinator.restyle` 이 `selectedRange()` 의 줄을 무조건 커서 줄로 쳐서, 첫 응답자가 아닌 종이의 기본 선택(글 끝)까지 「편집 중인 줄」이 됐다. 첫 응답자일 때만 커서 줄을 두고, `MemoNSTextView` 가 `becomeFirstResponder`/`resignFirstResponder` 에서 `onFocusChange(self, focused)` 로 알려 다시 꾸민다. 물러나는 중에는 `window.firstResponder` 가 아직 이 뷰라 값을 직접 넘긴다.

## 검증

- `./scripts/test.sh` 725개 통과.
- 무대를 두 번 돌려 5장 전부 2880×1800, 눈으로 확인 — 날짜 칩·달력 점(14일 둘·15·17·20)·서랍 7장·폴더 집 3장·어두운 모양. 두 번째 돌림에서 「☐ 식빵」이 상자로 그려진다.
- 사람 눈 확인이 남은 것: 실제로 종이를 클릭해 편집에 들어갈 때 커서 줄 기호가 되살아나고, esc 로 물러날 때 도로 감춰지는지 (첫 응답자 오감을 코드로 따라갔지만 손으로는 안 눌러 봤다).

## 메모

- 스토어 판 진짜 서명본은 아직 못 만든다 — `xcodebuild archive` 가 `No Accounts`. Xcode › Settings › Accounts 에 로그인해야 iOS·맥 둘 다 TestFlight 로 간다.
- `_template.md.bak` 은 플러그인 백업이라 커밋하지 않았다.