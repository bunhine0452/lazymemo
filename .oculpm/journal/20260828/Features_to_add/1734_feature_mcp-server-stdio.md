---
schema_version: 1
type: feature
slug: "mcp-server-stdio"
status: done
difficulty: high
created_at: "2026-08-28T17:34:32+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: update
  - path: "Sources/LazyMemoMCP/main.swift"
    op: create
  - path: "Sources/LazyMemoMCP/JSONRPC.swift"
    op: create
  - path: "Sources/LazyMemoMCP/MemoTools.swift"
    op: create
  - path: "Package.swift"
    op: update
  - path: "scripts/verify-mcp.sh"
    op: create
  - path: "scripts/install-mcp.sh"
    op: create
  - path: "scripts/build-app.sh"
    op: update
  - path: "Sources/LazyMemoCore/Model/Timestamp.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoVaultTests.swift"
    op: update
related: []
tags:
  - "mcp"
  - "json-rpc"
  - "stdio"
  - "claude-desktop"
  - "llm-safety"
  - "privacy"
  - "memo-service"
  - "mcp-tool"
---
[x] MCP 서버 — 별도 프로세스 stdio, 하드 삭제가 도달 불가능한 도구 표면

플래너 `{#llm}` 의 `{#mcp-server}` `{#mcp-events}` `{#mcp-onboarding}` `{#llm-safety}` 를 끝냈다. 외부 패키지 없이 JSON-RPC 2.0 을 직접 구현했다 — 표면이 요청/응답/오류 셋뿐이라 의존성을 들이면 오픈소스 빌드 문턱만 높아진다.

## 추가 기능

`MemoService`(공유 도메인 actor) · `LazyMemoMCP` 실행 타깃(`JSONRPC` · `MemoTools` · stdio 루프).

도구 6개: `list_memos` `create_memo` `update_memo` `delete_memo` `restore_memo` `list_trash`.

설계문서 §9.2 의 5개에 `list_trash` 를 더했다. `restore_memo` 만 있고 휴지통을 볼 수단이 없으면 되돌리기를 LLM 이 쓸 수 없다.

## 동작 흐름

Claude Desktop → stdio → `lazymemo-mcp` 프로세스 → `MemoService` → 마크다운 파일. 앱은 FSEvents 로 그 변경을 알아채고 화면을 갱신한다. 두 프로세스의 계약은 파일 그 자체다.

## 설계 결정

**`MemoService` 를 뽑아 앱과 MCP 가 공유한다.** 처음엔 MCP 서버가 `MemoVault` 와 `MemoIndex` 를 직접 쓰게 짰다가 되돌렸다 — 그러면 "파일 먼저, 그 다음 인덱스"와 "삭제는 휴지통 이동뿐"이 두 곳에 각각 구현된다. D6 같은 약속은 한 곳에만 있어야 지켜진다. `MemoStore`(@MainActor, 관찰 가능)는 이제 `MemoService` 위의 얇은 화면용 껍데기다.

**하드 삭제를 배선으로 막았다.** `MemoService` 에 하드 삭제 공개 API 자체가 없다 (`purgeExpiredTrash` 는 보존 기간이 지난 것만 지우고 앱만 부른다). 도구 목록에 없는 게 아니라 **호출할 함수가 없다.** 검증 스크립트가 도구 이름에 purge/permanently 가 없음을 확인한다.

**도구 오류를 JSON-RPC 오류로 돌려주지 않는다.** 잘못된 날짜나 없는 도구는 `isError: true` 결과로 돌려준다 — MCP 규약이기도 하고, 모델이 읽고 스스로 고칠 수 있어야 하기 때문이다. 프로토콜 오류(-32601)는 모르는 **메서드**에만 쓴다.

**프로토콜 버전은 클라이언트를 따라간다.** 우리가 쓰는 표면이 tools 뿐이라 버전 간 차이가 없다. 고정 문자열로 못 박는 것보다 클라이언트가 요청한 값을 되돌려주는 편이 오래 산다.

**이중 옵셔널로 "비우기"와 "건드리지 않기"를 가른다.** `update_memo` 에서 `due` 를 안 넘기면 보존, 빈 문자열을 넘기면 삭제. 설계문서 §9.2 의 "미지정 필드는 보존" 계약을 타입으로 표현했다.

**MCP 바이너리를 앱 번들 안에 넣는다.** `claude_desktop_config.json` 이 `.build/…` 를 가리키면 `swift build` 한 번, clean 한 번에 끊어진다. `dist/LazyMemo.app/Contents/MacOS/lazymemo-mcp` 가 안정적인 주소다.

## 알아낸 것 — 초 미만 정밀도가 파일 왕복에서 사라진다

`MemoStore` 를 `MemoService` 위로 옮기자 테스트 하나가 깨졌다. 예전에는 `update` 가 메모리의 `Memo` 를 고쳤는데 이제 파일에서 읽어 고친다. frontmatter 는 초 단위까지만 적으므로(사람이 읽을 파일이라 그렇다) `created` 가 왕복에서 밀리초를 잃고, 메모리와 디스크가 미묘하게 어긋났다.

정본이 파일인 이상 **모델이 파일보다 정밀한 값을 들고 있으면 안 된다.** `Memo.init` 에서 시각을 초 단위로 내림한다. 부수 효과로 같은 초 안의 수정은 `updated` 가 변하지 않는데, 이 형식이 보장할 수 있는 것은 "시각이 뒤로 가지 않는다"까지다. 재동기화는 `updated` 가 아니라 파일 mtime 을 보므로 영향이 없다.

## 프라이버시

기본 상태에서 lazymemo 는 네트워크를 쓰지 않는다. `scripts/install-mcp.sh` 로 Claude Desktop 에 등록하는 순간이 유일한 동의 지점이며, 스크립트 주석과 출력에 그 사실을 적었다. `--dry-run` 으로 바뀔 내용을 먼저 볼 수 있고, `--remove` 로 되돌릴 수 있으며, 기존 설정은 백업한다.

## 검증

`./scripts/verify-mcp.sh` — 임시 Vault 에 실제 JSON-RPC 대화를 흘려보내는 검증 15항목 전부 통과.

- initialize 핸드셰이크 / 도구 6개 노출 / **하드 삭제 도구 없음**
- 한글 전문 검색(`강남역`)이 생성한 메모를 찾음
- 날짜 범위 조회가 `at` 을 가진 메모만 돌려줌 (`{#mcp-events}`)
- 태그 필터
- 잘못된 날짜·없는 도구는 `isError`, 모르는 메서드는 -32601
- 알림(`notifications/initialized`)에는 응답하지 않음
- delete → list_trash → restore 왕복, 그리고 **정본 마크다운이 디스크에 그대로 남아 있음**

`./scripts/install-mcp.sh --dry-run` 으로 기존 설정의 다른 키를 건드리지 않고 `mcpServers.lazymemo` 만 추가함을 확인했다. **실제 등록은 사용자 결정이라 실행하지 않았다.**