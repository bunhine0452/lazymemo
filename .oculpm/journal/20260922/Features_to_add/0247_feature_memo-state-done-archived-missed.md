---
schema_version: 1
type: feature
slug: "memo-state-done-archived-missed"
status: done
difficulty: high
created_at: "2026-09-22T02:47:32+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Tidy.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Checklist.swift"
    op: update
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoStateTests.swift"
    op: create
  - path: "ios/LazyMemo/UnfinishedView.swift"
    op: create
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/NowBand.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "ios/LazyMemo/TutorialView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/research/usage-observation-2026-09-22.md"
    op: create
related:
  - ref: "20260922/Features_to_add/0245_feature_mac-done-archive-missed-summary.md"
    kind: "followup"
  - ref: "20260922/Bugs/0123_bug_tidy-overrode-user-intent.md"
    kind: "followup"
  - ref: "20260922/Features_to_add/0230_feature_capture-always-saves-followups-optional.md"
    kind: "followup"
tags:
  - "memo-state"
  - "done"
  - "archived"
  - "recall"
  - "now-band"
  - "handoff-bundle-4"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 처리 상태의 계약과 폰의 「놓친 것」 — done·archived 를 파일에 적고, 회차마다 완료를 풀며, 「지금」 세 장 곁에 놓친 것·오늘·나중에의 전체를 둔다 (묶음 4 · Core+폰)

인계서 §5 묶음 4 (`#memo-state-contract` → `#unfinished-recall`). 맥 화면 절반은 병렬 세션이 맡았다 (related 의 `mac-done-archive-missed-summary`). 순서는 인계서대로 파일 읽기/쓰기 호환 → 서비스 행동/되돌리기 → 예약/선정 규칙 → 폰/맥 → 위젯.

## 추가 기능

**상태 계약** (`Tests/LazyMemoCoreTests/MemoStateTests.swift` 머리의 표가 정본):

| 상태 | 뜻 | 파일 | 알림·「지금」·자리 알림 | 목록 |
|---|---|---|---|---|
| `done` | 사람이 끝냈다 | `done:` | 빠진다 | 남았다가 사흘 뒤 물러난다(`Tidy` `.finished`) |
| `archived` | 당장 안 볼 기록 | `archived:` | 빠진다 | 빠진다 — 검색·달력은 그대로 |
| 「봤어요」 | 이 등장·이 기기의 표시 억제 | 파일 아님(`NowSeen`) | 그 등장만 | 그대로 |
| `kept` | 도로 꺼냈다 | `kept:` | 그대로 | 규칙이 못 치운다 |

- `Memo.done`·`Memo.archived`(`knownKeys`·`MemoFile` 왕복; 옛 판은 모르는 키로 되쓴다), `Memo.isPutAway`(tidied‖archived), `Memo.isActionable`(칸이 남았거나 surface·at·due 가 있고 done 아님 — 「완료」 단추를 어디 둘지 이것이 정한다: 그냥 글엔 없다).
- `Recall.eligible` 이 done·archived 를 뺀다 → 예약·「지금」·위젯·자리 알림·맥 DueClock 이 한 규칙. `MemoStore.active` 가 archived 를 빼고 `archivedMemos`/`tidiedMemos` 를 가른다.
- `MemoService.markDone/markUndone/archive/unarchive` (+ `MemoStore` 의 `recording` 경유). 끝냄은 `kept` 를 이기고, 꺼냄은 `kept` 를 찍는다. 때(`due`·`at`·`surface`)를 옮기면 `done` 도 푼다 — 새 회차.
- **R06**: `Tidy.rolled` 가 다음 회차로 걸어갈 때 `done` 을 비우고 체크한 칸을 빈 칸으로(`Checklist.uncheckingAll`) — 「매주 분리수거」를 한 번 끝낸 사람의 다음 회차에 알림이 다시 선다. `Tidy.reason` 은 done 을 `finishedGrace`(사흘)로 물러나게 하고 archived 는 건드리지 않는다.
- `Recall.summary(memos, now:, calendar:, seen:)` → `missed`(지난 날의 surface·at 을 안 봤고 안 끝냈거나, 마감 지난 칸 남은 목록 — 「봤어요」한 등장은 빠지고, 미래 다시 보기의 지난 일정은 놓친 것이 아니다; 방금 지난 것이 먼저)·`today`(세 장으로 줄이기 전)·`later`. **`tidied` 를 done 으로 이행하지 않는다** — 옛 표시 그대로, 개별 복원은 검색·메뉴.
- 비서의 메모 상태(`Contracts.swift`)도 done·archived 를 「끝난 것」으로 본다.

