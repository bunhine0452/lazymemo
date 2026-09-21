---
schema_version: 1
type: feature
slug: "mac-done-archive-missed-summary"
status: done
difficulty: medium
created_at: "2026-09-22T02:45:23+09:00"
session_id: "20260922-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "54528a1e-487d-482a-9760-2f4dc8885b53"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteFooter.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerContents.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "scripts/verify-state.sh"
    op: create
  - path: "Tests/LazyMemoUITests/MemoStateMenuTests.swift"
    op: create
related:
  - ref: "20260922/Bugs/0123_bug_tidy-overrode-user-intent.md"
    kind: "followup"
  - ref: "20260829/Features_to_add/1913_feature_tidy-finished-memos-retreat.md"
    kind: "followup"
tags:
  - "mac"
  - "menu"
  - "calendar"
  - "note"
  - "done"
  - "archive"
  - "handoff-bundle-4"
  - "plan:lazymemo-product-value"
  - "mcp-tool"
---
[x] 맥에서 끝내기·보관·놓친 것 — 메뉴의 「놓친 N장 · 오늘 N장 · 나중에 N장」과 하위 손, 「보관한 N장」, 치워 둔 것 하나씩 꺼내기, 달력 줄과 종이의 완료 (묶음 4 맥)

인계서 §5 묶음 4 의 맥 절반 (`#unfinished-recall`). Core 의 계약(`Memo.done`·`archived`·`isActionable`·`isPutAway`, `Recall.summary`, `MemoStore.markDone/markUndone/archive/unarchive`)은 부모 세션이 놓았고, 여기서는 **손잡이만** 단다 — 화면이 완료·알림 규칙을 따로 만들지 않는다.

## 추가 기능

- **메뉴 요약 한 줄** `addSummaryLine` — 「놓친 2장 · 오늘 3장 · 나중에 5장」. `Recall.summary(store.memos, seen: NowSeen.load())` 가 정하므로 폰의 띠 밑 요약과 같은 수. 「봤어요」로 내려놓은 등장은 이 기기의 기억이라 여기서만 빠진다 — 완료가 아니다. 놓친 것은 하위 메뉴: 제목 · 언제(`MemoTimeLabel`), 그 밑에 열기 / 완료 / 보관 / 내일 아침으로(`Snooze.tomorrowMorning` — 배너 단추와 같은 값, 일정은 그대로). 푸시는 없다.
- **「보관한 N장」** 절 — 지운 것과 따로 세고, 하위 메뉴에서 하나씩 「보관에서 꺼내기」(꺼내면 종이를 앞으로).
- **치워 둔 것 「하나씩 꺼내기」** 하위 메뉴 — 「도로 꺼내기」 한 번이 전부를 세우고 꺼낸 것은 `kept` 라 규칙이 못 치우므로, 두 장 보려던 손이 열 장을 영영 세우는 셈이었다. 전부 꺼내는 줄은 그대로.
- **달력 줄** — 끝낼 것이 있는 줄(`isActionable`)에만 ✓ 단추, 끝낸 줄은 ↩(되돌리기)·꼬리에 `· 완료`. 낱말로 두었더니 캡슐이 넘쳐 「···」로 잘려 그림 하나로(길찾기 핀과 같은 규칙). `CalendarModel.toggleDone`.
- **종이** — 우클릭에 「완료」(끝낼 것이 있을 때만)/「되돌리기」와 「보관」; 꼬리 맨 앞에 ✓ 완료 표(`NoteFooter.isVisible` 에 `done` 포함). `NoteModel.toggleDone/archive`.
- **보관한 것의 자리** — 바탕화면에 서지 않고(`NoteWindowManager.plannedVisibleMemos`: `!isPutAway`), 서랍에는 치워 둔 것처럼 있다(`DrawerContents.holds`); 찾아서 열거나 서랍에서 꺼내면 `unarchive`. 끝낸 것은 사흘 동안 그대로 서 있다.
- 영어 표: 새 낱말 전부 + 묶음 5 의 「다른 기기의 판」 절이 빠뜨린 9줄을 채웠다 (`check-l10n` 의 내 파일 빠짐 0).

## 동작 흐름

메뉴 열기 → 「놓친 2장 · …」 → 놓친 것 → 「완료」 → `store.markDone` → 파일 `done:` → 알림·「지금」에서 빠지고 목록엔 남음 → 사흘 뒤 `Tidy` 가 물러나게 함. 「보관」 → `archived:` → 목록·바탕화면에서 빠지고 「보관한 N장」·서랍·검색에 있음 → 꺼내면 `kept` 로 규칙이 못 치움.

## 검증

- `scripts/verify-state.sh`(신규) — 실제 앱(`LAZYMEMO_MENU=1`, 임시 vault, 여섯 장)이 「놓친 2장 · 나중에 1장」, 놓친 것 둘의 열기/완료/보관/내일 아침으로, 「메모 4장」(보관 빠짐·끝낸 것 남음), 「치워 둔 1장 — 하나씩 꺼내기 → 장보기」, 「보관한 1장 → 나중에 볼 자료」를 적고 「지운 메모」가 없음을 확인. `verify-tidy.sh` 도 그대로 통과.
- 임시 렌더(시험 파일로 찍고 지움) — 달력 줄 캡슐 「✓ 미루기 종이로 | 🗑」과 끝낸 줄의 `· 완료` 꼬리, 종이 꼬리의 「✓ 완료 · 9월 22일 (화)」 확인.
- `./scripts/test.sh` 전체 **1,142개 통과** (UI 87 → 새 `MemoStateMenuTests` 3 포함 90… 정확히: Core 411/63·UI 90/16 등 합 1,142). 
- 안 한 것: 실제 클릭으로 완료·보관을 누르는 장면(메뉴는 시스템 창), 다크 모드 실앱, 「내일 아침으로」가 파일의 `surface` 를 바꾸는 것은 Core 시험이 보증.

## 메모

- 부모 세션의 `PreviewRenderer` 는 손대지 않았다 — `calendar`·`note` 렌더에 끝낸 표본을 더하면 상시 확인이 된다 (한 줄 제안).
- `Recall.summary` 의 「오늘」은 세 장으로 줄이기 전의 수라 띠와 다를 수 있다 — 그것이 뜻이다(세 장이 전부가 아니다).