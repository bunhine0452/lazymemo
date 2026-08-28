---
schema_version: 1
type: feature
slug: "markdown-vault-and-sqlite-index"
status: done
difficulty: high
created_at: "2026-08-28T17:11:24+09:00"
session_id: "20260828-001"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/ULID.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/CalendarDate.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Timestamp.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Frontmatter.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: create
  - path: "Sources/LazyMemoCore/Model/MemoFile.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/SQLite.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoIndex.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/VaultWatcher.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoStore.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoFileTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoVaultTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoIndexTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/MemoStoreTests.swift"
    op: create
related: []
tags:
  - "storage"
  - "markdown"
  - "frontmatter"
  - "sqlite"
  - "fts5"
  - "trigram"
  - "ulid"
  - "trash"
  - "fsevents"
  - "data-layer"
  - "mcp-tool"
---
[x] 데이터 계층 — 마크다운 정본, 파생 SQLite 인덱스, 하드 삭제 없는 휴지통

플래너 `{#data-layer}` 의 네 항목(`{#memo-schema}` `{#storage-layout}` `{#sqlite-index}` `{#trash-safety}`)을 한 사이클로 끝냈다. 외부 의존성 0 — SQLite 는 시스템 libsqlite3 를 직접 쓴다.

## 추가 기능

**모델** — `ULID` · `CalendarDate` · `Timestamp` · `Frontmatter` · `Memo` · `MemoFile`.

**저장** — `MemoVault`(actor, 파일) · `MemoIndex`(actor, SQLite) · `VaultWatcher`(FSEvents) · `MemoStore`(@MainActor 파사드).

## 동작 흐름

쓰기는 항상 `MemoStore` → `MemoVault`(파일) → `MemoIndex`(통지) 순이다. 설계문서 §4 의 단방향 원칙을 배선으로 강제했다 — 인덱스에는 애초에 "쓰기" 공개 API 가 없고 파일에 쓴 결과를 통지받기만 한다.

## 설계 결정

**`due`/`at` 을 `Date` 하나로 합치지 않았다.** `due: 2026-09-01` 은 특정 순간이 아니라 달력 위의 칸이라 `Date` 로 담으면 타임존이 바뀔 때 하루씩 밀린다. 별도 `CalendarDate` 값 타입을 만들었다.

**파일 경로를 `created` 가 아니라 ULID 의 내장 타임스탬프에서 뽑는다.** `notes/2026/08/<ulid>.md` 의 연·월이 frontmatter 의 `created` 에서 나오면, 사용자가 그 값을 고치는 순간 앱이 파일을 잃는다. ULID 앞 10글자를 복호해 쓰면 경로가 id 의 순수 함수가 된다. (사용자가 파일을 직접 옮긴 경우에 대비해 전체 스캔 폴백은 남겨 뒀다.)

**frontmatter 파서는 YAML 파서가 아니다.** 목적이 "이해"가 아니라 "보존"이다. 아는 키만 해석하고 모르는 키는 **원문 줄을 그대로 보관했다가 그대로 되쓴다.** 설계문서 §5.2 의 "사용자가 직접 넣은 필드를 앱이 지우지 않는다"가 완전한 YAML 지원 없이 지켜진다. 정규식을 안 쓴 이유는 `Regex` 가 Sendable 이 아니라 static 상수로 둘 수 없기 때문 — 수동 분해가 더 싸기도 하다.

**삭제 시각을 인덱스가 아니라 파일 frontmatter(`deleted:`)에 쓴다.** 인덱스를 지워도 보존 기간 계산이 살아남아야 한다. `purgeExpired` 는 `deleted` 가 **없는** 휴지통 파일을 건드리지 않는다 — 사용자가 직접 넣어둔 파일일 수 있다.

**하드 삭제를 MCP 에 노출하지 않는다는 D6 을 규약이 아니라 배선으로 지켰다.** `MemoStore` 의 공개 삭제 API 는 `delete`(휴지통 이동)뿐이고, 하드 삭제는 `MemoVault.purgeExpired` 하나뿐이며 `MemoStore.start()` 안에서만 불린다.

## 새로 정한 것 — MCP 서버는 별도 프로세스다 (설계문서 §4 보강)

설계문서 §4 다이어그램은 MCPServer 를 앱 안에 그려 뒀지만, **stdio MCP 는 클라이언트가 프로세스를 띄우는 구조**라 Claude Desktop 이 lazymemo 앱 프로세스에 붙을 수 없다. 성립하는 형태는 `lazymemo-mcp` 실행 파일이 따로 뜨고 같은 Vault 를 직접 만지는 것이다.

D4(파일이 정본) 덕분에 이게 거의 공짜다 — 두 프로세스의 계약이 파일 그 자체다. 대가는 하나: **앱이 외부 변경을 알아야 한다.** `VaultWatcher`(FSEvents)를 넣었다. `notes/2026/08/` 처럼 하위 디렉터리까지 봐야 해서 vnode 감시로는 부족하다.

자기가 쓴 파일에 대한 감시 이벤트로 무한 루프가 도는 문제는 **mtime 대조로 자연히 해결됐다** — 앱이 저장하면서 인덱스 mtime 을 이미 갱신했으므로 뒤따라온 이벤트의 `reconcile` 은 할 일을 찾지 못한다. 무시 타이머가 필요 없다.

## 알아낸 것 1 — FTS5 trigram 은 한국어 두 글자를 못 찾는다

한글에 `unicode61` 토크나이저를 쓰면 부분 일치가 전혀 안 돼 `trigram` 을 골랐다. 실측 결과 `강남역`(3글자)은 찾지만 `남역`(2글자)은 **못 찾는다** — trigram 은 3글자 미만을 색인하지 않는다. `병원`·`약속` 같은 두 글자 검색은 한국어에서 매우 흔하므로, 3글자 미만은 LIKE 스캔으로 떨어뜨렸다. 메모 수백 장 규모에서는 전체 스캔이 문제되지 않는다.

LIKE 로 떨어지는 경로가 생긴 이상 `%`·`_`·`\` 이스케이프가 필요해져 함께 처리했다 (`search("%")` 가 전부를 반환하지 않는지 테스트로 고정).

## 알아낸 것 2 — index.sqlite 만 지우면 앱이 열리지 않았다

설계문서는 파생물을 "지워도 된다"고 약속하는데, `index.sqlite` 만 지우고 WAL 사이드카(`-wal`/`-shm`)를 남기면 sqlite 가 `disk I/O error(10)` 로 열리지 않았다. 테스트가 이걸 잡았다.

`MemoIndex.init` 이 열기·마이그레이션 실패 시 **사이드카까지 통째로 버리고 한 번 재시도**하도록 고쳤다. 인덱스는 파생물이니 고치려 들지 않는 것이 맞다.

## 검증

`./scripts/test.sh` — 48개 테스트 7개 스위트 전부 통과. 특히 세 가지를 테스트로 못 박았다.

- **§5.3 불변식**: `index.sqlite` 를 삭제한 뒤 새 `MemoStore` 를 만들어도 메모와 전문 검색이 그대로 복원된다.
- **외부 프로세스 쓰기**: 다른 경로로 Vault 에 쓴 파일을 `reconcile()` 이 집어온다 (MCP 별도 프로세스의 근거).
- **왕복 무손실**: 모르는 frontmatter 키(`mood`, `project`)가 디코드·인코드 후에도 남는다.