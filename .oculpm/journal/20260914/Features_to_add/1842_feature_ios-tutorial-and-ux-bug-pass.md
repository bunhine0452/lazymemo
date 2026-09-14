---
schema_version: 1
type: feature
slug: "ios-tutorial-and-ux-bug-pass"
status: done
difficulty: medium
created_at: "2026-09-14T18:42:06+09:00"
session_id: "20260914-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/TutorialView.swift"
    op: create
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/HomeView.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/ShotTests.swift"
    op: update
related:
  - ref: "20260913/Features_to_add/1048_feature_mobile-card-design-upgrade.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0400_feature_phone-ui-second-edition.md"
    kind: "followup"
tags:
  - "ios"
  - "swiftui"
  - "tutorial"
  - "ux"
  - "bug"
  - "mcp-tool"
---
[x] 폰 첫 실행 안내 + 조작 결함 수정

## 추가 기능
- **첫 실행 안내** `TutorialView` — 네 장(펜·칩 읽기·밀기/길게/흔들기·달력). 종이·포레스트 테마, 「건너뛰기」와 「다음/시작하기」. 본 것은 이 기기의 `UserDefaults`(`tutorialSeen`)에만 — iCloud 설정에 두면 맥이 폰의 안내를 끈다. More 메뉴 「사용법」으로 다시 본다.
- 안내가 떠 있는 동안 펜이 켤 때의 포커스를 미룬다 (`PenModel.holdsLaunchFocus` / `releaseLaunchFocus`) — 시트 위로 키보드가 오르면 못 읽는다. 닫히면 그때 올라온다.
- 남기면 손끝에 한 번 (`sensoryFeedback(.success)`).
- 폴더 지우기 전에 확인 대화 (이름표가 떨어지는 일은 되돌릴 수 없다).
- 편집의 폴더 꼬리가 **있는 폴더를 메뉴로** 보여 준다 — 전에는 이름을 새로 쳐야만 했다. `listedFolders` 로 설정의 차례도 받는다.

## 동작 흐름
고친 결함 넷:
1. **펜 칩을 끄면 칩이 사라졌다.** `dateChip`/`placeChip` 이 토글을 거친 `reading` 에서 나와서, 끄는 순간 값이 `nil` 이 됐다 — 설계(§3)의 「빈 테두리로 남는다」에 닿을 길이 없었다. `readAll`(토글 전)로 칩을 그리고 `reading` 은 남길 것만. 글을 다 지우면 토글도 되돌린다.
2. **날짜 시트가 옛 메모를 봤다.** `.sheet(item: Memo)` 가 누를 때의 값을 잡아 두어 격자 밑줄·시각 칩이 첫 누름 뒤 따라오지 않았다. `ULID` 를 들고 `store.memo(id)` 로 살아 있는 메모를 본다 (목록·달력 둘 다).
3. **달력의 「다른 날로」 시트에서 고른 시각이 버려졌다.** `onChange` 가 날만 받아 `move(to: day)` 로 옮기니 `Schedule.moved` 가 옛 시각을 지켰다. 시트가 준 `Schedule` 을 통째로 쓰는 `reschedule` 로.
4. **편집의 「폴더」 알림에서 빈 이름으로 「넣기」를 누르면 있던 폴더에서 빠졌다.** `normalized` 의 `nil` 을 그대로 `folder: .some(nil)` 로 보냈다. 빈 이름은 아무것도 하지 않는다.
덤: 편집 중 앱이 뒤로 물러나면 즉시 내린다 (전에는 600ms 안에 죽으면 마지막 글자가 사라졌다).

## 검증
`./ios/scripts/uitest.sh` 8/8 통과 — 새 시험 둘: `testFirstLaunchShowsTutorialThenThePen`(안내 위 키보드 없음 → 닫히면 키보드 → More 로 재진입), `testDateChipStaysWhenTurnedOff`(끈 칩이 남고 값 「꺼짐」, 단추 「메모 남기기」, 다시 켜짐). 시뮬레이터 스크린샷으로 안내 첫 장을 눈으로 확인. 시험은 `-tutorialSeen YES/NO` 실행 인자로 안내를 정한다.

## 메모
날짜 시트 결함 2는 시트 안에서 두 번 이상 누르는 순간 드러나므로 실기기 손검증에서 「날짜 시트에서 시각 칩을 고른 뒤 다른 시각」을 한 번 밟아 볼 것.