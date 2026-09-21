---
schema_version: 1
type: feature
slug: "conflict-copies-people-can-recover"
status: done
difficulty: medium
created_at: "2026-09-22T01:36:13+09:00"
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
  - path: "Sources/LazyMemoCore/Storage/ConflictSettlement.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemo/TrashView.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/ConflictRecoveryTests.swift"
    op: create
related:
  - ref: "20260913/Features_to_add/0226_feature_icloud-watcher-placeholders-conflicts.md"
    kind: "followup"
tags:
  - "conflict"
  - "icloud"
  - "trash"
  - "handoff-bundle-5"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 동기화 충돌의 진 판을 사람이 고른다 — 「다른 기기의 판」이 지운 메모와 따로 서고, 「이 판으로」·「둘 다 남기기」가 양 플랫폼에 (묶음 5)

인계서 `docs/PRODUCT_IMPLEMENTATION_HANDOFF.md` §5 묶음 5 (`#conflict-recovery`). 2026-09-13 의 `ConflictSettlement` 은 진 판본을 휴지통에 **남기기는** 했다 — 그러나 파일에 「지운 메모」와 다른 점이 하나도 없어(재현 시험: 진 판의 frontmatter 에 자리의 id 가 없음 → 빨강) 사람은 그런 일이 있었는지도, 그 문장이 어느 메모에서 떨어졌는지도 몰랐고, 늦은 시각이 이긴다는 앱의 선택을 뒤집을 손도 없었다. `MemoService.reconcile` 은 `settleConflicts()` 의 결과를 `try?` 로 버린다.

## 추가 기능

- **`Memo.conflictOf: ULID?`** — frontmatter `conflict: <자리 메모 id>`. `ConflictSettlement.settle` 이 진 판에 적고, `sameContent` 는 무시한다. 옛 판은 모르는 키를 `preserved` 로 되쓴다. 왕복 시험.
- **`ConflictSettlement.swapped(winner:loser:)`** — 「이 판으로」의 순수 규칙: 자리의 메모는 **id 를 지킨 채** 진 판의 글·날짜·자리·색·체크·폴더·`preserved` 를 받고(`updated` = 지금), 밀려난 글은 **진 판의 휴지통 자리(같은 id)** 에 `conflictOf` 를 달고 앉는다. 파일이 늘지 않고 한 번 더 하면 원래대로. `kept`·`tidied` 는 자리의 것 — 글이 아니라 자리의 상태.
- **`MemoVault.adoptConflict`** → `MemoService.adoptConflict` → `MemoStore.adoptConflict` (`recording` 경유). 자리의 메모가 그 사이 지워졌으면 되돌리기와 같다. **`MemoVault.restore` 는 `conflictOf` 를 뗀다** — 되돌리기가 곧 「둘 다 남기기」.
- **`MemoStore.conflicts`** — 휴지통 중 `conflictOf` 의 자리 메모가 살아 있는 것. 새 상태 없이 파생.
- **맥 메뉴** — 휴지통 절 맨 위에 「다른 기기의 판 N장 — 따로 고친 글이 만났습니다」, 한 장마다 하위 메뉴: 지금 자리/다른 판 첫 줄(비활성, 툴팁에 두 글 여섯 줄씩) · **이 판으로** · **둘 다 남기기**. 「방금 지운 것」과 「지운 메모 N장」에서는 뺀다 — 사람이 지운 것이어야 하니까.
- **폰 `TrashView`** — 같은 낱말의 절이 위에 서고, 줄을 누르면 `ConflictCompareSheet` 가 두 글을 나란히(지금 자리 / 다른 판, 고친 때) 놓고 두 단추. 스와이프에도 둘.

## 동작 흐름

두 기기가 따로 고쳐 만남 → `settleConflicts` 가 늦은 판을 자리에, 진 판을 `conflict:` 달아 휴지통에 → 맥 메뉴·폰 휴지통이 「다른 기기의 판」으로 따로 셈 → 사람이 견주고 **이 판으로**(글 맞바꿈, 밀려난 글은 같은 자리에 남음) 또는 **둘 다 남기기**(되돌려 나란히). 어느 길에서도 글이 없어지지 않고, 진 판만 물고 있던 사진은 휴지통 본문을 참조로 치는 기존 정리 덕에 살아 있다(시험으로 못 박음).

원자적 쓰기·파일 조정(`NSFileCoordinator`, `upgrades-2026-09#file-coordinator` 의 `oculpm-defer` 그대로)·충돌 해결은 **서로 다른 문제**다 — 이번 것은 셋째만이고, 앞의 둘은 손대지 않았다.

## 검증

- 재현: `ConflictRecoveryReproTests.loserNamesItsWinner` 현재 소스에서 빨강 → 수정 뒤 초록.
- 신규 `ConflictRecoveryTests` 7 + `ConflictRecoveryStoreTests` 4 = **11개** (표시·왕복·맞바꿈 규칙/가역·파일 맞바꿈·되돌리기의 표시 제거·자리 없을 때·저장소의 구분·둘 다 남기기·진 판만의 사진 생존). `./scripts/test.sh` 전체 **1,121개 통과** (Core 551/79).
- 실제 맥 앱(`LAZYMEMO_MENU=1`, 임시 vault 에 자리 1·다른 판 1·지운 것 1)이 「다른 기기의 판 1장」 하위 메뉴(지금 자리/다른 판/이 판으로/둘 다 남기기)와 「지운 메모 1장」을 따로 적었다.
- **못 본 것**: 폰 `TrashView` 는 `swiftc -parse` 문법 확인만 — 다른 세션의 xcodebuild 가 `.build/ios` 를 쓰고 있어 iOS 빌드·시뮬레이터 확인을 하지 않았다. 진짜 iCloud 판본(`NSFileVersion`)은 시험에서 못 만들어 정리 뒤의 모습을 `retire` 로 놓고 쟀다 — 실기기 왕복은 `lazymemo-recall#recall-device`·`lazymemo-app-store#mac-sandbox-handtest` 몫.

## 메모

- 폰 목록(`StackView`)에 「다른 기기의 판 N장 → 휴지통」 한 줄을 세우면 발견이 더 빠르다 — 그 파일은 다른 세션 소유라 손대지 않았다.