**폰** — `NowBand` 카드에 「완료」(끝낼 것이 있을 때만, 「봤어요」와 나란히·다른 뜻), 줄 오른쪽 밀기 완료(→끝냈으면 되돌리기)·미루기·고정, 왼쪽 밀기 보관·지우기, 컨텍스트 메뉴·접근성 행동 같음; 끝낸 줄은 ✓ 와 취소선, 보관한 줄은 「N 전 보관」. 「지금」 아래 `RecallSummaryRow` 「놓친 2 · 오늘 5 · 나중에 3」(찾는 중·폴더 안에선 없음; 셋 다 비면 없음) → `UnfinishedSheet`(놓친 것/오늘/나중에 — 열기·완료·내일 아침 9시·보관, 되돌리기 등록), 더 보기 「보관 N장」 → `ArchivedSheet`(꺼내기). 새 파일 `ios/LazyMemo/UnfinishedView.swift`. 안내 다섯 장·README 의 낱말을 맞췄다.

**위젯** — `Recall.nowCards`/`eligible` 을 그대로 쓰므로 끝낸 것·보관한 것이 자동으로 빠진다. 새 화면은 없다.

## 동작 흐름

폰: 줄을 오른쪽으로 밀어 「완료」 → 파일에 `done:` → 예약·「지금」에서 빠짐 → 줄은 ✓ 로 사흘 남음 → 흔들면 되돌림. 어제 다시 보기로 한 글을 안 봤으면 아침에 「놓친 1」 → 전체 → 길게 눌러 완료/내일 아침/보관. 「매주」 메모를 끝내면 다음 회차에 도로 산다.

## 검증

- `./scripts/test.sh` 전체 **1,142개 통과** (맥 절반과 합친 상태) — 새 `MemoStateTests` 8 + `MemoStateSweepTests` 4: 왕복·구형 파일·`eligible`·`isActionable`·사흘 유예·R06 회차 리셋·`uncheckingAll`·요약(놓친/오늘/나중에·봤어요·미래 다시 보기)·완료 왕복(파일·예약·되돌리기·물러남)·보관 왕복(검색·꺼냄 뒤 규칙)·때 옮기면 done 풀림·되풀이 끝내고 정리.
- 폰 시뮬레이터 스모크 **27개 전부 통과** — 새 `testMissedSummaryDoneAndArchive`: 어제의 다시 보기 → 「놓친 1」 → 전체에서 길게 눌러 완료 → 파일에 `done:` → 요약 사라짐·줄은 ✓ 로 남음 → 그냥 글엔 「완료」 없음·「보관」 → 목록에서 빠짐 → 더 보기 「보관 1장」 → 파일에 `archived:`. 찍은 화면(`/tmp/lazymemo-archived.png`)으로 ✓·취소선·보관 시트 확인.
- 폰 앱·위젯 확장 `xcodebuild build` 성공. `verify-state.sh`·`verify-tidy.sh` 통과(맥 절반).
- 안 한 것: 폰 완료가 **동기화된 맥·위젯에 반영되는 장면**(iCloud 두 기기)·시간대 변경·동시 수정 — 파일 규칙은 시험으로 고정했지만 실기기 왕복은 `lazymemo-recall#recall-device` 몫. 위젯 실화면은 이번에 찍지 않았다.

## 메모

- 날짜만 있는 메모의 「기본 시간 고르기」는 결과 카드의 「시각 정하기」(묶음 3)로 갈음.
- 「오늘 숨김(봤어요)」과 「완료」를 한 단추로 뭉치지 않았다 — 인계서 §4 의 표 그대로.