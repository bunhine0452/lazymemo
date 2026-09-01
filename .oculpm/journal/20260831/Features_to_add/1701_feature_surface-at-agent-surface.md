---
schema_version: 1
type: feature
slug: "surface-at-agent-surface"
status: done
difficulty: medium
created_at: "2026-08-31T17:01:17+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/SurfaceWords.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/DueClock.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteFooter.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Sources/LazyMemoMCP/MemoTools.swift"
    op: update
  - path: "scripts/verify-mcp.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "Tests/LazyMemoCoreTests/SurfaceWordsTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/SurfaceTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md"
    kind: "followup"
tags:
  - "surface"
  - "mcp"
  - "clock"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 나올 때 — Claude 가 종이가 앞으로 나올 시각을 정한다

플랜 `{#p2-surface}` 4항목 전부. 토의 `lazymemo-agent-surface` 가 «차별의 핵심» 으로 꼽은 것이다 — 남의 앱에 결과를 넣는 MCP 서버는 **띄울 화면이 없어서** 시각을 정할 수 없다.

## 추가 기능

**`surface` — 일이 언제인가와 종이가 언제 나오는가는 다르다.** 회의는 3시, 종이는 2시 30분. 「회의 30분 전에 이거 띄워줘」가 MCP `surface_at`·`surface_memo` 로 들어온다.

**장소와 같은 성질로 뒀다 — 자리를 바꾸지 않는다.** `isScheduled` 는 이 필드를 보지 않으므로 달력에 따로 나타나지 않고, 그 시각에 하는 일은 바탕화면의 종이가 앞으로 나오는 것뿐이다. **시스템 알림 권한은 여전히 쓰지 않는다.**

`surface_memo` 를 따로 낸 이유: 나올 시각과 일정이 한 도구에 섞이면 모델이 「30분 전에 띄워줘」를 **「30분 앞당겨줘」로 실행하는 날**이 온다. 이 도구는 `surface` 만 고치고 `due`/`at` 은 건드리지 않으며, 그것을 verify-mcp 가 센다.

## 동작 흐름

**«화면에서 읽히지 않으면 필드를 넣지 않는다»가 이 단계의 첫 항목이었다** (`{#surface-semantics}`). 정한 것:

| 상태 | 꼬리에 적히는 것 |
|---|---|
| 일정만 | `🕐 8월 31일 오후 2:30` |
| 일정 + 나올 때 | `🕐 8월 31일 오후 2:30 · 30분 전` |
| 나올 때만 | `↑ 9월 1일 오전 9시 나옴` |

**두 칩으로 나누지 않았다.** 나누면 무엇이 일정이고 무엇이 알림인지 매번 읽어야 하고, 꼬리는 첫 줄 다음으로 비싼 줄이다(§14.10). 한 조각으로 붙인다 — 그 «붙이는 말» 이 `SurfaceWords.lead` 이고, 분·시간·일로 갈라 말한다. 1분 미만은 알려 주는 값이 없어 아무 말도 하지 않는다.

「나올 때만」 있는 칩은 **누를 수 없다.** 날짜 칩이 누를 수 있는 이유는 그 메모가 달력의 어딘가에 서 있기 때문인데, 이것은 달력에 없어 갈 곳이 없다.

**시계가 보는 값을 하나로 좁혔다** — `Memo.surfacesAt`(적혀 있으면 `surface`, 없으면 `at`). `DueClock` 의 네 자리를 전부 이것으로 바꿨다. 두 갈래로 두면 자다 깬 기계·하루가 바뀐 순간·늦게 켠 저녁이 전부 두 번씩 있게 된다.

## 검증

`./scripts/test.sh` — **494개 통과** (앞 484 → 새 10개: SurfaceWords 5, 메모의 나올 때 5). `./scripts/verify-mcp.sh` — **31항목** 통과, 새로 5개(도구 7개, `surface_memo` 존재, 나올 시각이 따로 적히는지, **일정을 바꾸지 않는지**, **달력의 자리를 바꾸지 않는지**). `./scripts/render-ui.sh` 로 라이트·다크 확인 — `note.png` 가 `🕐 8월 31일 오후 2:30 · 30분 전  #병원` / `📍 강남역 3번 출구` 로 두 줄에 온전히 선다.

## 메모

`Memo.init` 인자가 또 늘어 SwiftPM 증분 빌드가 낡은 오브젝트로 링크에 실패했다. 앞선 일지와 같은 것이고, 테스트 파일을 `touch` 하면 풀린다.

`Tidy` 는 아직 `surface` 를 모른다. 나올 때가 미래인데 일정이 지나 물러난 메모가 그 시각에 어떻게 되는지는 정하지 않았다 — `{#recurring-vs-tidy}` 를 다룰 때 함께 볼 것.