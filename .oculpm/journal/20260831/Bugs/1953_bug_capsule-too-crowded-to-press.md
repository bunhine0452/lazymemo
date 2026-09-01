---
schema_version: 1
type: bug
slug: "capsule-too-crowded-to-press"
status: done
difficulty: high
created_at: "2026-08-31T19:53:47+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Views/NoteControlLayout.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Calendar/CalendarView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Drawer/DrawerView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/NoteControlLayoutTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureRecallTests.swift"
    op: correct
related:
  - ref: "20260831/Features_to_add/1906_feature_claude-on-the-paper.md"
    kind: "blocked_by"
tags:
  - "ux"
  - "hit-target"
  - "layout"
  - "regression"
  - "mcp-tool"
---
[x] 버튼이 눌리지 않던 이유 — 과녁이 아니라 캡슐에 든 개수였다

사용자가 「아직도 모든 버튼이 누르기 존나 불편하다」고 했다. 「아직도」가 붙은 것은 앞서 한 번 고친 적이 있다는 뜻이고, 실제로 다른 세션이 그 일을 하고 있었다.

## 발생 원인

**내가 붙인 다듬기(✧) 버튼이 남의 예산을 깼다.**

종이의 조작 캡슐은 폭 예산이 빠듯하다 — 260pt 종이에서 캡슐이 넓어지면 꼬리(날짜·장소·태그)가 비워 둬야 할 폭도 함께 넓어지기 때문이다. 다른 세션이 세워 둔 시험 `footerStillHasRoomForADate` 가 그 예산을 지키고 있었고 **슬랙이 2pt** 였다(room 112 > 110).

거기에 다듬기를 더해 다섯이 되자 캡슐 136pt, **남는 자리 87pt** — 날짜 한 줄(약 100pt)이 안 들어간다. 그런데 그 시험은 기본값 `buttons: 4` 만 재고 있어서 **조용히 지나갔다.** 화면에서는 날짜가 캡슐 밑으로 들어가고 있었다.

그리고 그 다섯이 **1pt 간격**으로 붙어 있었다. 과녁은 이미 24pt(`Theme.touch`)로 키워져 있었지만 사이에 죽은 자리가 없으면 키운 값이 절반이다 — 손이 조금만 흘러도 옆 것이 눌린다. 게다가 이 캡슐의 둘레는 **글을 적는 면**이라, 빗나간 클릭은 아무 일도 없는 것이 아니라 **커서가 옮겨 가는 일**이다. 「눌렀는데 딴 게 됐다」가 여기서 나온다.

같은 고장이 달력 줄에도 있었다 — `rowControls` 가 `HStack(spacing: 0)` 이라 24pt 넷이 완전히 맞붙어 있었다.

## 해결 방법

**캡슐에서 둘을 덜어 냈다.** 픽셀을 더 짜내는 길은 없었다 — 넷에 간격 3만 줘도 예산이 깨진다(room 104).

덜어 낼 기준은 «자주 하지 않고, 잘못 눌러도 값이 싼» 것이다. **색과 고정**이 그렇고, 둘은 우클릭 메뉴(`NoteView.paperMenu`)로 갔다 — macOS 사람이 이미 아는 자리이고 화면에 자리를 차지하지 않아 철학 4 와도 부딪히지 않는다. 캡슐에는 되돌리기 값이 비싼 것(지우기)과 자주 쓰는 것(달력·다듬기)만 남는다.

그렇게 열린 예산으로 **간격을 1 → 6** 으로 벌렸다. 남는 자리 152pt(둘) / 122pt(셋).

| | 캡슐 | 남는 자리 |
|---|---|---|
| 예전 (다섯, 간격 1) | 136pt | **87pt ✗** |
| 지금 (셋, 간격 6) | 101pt | 122pt |
| 지금 (둘, 간격 6) | 71pt | 152pt |

**시험이 재던 것이 틀려 있어서 함께 고쳤다.** `bottomControlsClearTheFooter` 는 캡슐을 4개로, 비우는 폭을 기본값으로 재고 있었다 — 그 둘이 어긋나면서 실은 «덮이는가» 가 아니라 **«두 숫자가 우연히 맞는가»** 를 재고 있었다. 이제 둘 다 실제 버튼 수를 돈다. `footerReserve` 의 기본값도 4(화면 어디에도 없는 숫자)에서 `paperButtons(hasTidy: true)` 로 바꿨다.

나머지 과녁도 잡았다 — 달력 `rowControls` 간격 0 → 6, 종이의 되돌리기 둘(다듬기·삭제), 서랍의 「꺼내기」(맨 `Button` 이라 글자 크기가 곧 과녁이었다).

## 검증

`./scripts/test.sh` — **598개 통과** (새 시험 둘: `buttonsAreNotFlush`, `capsuleStaysSmall`). `verify-notes`·`verify-mcp`·`verify-drawer`·`verify-capture-paste` 전부 통과. `render-ui.sh` 로 눈으로 확인 — `note.png` 의 캡슐이 🗑 | ✧ 📅 셋으로 줄고 사이가 뚜렷하며 꼬리가 온전히 읽힌다. `calendar-in-use.png` 의 줄 캡슐도 넷 사이가 벌어졌다.

`button`(24)·`capsulePadding`(3)·`firstLineCover`·`footerLine`·`footerTwoLineInset`·`capsuleHeight` 는 건드리지 않았다 — 다른 세션이 알려 준 `button < 26` 제약이 그대로 성립한다.

## 메모

**같은 워킹트리를 세 세션이 쓰고 있었다.** `git show HEAD` 와 견주어 보고서야 `Theme.touch`·`hitTarget`·`footerLine`·서랍 위젯이 내 것이 아님을 알았다. 사용자 지시로 `lazymemo-0c`·`lazymemo-ca` 에 알려 그 파일들에서 손을 떼게 했다. **브랜치가 아니라 한 트리라 «합칠 것»이 없다는 점**이 중요하다 — 서로의 편집이 이미 섞여 있다.

내가 쓴 `CaptureRecallTests` 둘이 고정 320ms 대기라 기계가 바쁘면 지고 있었다. 조건을 기다리도록 고쳤다 — 코드가 아니라 시험이 틀린 것이었다.

`verify-capture-paste` 는 앱을 띄우는 스크립트 넷을 연달아 돌리면 실패한다(SIGTERM). 혼자 돌리면 통과한다 — 스크립트끼리 앞선 인스턴스가 겹치는 것으로 보이고, 앱의 결함은 아니다.