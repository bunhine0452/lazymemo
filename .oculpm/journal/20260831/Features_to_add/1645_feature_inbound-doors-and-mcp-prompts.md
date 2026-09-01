---
schema_version: 1
type: feature
slug: "inbound-doors-and-mcp-prompts"
status: done
difficulty: high
created_at: "2026-08-31T16:45:37+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Inbound/Inbound.swift"
    op: create
  - path: "Sources/LazyMemoCore/Inbound/NoteReader.swift"
    op: create
  - path: "Sources/LazyMemoUI/QuickCapture/InboundDoor.swift"
    op: create
  - path: "Sources/LazyMemoMCP/MemoPrompts.swift"
    op: create
  - path: "Sources/LazyMemoMCP/main.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/ClipboardCapture.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "Sources/LazyMemoUI/AppDelegate.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "README.md"
    op: update
  - path: "scripts/verify-mcp.sh"
    op: update
  - path: "Tests/LazyMemoCoreTests/InboundTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/NoteReaderTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/VaultAdoptionTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/InboundDoorTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1629_feature_in-app-update.md"
    kind: "followup"
tags:
  - "inbound"
  - "mcp"
  - "cli"
  - "url-scheme"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 문을 넷 열었다 — 터미널·URL·서비스 메뉴·아이폰, 그리고 사람이 읽는 MCP 프롬프트

플랜 `{#p1-doors}` 전부(7항목)와 `{#place-from-clipboard}`. 전부 권한을 요구하지 않는다.

## 추가 기능

**문이 넷이어도 안으로 들어오는 것은 하나다** (`InboundNote` → `NoteReader` → `InboundDoor`). 문마다 따로 읽으면 같은 글이 어디로 들어왔느냐에 따라 달라지고, 그건 사용자가 「형식을 배우지 않는다」를 문마다 다시 배우는 것이다. 어느 문으로 들어와도 `내일 3시` 는 일정이 되고 `@강남역` 은 장소가 된다.

| 문 | 어떻게 |
|---|---|
| 터미널·cron·스크립트 | `lazymemo-mcp add "내일 3시 치과 @강남역"` |
| 다른 앱 | 우클릭 → 서비스 → 「lazymemo 에 적기」 |
| 단축어·Raycast·Alfred | `open "lazymemo://add?text=…"` |
| 아이폰 | 폴더에 `.md` 를 떨구면 앱이 받아 앉힌다 |

**URL 스킴은 글자만 받는다.** 파일 경로도 실행할 명령도 열 주소도 받지 않는다 — 이 컴퓨터의 아무 프로그램이나 두드릴 수 있는 문이라, 문 뒤에 있는 것이 「글을 종이에 적는다」 하나뿐이어야 안전하다. **할 수 있는 일을 늘리지 않는 것이 유일하게 확실한 방어**라, `lazymemo://run?cmd=…` 같은 것이 아예 파싱되지 않는 것을 시험으로 못 박았다.

**CLI 는 인자가 없을 때의 동작을 바꾸지 않는다.** Claude Desktop 이 이 실행 파일을 인자 없이 띄우므로, 그 갈래를 건드리면 이미 등록해 둔 사람의 연동이 조용히 깨진다.

**MCP 프롬프트 5개.** 도구 목록은 모델이 읽고 프롬프트 목록은 **사람이 읽는다** — 지금까지 비어 있던 쪽이 사람 쪽이었다. MCP 를 등록해도 무엇을 시킬 수 있는지 모르면 아무 일도 안 일어나고, 그러면 「정리를 대신 해준다」의 절반은 등록만 해 두고 안 쓰이는 기능이 된다. 문구에 규칙 셋을 걸었다 — ① **지우기 전에 묻는다**(D6 가 하드 삭제 도구를 안 만든 것과 같은 이유로 문장에서도 한 번 더 막는다) ② 적게 돌려준다(셋이면 셋이라고 적는다) ③ 날짜와 장소를 채우게 한다.

**낯선 파일을 받아 앉힌다** (`MemoVault.adopt`). 이 앱의 파일 이름은 ULID 인데 밖에서 만든 파일이 그 규칙을 알 리 없다. **이름을 맞추라고 요구하는 대신 우리가 붙인다** — frontmatter 가 아예 없으면 파일 전체를 본문으로 보고, `id` 만 없으면 `due`·`place` 는 그대로 살린다. 이 한 줄이 아이폰 단축어·Hazel·Finder 끌어놓기를 전부 입력 경로로 만들었다.

## 동작 흐름

`ClipboardCapture` 의 글 갈래를 `InboundDoor` 로 넘겼다. **부수 효과로 클립보드가 장소를 읽게 됐다** — 지도 앱에서 복사한 주소가 그대로 `place:` 가 된다(`{#place-from-clipboard}` 도 여기서 끝났다).

**번들 설정과 코드의 짝을 시험이 지킨다.** `Info.plist` 의 `NSMessage` 와 `@objc` 메서드 이름이 어긋나면 «메뉴에는 나타나는데 눌러도 아무 일이 없다» 가 되고, 그건 화면을 봐서는 알 수 없다. 그래서 plist 를 직접 읽어 ① 등록한 스킴이 `InboundLink.scheme` 과 같은지 ② `NSMessage` 가 실제로 있는 셀렉터를 가리키는지 ③ 판 번호가 `Version.swift` 와 같은지(CI 가 태그에서 세는 그 값) 확인한다.

받아 앉히기는 `MemoService.reconcile()` 첫 줄이다. 원본 파일은 정본이 새 자리에 앉은 뒤에 지운다 — 두 이름으로 남으면 다음 스캔에서 또 받아 앉혀 무한히 불어난다. 빈 파일은 받지도 지우지도 않는다(쓰다 만 것일 수 있다).

## 검증

`./scripts/test.sh` — **484개 통과** (앞 452 → 새 32개: Inbound 12, NoteReader 8, VaultAdoption 5, InboundDoor 4, 번들 짝 3). `./scripts/verify-mcp.sh` — **26항목** 통과(프롬프트 6항목 새로 추가, 「정리 프롬프트가 지우기 전에 묻게 되어 있는지」 포함). `./scripts/verify-notes.sh` 통과. `./scripts/build-app.sh` 로 번들을 짓고 등록된 스킴(`lazymemo`)·`NSMessage`(`addToLazyMemo`)·번들 안 CLI(`--version` → 0.1.0)를 직접 확인했다. 번들 2.6M → **2.8M**.

터미널에서 실제로 돌려 봤다 — `add "내일 3시 치과 @강남역"` 이 `at: 2026-09-01T15:00:00+09:00`, `place: 강남역`, 본문 `치과` 인 파일을 남긴다.

## 메모

URL 스킴이 **LaunchServices 를 거쳐 실제로 앱에 닿는 것**은 아직 못 봤다. `open lazymemo://…` 로 확인하려면 개발 번들을 시스템에 등록해야 하고, 그러면 임시 Vault 로 띄운 인스턴스가 아니라 등록된 다른 사본이 깨어나 **실제 메모 폴더에 쓸 위험**이 있다. 파싱·핸들러·plist 등록은 각각 시험했으니, 마지막 연결은 설치본에서 한 번 눌러 볼 것.