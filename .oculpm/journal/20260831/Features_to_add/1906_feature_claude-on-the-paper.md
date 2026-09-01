---
schema_version: 1
type: feature
slug: "claude-on-the-paper"
status: done
difficulty: high
created_at: "2026-08-31T19:06:44+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Claude/ClaudeCLI.swift"
    op: create
  - path: "Sources/LazyMemoCore/Claude/ClaudeRunner.swift"
    op: create
  - path: "Sources/LazyMemoCore/Claude/BriefClock.swift"
    op: create
  - path: "Sources/LazyMemoUI/Claude/ClaudeSupport.swift"
    op: create
  - path: "Sources/LazyMemoUI/Claude/MorningBrief.swift"
    op: create
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowManager.swift"
    op: update
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "Tests/LazyMemoCoreTests/ClaudeCLITests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/ClaudeRunnerTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/ClaudePromptsTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/BriefClockTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/NoteTidyTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/NoteControlLayoutTests.swift"
    op: update
related:
  - ref: "20260831/Features_to_add/1744_feature_lazy-recall-filters-and-recency.md"
    kind: "followup"
tags:
  - "claude"
  - "subprocess"
  - "wait-state"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 종이 위에서 Claude 를 부른다 — 그리고 이 앱이 처음 「기다리는 상태」를 갖는다

플랜 `{#claude-cli-detect}`·`{#claude-wait-state}`·`{#claude-tidy-action}`·`{#claude-morning-brief}`. 설계문서가 F-2 로 미뤄 둔 것이고, 「정리를 대신 해준다」(§1 의 약속 ②)가 **Claude Desktop 을 설정하지 않은 사람에게도** 닿는 첫 길이다.

## 추가 기능

**있으면 켜지고 없으면 조용히 없다.** `claude` 가 없는 컴퓨터에서는 종이에 조작이 하나 안 생길 뿐이고 그 사실을 어디에도 적지 않는다. 안 되는 버튼을 놓아 두는 것보다 아예 없는 편이 낫다.

**찾는 것이 생각보다 어려웠다.** GUI 앱은 로그인 셸을 거치지 않고 뜨므로 PATH 가 `/usr/bin:/bin:/usr/sbin:/sbin` 뿐이다 — 터미널에서 `which claude` 가 되는데 앱에서는 안 되는 이유가 이것이고, **그냥 `which` 를 부르면 거의 모든 사용자에게 「없음」이 나온다.** 실제로 이 기계의 `claude` 는 fnm 의 node-versions 아래에 있어 어떤 고정 목록으로도 못 찾는다. 그래서 두 걸음이다 — ① 있을 만한 자리를 직접 보고 ② 못 찾으면 `zsh -lc 'command -v claude'` 로 **로그인 셸에게 물어본다.** 찾은 자리는 `settings.json` 에 적어 두고 다시 묻지 않는다(켤 때마다 셸을 띄울 이유가 없다).

**종이 위 ✧** 를 누르면 Claude 가 그 메모를 다듬는다.

## 동작 흐름 — 기다림을 말하는 낱말이 없었다

지금까지 이 앱의 모든 조작은 즉시 끝났다. 그래서 «기다림» 을 말하는 낱말이 화면에 하나도 없었고, 답이 십 초 걸리는 조작을 그냥 붙이면 종이는 그동안 **아무 말도 안 하는 종이**가 된다. 정한 것 넷:

1. **끝나지 않는 것은 없다** — 90초 상한. 답이 영영 안 오는 종이는 「고장」이고 고장은 되돌릴 수 없다.
2. **답이 오는 사이에 글이 바뀌었으면 버린다** — 십 초는 한 줄 더 적기에 충분하고, 그때 덮어쓰면 다듬은 것이 아니라 **지운** 것이다.
3. **되돌리기 8초** — 지우기와 같은 창(D6). 다만 종이를 **덮지 않는다**: 지우기는 글이 없어진 것이지만 다듬기는 바뀐 것이라, 바뀐 글이 보여야 되돌릴지 정할 수 있다.
4. **실패를 조용히 삼키지 않는다** — 아무 일도 없어 보이면 사람은 한 번 더 누르고, 그때마다 값이 나간다.

**stderr 를 파이프가 아니라 파일로 받는다.** 파이프로 받으면 그쪽이 64KB 를 넘기는 순간 양쪽이 서로를 기다리며 멈춘다 — 재현이 어렵고 사용자에게만 나는 교착이다. 글은 인자가 아니라 **stdin** 으로 준다(긴 메모는 인자 길이 상한에 걸리고, 따옴표가 든 글은 새는 자리다).

**「코드펜스를 붙이지 마라」를 말로 막고 코드로 한 번 더 막는다** (`ClaudePrompts.clean`). 모델은 종종 붙이고, 그걸 그대로 넣으면 메모 전체가 코드 덩어리로 꾸며진다.

**아침 브리핑은 기본이 꺼짐이다.** 사용자가 누르지 않았는데 토큰을 쓰는 유일한 기능이라 §9.3 의 조건 셋으로는 모자라고, «켜는 것을 사람이 직접 해야 한다» 로 한 단계 더 잠갔다. 메뉴에도 「구독 사용량이 듭니다」라고 적는다. 종이는 **한 장을 다시 쓴다** — 매일 새로 만들면 한 달에 서른 장이 쌓이고 그건 정리가 아니라 치울 거리다.

## 검증

`./scripts/test.sh` — **590개 통과** (앞 537 → 새 28개: ClaudeCLI 8, ClaudeRunner 7, ClaudePrompts 5, BriefClock 2, 다듬기 6, 조작 줄 2 — 이번에 늘린 것 포함). **진짜 `claude` 를 부르는 시험은 없다** — 시험이 사용자의 토큰을 쓰면 안 되므로 가짜 실행 파일(`#!/bin/sh cat`, `exit 3`, `sleep 30`)로 stdin·종료 코드·상한을 전부 지났다.

`./scripts/render-ui.sh` 로 눈으로 확인 — `note.png` 에서 ✧ 가 캡슐에 섰고 **꼬리는 덮이지 않았다.** 버튼이 넷에서 다섯으로 늘면 캡슐이 넓어지고 꼬리가 비워 둔 폭이 그대로면 날짜가 캡슐 밑으로 들어가는데(그 파일이 처음부터 경고하던 어긋남), `controlCount` 로 둘을 묶고 시험으로도 못 박았다. `./scripts/verify-notes.sh` 통과.

## 메모

**진짜 `claude` 로 끝까지 돌려 보지는 않았다.** 배선(찾기·stdin·상한·종료 코드·되돌리기)은 전부 시험했지만, 실제 모델이 돌려주는 답으로 종이가 어떻게 바뀌는지는 사용자가 한 번 눌러 봐야 안다. 아침 브리핑도 마찬가지다 — 여덟 시를 기다려야 하고, 기본이 꺼져 있어 켜야 돈다.