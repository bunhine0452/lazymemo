---
schema_version: 1
type: bug
slug: "save-failures-never-reached-screen"
status: done
difficulty: medium
created_at: "2026-08-29T17:34:22+09:00"
session_id: "20260829-003"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/NoteView.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoStoreTroubleTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/NoteSaveFailureTests.swift"
    op: create
related: []
tags:
  - "error-handling"
  - "autosave"
  - "menubar"
  - "note"
  - "mcp-tool"
---
[x] 저장 실패가 화면 어디에도 안 나오던 것 — 빈 catch 와 아무도 안 읽는 lastError

## 발생 원인

구멍이 셋이고 셋이 이어져 있었다.

① `NoteModel.persistBody` 의 `catch` 가 **비어 있었다.** 주석은 "저장 실패는 조용히 넘어가면 안 된다" 라고 적혀 있는데 코드는 정확히 조용히 넘어갔다. `isDirty` 를 유지하므로 다음 타자에 다시 쓰긴 하지만, **손이 멈춘 뒤에는 다시 쓸 계기가 없다.**

② 실패가 `MemoStore` 까지 올라가지도 않았다. `lastError` 는 `search`·`scheduled`·`reconcile`·`purgeExpiredTrash` 같은 **읽기 경로에만** 적혔고, 정작 글을 잃는 `create`·`update`·`delete` 는 그냥 던지기만 했다. 호출자는 전부 `try?` 라 거기서 죽었다.

③ 그렇게 적힌 `lastError` 조차 **읽는 곳이 하나도 없었다** (grep 결과 `MemoStore.swift` 안 세 줄이 전부).

저장 버튼이 없는 앱에서 이 셋이 겹치면 결과는 하나다 — 안 적힌 글도 화면에는 그대로 있으므로 적힌 것과 **똑같이 보이고**, 그 상태로 창을 닫으면 그대로 잃는다. 사용자는 껐다 켠 뒤에야 안다.

## 해결 방법

**실패는 사용자의 데이터가 위험할 때만, 그리고 반드시 화면까지.**

- `lastError: String?` → `trouble: Trouble?` (`doing` = 사람의 말, `detail` = 기계의 말). 메뉴에는 `doing` 만 적고 Swift 오류 문자열은 도움말로만 보인다 — 종이 위에 오류 덤프가 떠 있으면 그건 이 앱의 화면이 아니다.
- 쓰기 경로 넷(`create`·`update`·`delete`·`restore`)을 `recording(_:_:)` 로 감쌌다. **적어 두고 그대로 던진다** — 호출자의 처리를 뺏지 않으면서 실패가 사라지지 않는다. 성공하면 스스로 지워진다.
- **읽기 경로는 오히려 뺐다.** `search`·`scheduled` 는 인덱스가 아파도 파일 스캔으로 답이 나온다(§5.3). 성공한 일을 실패라고 적으면 그 경고는 다음번 진짜 실패에서도 안 읽힌다. `reconcile` 만 남겼다 — 파일을 못 읽으면 보여줄 것 자체가 없기 때문이다.
- 메뉴 **첫머리**에 `⚠︎ <doing>` 한 줄 (`addTroubleLine`). 목록 아래에 두면 메모 여덟 줄에 밀려 안 읽힌다.
- 종이도 스스로 말한다 — `NoteModel.isUnsaved` 와 꼬리 위의 「아직 안 적혔습니다」. 겹쳐 뜨는 조작과 달리 **보러 오지 않아도 보여야 하는** 종류라 hover 를 기다리지 않는다. 철학 4(앱은 자기를 드러내지 않는다)에 여는 예외이고, 근거는 이건 앱을 드러내는 일이 아니라 사용자의 글을 지키는 일이라는 것.
- 실패 뒤 3초 간격으로 세 번까지 다시 써 본다. 끝없이 두들기면 디스크가 찬 동안 3초마다 도는 고리가 되므로 예산을 둔다 — 표시는 남기고 손은 멈춘다. 다시 타자를 치면 예산이 되돌아온다.

## 검증

- `./scripts/test.sh` — 276개 통과 (신규 9건).
- `MemoStoreTroubleTests` — 없는 메모에 쓰면 `trouble.doing == "메모를 저장하지 못했습니다"` 이고 `detail` 이 비어 있지 않다 · 다음 성공에서 스스로 사라진다 · 실패해도 여전히 던진다 · **인덱스를 통째로 지우고 검색해도 경고가 안 뜬다**(느린 길로 답이 나오므로 실패가 아니다).
- `NoteSaveFailureTests` — 정본 폴더를 잠깐 옮겨 두고 저장을 실패시킨 뒤 `isUnsaved` 가 서는지, 글이 화면에 그대로 남는지(옮겨 담을 수 있어야 한다), 폴더를 되돌리면 표시가 사라지고 본문이 실제로 파일에 들어가는지, 그리고 같은 사실이 `store.trouble` 까지 올라가는지. 마지막 것이 중요하다 — 그 종이가 치워져 있으면 종이의 표시는 아무도 못 본다.
- `LAZYMEMO_MENU=1` — 메뉴가 그대로 지어지고, 실패가 없을 때는 경고 줄이 아예 나타나지 않는다.

## 메모

되풀이 시도를 3초·3회로 잡은 것은 **의도적 지름길**이다. 자리를 비운 사이 디스크가 풀리면 그때는 아무도 다시 쓰지 않는다. 플랜의 `#day-clock` 이 서면 그 시계에 얹는 편이 맞다.