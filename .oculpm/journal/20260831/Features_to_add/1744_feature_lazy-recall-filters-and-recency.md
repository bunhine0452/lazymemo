---
schema_version: 1
type: feature
slug: "lazy-recall-filters-and-recency"
status: done
difficulty: medium
created_at: "2026-08-31T17:44:13+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Inbound/MemoFilter.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/LayoutStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoFilterTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/CaptureRecallTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1726_feature_recurring-walks-instead-of-retreating.md"
    kind: "followup"
tags:
  - "search"
  - "recall"
  - "quick-capture"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 게으른 찾기 — 새 문법 없이 생김새·장소·날짜로 거르고, 읽은 것도 「요즘」에 넣는다

플랜 `{#recall-chips}`·`{#recall-ranking}`. 토의가 「Stickies 가 죽은 이유 중 하나가 검색 부재」라고 적어 둔 자리다.

## 추가 기능

**새 문법을 하나도 만들지 않았다.** 이미 이 앱이 쓰는 기호를 그대로 쓴다 — `#` 은 태그와 생김새(`#사진`·`#링크`·`#체크`), `@` 는 장소, 날짜는 **치는 순간 이미 칩으로 떠오르는 그것**이다. 기억나지 않는 낱말 대신 기호를 외우게 하면 본문 검색보다 나을 것이 없다.

`MemoShape` 가 그 «생김새» 다. 게으른 사람이 실제로 기억하는 것은 본문이 아니라 「그 링크 뭐였지」, 「사진 붙여 둔 거」이고, 본문 검색만 있으면 그 기억으로는 아무 데도 갈 수 없다.

**날짜는 적힌 날이든 손댄 날이든 걸린다.** 「어제」라고 친 사람이 찾는 것은 어제로 잡아 둔 일정일 수도, 어제 적어 둔 메모일 수도 있고 — 어느 쪽인지 묻지 않는 편이 게으르다.

**무엇으로 걸렀는지 화면에 적는다.** 「`#사진` 만 보입니다」. 목록이 짧아진 이유가 화면에 없으면 사람은 그것을 «메모가 사라졌다» 로 읽는다 — 「… 외 N장 더」를 세어 적는 것과 같은 이유다.

## 동작 흐름

찾기는 **두 걸음**이다. 인덱스는 낱말만 알고, 생김새·태그·장소·날짜는 메모를 손에 쥐어야 볼 수 있다. 그래서 낱말로 먼저 훑고 조건으로 거른다. 낱말이 비어 있으면(`#사진` 만 쳤을 때) 요즘 것부터 훑는다 — 인덱스에 넘길 것이 없기 때문이다.

`foo#bar` 는 조건이 아니다. `#`·`@` 앞이 글의 처음이거나 공백일 때만 본다 — `PlaceParser` 가 메일 주소를 거르는 것과 같은 한 줄이다.

**읽은 것도 「요즘」이다** (`{#recall-ranking}`). 읽기만 해서는 `Memo.updated` 가 안 움직여 어제 열어 본 메모가 목록 밖으로 밀렸다. `WindowLayout.opened` 를 더해 고친 때와 연 때 중 나중 것으로 센다. **정본 파일이 아니라 파생물(`layout.json`)에 둔다** — 읽기만 해도 정본이 바뀌면 iCloud 가 매번 동기화하고, 「손댄 것은 다시 산 것이다」라는 `updated` 의 뜻도 흐려진다.

여는 것으로 치는 신호는 `activating` 이다. 켤 때 되살아난 창과 시각이 되어 나온 종이는 «내가 본 것» 이 아니다.

## 검증

`./scripts/test.sh` — **537개 통과** (앞 519 → 새 18개: MemoFilter 12, 게으른 찾기 6). `./scripts/verify-mcp.sh` 35항목, `./scripts/verify-notes.sh` 통과. `./scripts/render-ui.sh` 에 `capture-filter.png` 를 더해 눈으로 확인 — `#사진` 을 치면 「`#사진` 만 보입니다」 칩이 서고 사진이 붙은 메모 한 장만 남는다. 라이트·다크 양쪽.

## 메모

**「자주 여는 것」순은 넣지 않았다.** 횟수만 세면 지난달에 스무 번 연 메모가 오늘 것을 이기고, 그걸 고치려면 감쇠를 넣어야 한다 — 그 순간부터 목록 차례가 사람이 예측할 수 없는 값이 된다. 「틀린 자동 분류는 치울 것을 하나 더 만든다」(`{#opt-g}` 를 보류한 판단)와 같은 자리로 보고 «최근 본 것» 하나만 넣었다.

시험 하나가 처음에 빨갰다 — 같은 초에 만든 두 메모는 `updated` 가 같아 차례가 정해지지 않는데, 시험이 그것을 가정하고 있었다. 코드가 아니라 시험이 틀렸고, **지금 위가 아닌 쪽을 열어 보고 그것이 올라오는지** 보는 형태로 고쳤다.