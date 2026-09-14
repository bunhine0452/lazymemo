---
schema_version: 1
type: bug
slug: "ios-ux-pass-two-keyboard-done-date-sheet"
status: done
difficulty: medium
created_at: "2026-09-14T19:01:27+09:00"
session_id: "20260914-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "c52cca45-41ed-4eb2-9a0c-d69c0afdbc2f"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo/MemoEditorView.swift"
    op: update
  - path: "ios/LazyMemo/PaperTextView.swift"
    op: update
  - path: "ios/LazyMemo/DateSheet.swift"
    op: update
  - path: "ios/LazyMemo/CalendarView.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/TrashView.swift"
    op: update
  - path: "ios/LazyMemoShare/ShareViewController.swift"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
related:
  - ref: "20260914/Features_to_add/1842_feature_ios-tutorial-and-ux-bug-pass.md"
    kind: "followup"
tags:
  - "ios"
  - "swiftui"
  - "ux"
  - "bug"
  - "keyboard"
  - "date-sheet"
  - "mcp-tool"
---
[x] 폰 조작 결함 둘째 묶음 — 편집의 「완료」, 날짜 시트의 시각, 닫힌 채 잡힌 메모

## 발생 원인
코드를 읽으며 조작 경로를 손으로 따라간 결과 (앞 일지의 이어짐):
1. **편집에서 키보드를 내릴 길이 없었다.** 키보드가 바닥 툴바(날짜·폴더·지우기)를 덮는데, 내리는 길은 드래그뿐. `PaperTextView.onEditingChanged` 는 아무도 안 썼다.
2. **날짜 시트가 붙어 있는 시각을 말하지 않았다.** 제목은 날짜만, 15:00·10:30 같은 시각은 「09:00」「14:00」 어느 칩도 안 켜져 「시각 없음」으로 읽혔다. 9:30 은 「09:00」 칩이 켜졌다(시만 비교). 「직접…」을 펴 놓고 휠을 안 돌리면 아무 시각도 안 붙었다. 이웃 달 칸을 누르면 격자가 그 달로 안 갔다.
3. **달력의 날짜 시트 클로저가 첫 누름 전의 `memo` 를 잡고 있었다.** `guard after != before` 가 옛 값과 비교해, 옮겼다가 도로 그 날로 누르면 아무 일도 안 났고 되돌리기 값도 어긋났다. 편집의 `onClear` 도 같다.
4. **「달력에 남기기」 라벨이 꺼진 칩을 무시했다.** 달력이 물린 날 칩을 끄면 `leave()` 는 안 쓰는데 단추는 여전히 「달력에 남기기」.
5. **되풀이 칩이 날짜 칩과 한 스위치였다.** 「되풀이로 읽지 않습니다」를 누르면 날짜도 꺼졌다.
6. 휴지통에서 되돌린 줄의 밝힘이 휴지통 안에서 켜져 돌아갈 즈음 이미 꺼져 있었다 (`dismiss` 는 선언만 있고 안 쓰임). 달력 탭의 「이 날에 적기」 뒤 키보드를 내릴 길이 없었다. 찾기 범위 문구가 폴더를 골라 둬도 전체 수를 셌다. 편집의 지우기가 저장을 던져 두고 지워 휴지통 글과 어긋날 수 있었다. 공유 시트의 「남기기」를 두 번 누르면 두 장이 됐다.

## 해결 방법
- `PaperTextView` 에 `editing` 바인딩 — 델리게이트가 올리고 내리며, 바깥이 `false` 로 놓으면 `resignFirstResponder`. 편집은 `editing` 동안 위 오른쪽에 「완료」(`done-editing`).
- `DateSheet`: 제목에 시각, 정각만 프리셋 칩이 켜짐(`clock`), 프리셋 밖 시각은 「직접…」이 켜진 채 휠을 펴고 열림(`ownTime`), 휠을 펼 때 시각이 없으면 휠의 시각을 바로 붙임, 이웃 달 칸은 격자를 옮김.
- 시트 클로저는 `store.memo(id)` 로 그때의 메모를 다시 집는다 (달력·편집).
- `leaveLabel` 은 `readsDate && presetDay != nil`. `PenModel.readsEvery` 분리 — 날짜가 꺼지면 되풀이도 꺼져 보이고, 누르면 둘 다 켜진다.
- 휴지통은 `lastRestored` 를 들고 `onDisappear` 에 밝힌다. 달력 목록에 `scrollDismissesKeyboard`. 찾기 범위는 폴더 안에서 센다. 편집의 지우기는 `save()` 를 기다린 뒤 지운다. 공유 시트는 `leaving` 동안 단추를 끈다.

## 검증
`./ios/scripts/uitest.sh` 10/10 통과 — 새 시험 둘: `testDoneLowersTheKeyboardInTheEditor`(열 때 「완료」 없음 → 탭하면 나타남 → 누르면 키보드 사라지고 `tail-date` 가 닿음), `testDateSheetShowsTheClock`(15:00 메모의 시트 제목에 15:00 → 「09:00」 누르면 제목이 따라옴). 맥 앱은 이번에 손대지 않았다.

## 메모
실기기 손검증에 보탤 것: 편집 중 「완료」→ 꼬리 조작, 날짜 시트에서 「직접…」 펴고 접기, 되풀이 칩만 끄고 남기기.