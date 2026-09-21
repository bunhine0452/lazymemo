---
schema_version: 1
type: bug
slug: "tidy-overrode-user-intent"
status: done
difficulty: medium
created_at: "2026-09-22T01:23:45+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/Tidy.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Agenda/GeofenceRule.swift"
    op: update
  - path: "Sources/LazyMemoUI/DueClock.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/TidySafetyTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/DueClockTests.swift"
    op: update
  - path: "scripts/verify-tidy.sh"
    op: update
related:
  - ref: "20260829/Features_to_add/1913_feature_tidy-finished-memos-retreat.md"
    kind: "followup"
  - ref: "20260831/Features_to_add/1726_feature_recurring-walks-instead-of-retreating.md"
    kind: "followup"
tags:
  - "tidy"
  - "recall"
  - "handoff-bundle-1"
  - "plan:lazymemo-product-value"
  - "kept"
  - "mcp-tool"
---
[x] 자동 정리가 사람의 뜻을 덮었다 — 미래 다시 보기·미완료 목록·도로 꺼낸 것이 지난 일정으로 치워지던 셋을 현재 소스로 재현하고 고쳤다 (묶음 1 · R01~R03)

인계서 `docs/PRODUCT_IMPLEMENTATION_HANDOFF.md` §5 묶음 1 (`#tidy-recall-safety`). 세 결함을 **현재 소스로 먼저 재현**했다 — 임시 재현 판(`TidySafetyTests`) 6개 expectation 전부 빨강: R01 `Tidy.reason → .past` 이고 `Recall.reservations` 가 빈 배열, R02 `.past`, R03 꺼낸 같은 날 정리에서 도로 `active` 가 빔.

## 발생 원인

`Tidy.reason` 이 「날짜가 지났다 = 끝났다」로 셌다.

- **R01** 지난 `at` 에 미래 `surface` 가 있어도 `scheduledDate` 만 보고 `.past` → `tidied:` 가 적히고 → `Recall.eligible` 이 `tidied != nil` 을 빼서 **25일 예약이 사라졌다.** 맥의 `DueClock` 은 반대로 `Recall.eligible` 을 안 봐서 치운 종이가 나오는 쪽이었다 — OS 예약과 바탕화면 노출의 제외 규칙이 달랐다.
- **R02** 지난 일정 검사가 체크상자 검사보다 먼저라 `- [ ] 서류 제출` 마감이 지나면 미완료인 채 치워졌다.
- **R03** `untidy` 는 `updated` 만 새로 찍는데, 지난 일정 규칙은 `updated` 를 읽지 않아 꺼낸 그 날 다음 정리가 도로 치웠다. 기존 시험 `restoredStaysRestored` 는 다 체크한 목록만 재서 이 길을 못 봤다.

## 해결 방법

- `Memo.kept: Date?` 신설 — **사람이 도로 꺼낸 때.** frontmatter `kept:` 로 파일에 적는다(`MemoFile` 왕복, `knownKeys`). 옛 판은 모르는 키를 `preserved` 로 되쓰므로 호환된다. 때(`due`·`at`·`surface`)를 옮기면 새 회차라 `update`/`modify` 가 지운다.
- `Tidy.reason` 재배치: `kept` 는 손대지 않음 넷째 → **목록은 칸이 말한다**(칸이 남았으면 nil, 다 체크했으면 `updated`+3일에 `.finished` — 지난 마감으로 먼저 재면 밀린 목록의 마지막 칸을 체크한 그 밤에 사라진다) → 칸 없는 글만 날짜로, **일정 날과 다시 볼 날 중 늦은 날**(`lastDay`) 기준 `.past`. 다시 볼 시각만 있고 일정이 없는 글은 날짜 없는 글이라 물러나지 않는다.
- `MemoService.untidy`/`untidyAll` 이 `kept` 를 찍고(`broughtBack` 한 곳), `tidyFinished` 는 `kept && tidied` 인 파일(옛 판이 도로 치운 것)을 다시 세운다.
- `DueClock` 세 필터와 `GeofenceRule.watchable` 이 `Recall.eligible` 을 쓴다 — 예약·지금·자리 알림·맥 종이가 한 규칙 (R05 의 현재 상태 범위).
- `scripts/verify-tidy.sh` 에 ④ 마감 지난 미완료 목록 ⑤ 지난 약속+앞으로 올 다시 보기 ⑥ `kept:` 가 적힌 지난 일정을 더해 실제 앱 메뉴가 「메모 4장 / 치워 둔 2장」이라 적는지 본다.

R04(놓친 미처리의 발견 경로)·R05 의 완료/보관 상태·R06(회차 완료)은 상태 모델이 필요해 묶음 4 `#memo-state-contract` 의 시험 계약으로 넘긴다 — 지금은 「지난 다시 보기는 `active` 에 남고 새 푸시는 안 만든다」까지만 시험으로 고정했다.

## 검증

- `./scripts/test.sh` 전체(새로 빌드): **1,106개 통과** (Core 539/77 스위트 — 신규 `TidySafetyTests` 13개 포함, UI 87, Reminders 18, 그 외). `--skip-build` 는 낡은 바이너리를 돌린다는 것을 R05 시험에서 한 번 확인하고 다시 빌드했다.
- `./scripts/verify-tidy.sh` — 실제 맥 앱(`LAZYMEMO_MENU=1`)이 6장 중 4장을 목록에 남기고 «치워 둔 2장 — 다 체크한 목록·지난 일정» 을 적었다.
- 실기기 알림·양 기기 동기화는 하지 않았다 — `lazymemo-recall#recall-device` 몫.

## 메모

- `Memo.init` 인자가 늘어 SwiftPM 증분 링크가 낡은 오브젝트를 무는 것은 이번엔 없었다.
- 폰 시뮬레이터 xcodebuild 가 다른 세션에서 돌고 있어(`.build/ios`) 그쪽은 건드리지 않았다.