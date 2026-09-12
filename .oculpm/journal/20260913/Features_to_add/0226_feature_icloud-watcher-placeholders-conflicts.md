---
schema_version: 1
type: feature
slug: "icloud-watcher-placeholders-conflicts"
status: done
difficulty: medium
created_at: "2026-09-13T02:26:03+09:00"
session_id: "20260913-001"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Storage/VaultWatcher.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/ConflictSettlement.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/MemoVault.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/MemoService.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/ConflictSettlementTests.swift"
    op: create
related:
  - ref: "20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md"
    kind: "followup"
tags:
  - "ios"
  - "icloud"
  - "storage"
  - "sync"
  - "conflict"
  - "mcp-tool"
---
[x] iCloud 위에서도 정본이 정직하다 — 폰의 감시자, 안 내려온 파일, 충돌은 휴지통으로

## 추가 기능

파일이 정본(D4)이라는 약속을 iCloud 컨테이너 위에서도 지키기 위한 셋. 전부 Core 라 맥의 「iCloud 로 동기화」에서도 그대로 쓴다.

- **폰의 `VaultWatcher`** — FSEvents 자리에 `NSMetadataQuery`(`NSMetadataQueryUbiquitousDocumentsScope`, `*.md`). 첫 목록(`DidFinishGathering`)과 갱신(`DidUpdate`)을 받아 감시 폴더 안의 경로만 `handler` 로 넘긴다 — `MemoStore` 는 맥과 같은 배선으로 전체 대조. 로컬 폴백이면 질의가 아무것도 못 찾는데, 그때의 폰은 쓰는 주체가 앱 하나라 들을 것도 없다.
- **안 내려온 파일** — iCloud 는 목록만 먼저 주고 내용은 열 때 가져온다. 그 자리의 숨은 `.md.icloud` 는 `MemoVault.scan` 이 건너뛰므로 우리가 청하지 않으면 그 메모는 화면에 **없다.** 감시자가 보이는 족족 `startDownloadingUbiquitousItem` 을 청하고, 내려오면 `DidUpdate` 가 다시 돈다. 별도 클래스를 두지 않았다 — 목록을 받는 곳이 곧 청하는 곳이다.
- **충돌** — `ConflictSettlement.settle(current:others:)`: `updated` 가 늦은 판본이 자리를 지키고, 진 판본은 **새 ULID + `deleted` 로 휴지통에** 간다(되돌리기 가능, D6). 글이 같으면 충돌이 아니다(시각만 다른 판본은 흔하다). 시각이 같으면 자리에 있는 쪽 — 이유 없이 파일을 다시 쓰지 않는다. `MemoVault.settleConflicts` 가 `NSFileVersion.unresolvedConflictVersionsOfItem` 을 돌며 적용하고 `isResolved`·`removeOtherVersionsOfItem` 으로 iCloud 에 알린다. `MemoService.reconcile` 이 `adopt` 다음에 부른다.
- **`vault.retire(_:)`** — 휴지통에 **바로** 앉힌다. 바탕화면을 거치면 같은 메모가 잠깐 둘로 보인다.

## 동작 흐름

- `NSFileCoordinator` 는 **안 붙였다.** 원자적 쓰기는 임시 파일 + 이름 바꾸기라 iCloud 가 반쪽을 볼 수 없고, iCloud 가 내려놓는 쪽도 같은 방식이라 우리가 반쪽을 읽을 일이 없다. 겹치면 판본이 하나 더 생기는 것이 최악이고 그건 위 정리가 받는다. `MemoVault.save` 에 `oculpm-defer` 로 재방문 트리거(실기기 왕복에서 유실·충돌 보고)를 적어 뒀다.
- `NSFileVersion.url` 은 옵셔널이 아니다 — 처음 `guard let` 으로 썼다가 컴파일러가 잡았다.

## 검증

- `ConflictSettlementTests` 7건 신설 — 늦은 판본 승리, 진 판본의 새 id·deleted·글 보존, 동시각은 자리 쪽, 같은 글은 무시, 셋 중 둘 다 남음(id 겹침 없음), 휴지통 직행이 `trashedMemos` 에 보이고 `loadAll` 에는 없음, 보통 파일은 손대지 않음.
- 맥 371 / iOS 시뮬레이터 353 전부 통과. Core iOS 빌드 성공.
- 진짜 iCloud 충돌·다운로드는 시뮬레이터에 iCloud 가 없어 여기서 못 본다 — `release-device` 손검증 항목이 받는다.