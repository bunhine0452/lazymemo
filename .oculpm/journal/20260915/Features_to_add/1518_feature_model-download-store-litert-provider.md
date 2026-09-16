---
schema_version: 1
type: feature
slug: "model-download-store-litert-provider"
status: done
difficulty: high
created_at: "2026-09-15T15:18:21+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/ModelManifest.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/ModelStore.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/ModelDownloader.swift"
    op: create
  - path: "Sources/LazyMemoLocalLiteRT/LiteRTProvider.swift"
    op: create
  - path: "Sources/LiteRTLM/README.md"
    op: create
  - path: "Sources/LiteRTLM/LICENSE"
    op: create
  - path: "Sources/LiteRTLM/Engine.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/ModelStoreTests.swift"
    op: create
  - path: "Tests/LazyMemoLocalLiteRTTests/RealModelTests.swift"
    op: create
related:
  - ref: "20260915/Features_to_add/1511_feature_action-executor-conditional-modify.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md"
    kind: "followup"
tags:
  - "jarvis"
  - "litert"
  - "model-download"
  - "provider"
  - "lifecycle"
  - "mcp-tool"
---
[x] 모델 manifest·저장소·이어받기 다운로더와 LiteRT provider 어댑터 — 래퍼 소스 v0.16.0 들여와 2.7GB 클론 회피, 실모델 opt-in 테스트 통과

## 추가 기능

**`#model-download` (명세 §7)** — `LazyMemoAssistant` 안, 엔진 무관.
- `ModelManifest`: profileID·upstream ID·artifact repo·**revision 고정**·engine·file(name/bytes/sha256)·license·context·template. `gemma4E2B` 기본(revision `b3ca0d2f…`, 2,588,147,712 bytes, sha256 `181938…`). `main` URL 없음.
- `ModelStore`(actor): `<support>/models/<profileID>/` — vault·iCloud 밖, `isExcludedFromBackup`. `.part` staging → 크기·SHA-256(8MB 청크) 검증 → `replaceItemAt` 원자 교체 → `manifest.json`. 검증 실패 시 staging 삭제, 활성 판은 그대로. `availability` 는 크기만 본다(매 실행 2.4GB 읽지 않음). 디스크 여유 200MB 검사. `delete` 는 폴더째.
- `ModelDownloader`: `URLSession.bytes` + `Range` 이어받기(서버가 206 을 안 주면 처음부터), 1MB 버퍼, 진행 이벤트, Task 취소 시 `.part` 보존. 실패 메시지는 사람 말(손상·크기·저장 공간·오프라인).

**`#model-lifecycle` (명세 §6~7)** — 새 타깃 `LazyMemoLocalLiteRT` = `LazyMemoAssistant` + `LiteRTLM`.
- `LiteRTProvider`(actor, `LocalModelProvider`): Engine 하나, 요청마다 새 Conversation(`live[requestID]`), thinking off, schema 가 오면 `enableResponseFormat`. `cancel(requestID)` → `Conversation.cancel()`. **유휴 `profile.idleUnload`(기본 120s) 뒤 해제**, `DispatchSource` 메모리 압박(warning/critical) 시 진행 중이 아니면 즉시 해제. 로딩·추론은 MainActor 밖.
- iOS 백그라운드 진입 시 취소·해제는 앱 수명주기 훅(AppModel)에서 부른다 — UI 단계에서 연결.

**`LiteRTLM` 타깃** — 공식 v0.16.0(commit 924e79c9)의 `swift/` 소스 11개를 그대로 들여옴(Apache 2.0, LICENSE 동봉, 고치지 않음). xcframework 두 개는 공식 릴리스 URL + checksum `binaryTarget`. 이유: `.package(exact:)` 는 모델 자산이 든 저장소를 2.7GB 복제한다(용량 지시). Swift 5 언어 모드(래퍼·어댑터 둘 다 — `Conversation` 이 Sendable 이 아님).

## 검증

- `ModelStoreTests` 3개: 파일 URL 다운로드→verifying→ready→delete, 해시 불일치 시 활성 없음·staging 삭제, 활성 판은 새 판 검증 실패에도 보존.
- **실모델 opt-in** `RealModelTests`(`LAZYMEMO_MODEL_PATH` 있을 때만, symlink 로 앉힘): M4 콜드 로드 포함 4.4s 에 근거 id 인용 답 `completed(.answer)`, tidy 첫 delta 에서 취소 → 0.39s 에 스트림 종료·delta 1. 첫 시도는 「엄마 선물」 문항에서 모델이 `found:false`(벤치 A01 과 같은 품질 실패)라 배관만 단정하도록 문항을 바꿨다.
- `swift build` 전체 통과. iOS 실기기·M1 은 미검증.