---
schema_version: 1
type: feature
slug: "capture-list-beyond-twenty"
status: done
difficulty: medium
created_at: "2026-08-31T13:04:05+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureBrowseTests.swift"
    op: update
related: []
tags:
  - "quick-capture"
  - "search"
  - "ux"
  - "mcp-tool"
---
[x] 스무 장 너머 — 목록이 끊긴 자리에 끊겼다고 적고, 그 자리에서 넓어진다

## 추가 기능

빠른 입력 목록이 다섯 줄에서 **소리 없이 잘려 있었다.** 검색은 인덱스에서 5줄만 들고 왔고 요즘 목록도 앞 다섯 장만 잘라 썼으므로, 여섯 번째가 있는지를 **앱 자신도 몰랐다.** 사람은 그것을 "이게 전부" 로 읽고, 아홉 번째 메모는 있는 줄도 모르는 채 다시 적힌다. 메뉴 목록이 여덟 장에서 끊기므로 그 너머는 이 상자에서만 만나는데, 여기서까지 끊기면 그 메모들은 어디에도 없는 것이 된다.

- 목록 아래에 「… 외 N장 더」 한 줄. 누르면 스무 줄까지 넓어진다.
- **마지막 줄에서 ↓ 를 한 번 더** 눌러도 넓어지고, 넓어진 여섯째 줄이 곧바로 골라진다 — 마지막 줄의 ↓ 는 어차피 할 일이 없던 키다.
- 넓혀도 남으면 「… N장 더 있습니다 — 낱말을 더 적으면 좁혀집니다」. 스무 줄을 훑는 것보다 한 글자 더 치는 편이 짧다.

## 동작 흐름

요점은 **화면에 놓는 수와 아는 수를 갈라 놓은 것**이다.

- `listed` 를 저장 속성에서 계산 속성으로 바꾸고 그 뒤에 `pool`(찾아 둔 것 전부)을 둔다. `listed = pool.prefix(isExpanded ? 20 : 5)`.
- 검색은 `searchCeiling = 200` 으로 세어 온다. 200줄을 세는 값은 인덱스에서 거의 공짜이고, 그래야 "몇 장이 남았는지" 를 정직하게 적을 수 있다.
- `overflow` 가 `.more(N)` / `.tooMany(N)` 로 화면이 할 말을 정한다.
- 넓힘은 **낱말이 바뀌면 접힌다**(새 목록은 다른 물건이다). 지운 뒤의 다시 짓기(`refreshListing`)는 같은 목록이므로 접지 않는다 — 한 장 지울 때마다 목록이 도로 좁아지면 치우던 손이 멈춘다.

## 검증

`CaptureBrowseTests` 에 8건 신설 — 세는 수, 넓히기, 스무 장 초과, 끝에서 ↓, 다 보일 때의 ↓(예전대로 선택을 놓는다), 검색 상한, 낱말이 바뀔 때 접힘. 전체 377개 통과. `capture-recent.png` 에 「… 외 5장 더」 줄이 실제로 그려지는 것을 눈으로 확인했다.