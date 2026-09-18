---
schema_version: 1
type: bug
slug: "ios-litert-per-layer-embedding-null"
status: done
difficulty: high
created_at: "2026-09-18T16:50:47+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/Config/LazyMemo.entitlements"
    op: update
  - path: "Sources/LazyMemoLocalLiteRT/LiteRTProvider.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
related:
  - ref: "20260915/Features_to_add/1518_feature_model-download-store-litert-provider.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/1228_feature_assistant-web-search-ddg.md"
    kind: "followup"
tags:
  - "ios"
  - "litert"
  - "assistant"
  - "memory"
  - "entitlements"
  - "error-handling"
  - "mcp-tool"
---
[x] 폰 검색 오류 — Gemma 층별 임베딩 mmap 이 실패해 첫 prefill 에 넘어졌다: 넓힌 주소 공간 entitlement, 사람 말 오류, 웹 결과는 그대로 보임

## 발생 원인

사용자 화면(아이폰): `conversation(LiteRTLM.LiteRTLMError.ConversationError.invalidResponse("FAILED_PRECONDITION: Prefill requires per_layer_embedding_lookup_ when signature has input_per_layer_embeddings, but per_layer_embedding_lookup_ is null."))` — 검색(웹에서 찾기·메모에 묻기)이 그 자리에서 죽고, 기계의 말이 그대로 화면에 섰다.

LiteRT-LM v0.16.0 소스로 따라갔다(`llm_litert_compiled_model_executor.cc` 586 · `litert_compiled_model_executor_utils.cc InitializeEmbeddingLookups` · `litert_lm_loader.cc GetSectionBuffer`). `per_layer_embedding_lookup` 은 `.litertlm` 의 `TF_LITE_PER_LAYER_EMBEDDER` 절을 못 얻으면 **조용히 null** 로 남고 엔진은 「준비됨」이라 한다 — 그 절의 `mmap` 이 실패하면(`Failed to map section` 경고 한 줄) 그렇다. Gemma 4 E2B 의 층별 임베딩은 약 1.3GB 짜리 **이어진 주소 공간 하나**를 요구하는데, 아이폰의 기본 주소 공간은 앱이 조금만 오래 돌아(XNNPACK 가중치 패킹, Metal) 조각나면 그 자리가 없다 — 물리 메모리는 넉넉해도 `ENOMEM`. 같은 파일이 맥에서 되는 이유가 그것이다. 상류 이슈 google-ai-edge/LiteRT-LM#2545 가 같은 증상(iPhone 16 Pro, 빈 앱에서는 되고 큰 앱에서는 안 됨, CPU·GPU 둘 다)을 적어 두었고 답은 없다.

파일은 멀쩡하다 — `ModelStore.activate` 가 SHA-256 을 본다.

## 해결 방법

1. **`ios/Config/LazyMemo.entitlements`** 에 `com.apple.developer.kernel.extended-virtual-addressing`(넓힌 주소 공간 — 이어진 1.3GB 자리가 생긴다) 과 `com.apple.developer.kernel.increased-memory-limit`(2.6GB 모델을 8GB 폰에서 jetsam 앞에 두지 않게) 둘. 둘 다 App ID capability 라 자동 서명이 등록한다 — `xcodebuild build -destination generic/platform=iOS -allowProvisioningUpdates` 로 프로필이 새로 발급되고, 서명된 앱의 entitlements 에 둘 다 들어간 것을 `codesign -d --entitlements` 로 확인했다.
2. **`LiteRTProvider`**: `LiteRTLMError` 를 `AssistantFailure.provider(우리말 한 줄)` 로 — 「이 기기에서 모델이 자리를 잡지 못했습니다 — 한 번 더 해 보고, 그래도 안 되면 앱을 껐다 켜 주세요」. 원문은 stderr(`[litert]`). `isEngineBroken`(FAILED_PRECONDITION·null·engine 오류)이면 **엔진을 내린다** — 이 엔진으로는 백 번 해도 같고, 다시 올리면 mmap 을 한 번 더 시도한다.
3. **`Coordinator`**: `.webAnswer` 에서 모델이 넘어져도 이미 손에 있는 웹 결과를 버리지 않는다 — 모델 없는 기기와 같은 `plainWebAnswer` 로 결과 셋을 보인다. 메모 묻기(`.answer`)는 근거 목록이 이미 화면에 있으므로 메시지만 사람 말로.

## 검증

- `swift build` ✓ · `./scripts/test.sh` 956 전부 초록.
- 아이폰 기기 빌드(Release, 자동 서명) ✓ — 프로필에 두 entitlement 포함, 앱 서명에 둘 다 실림.
- **실기기 확인은 못 했다** — 이 맥에 아이폰이 연결돼 있지 않다. 다음 TestFlight 판에서: 웹에서 찾기 한 번, 메모에 묻기 한 번, 앱을 30분쯤 쓴 뒤 다시 한 번(주소 공간이 조각난 뒤가 재현 조건).

## 메모

- entitlement 가 안 먹는 폰(구형 iOS)에서는 2·3 이 남는다 — 결과 셋은 보이고, 메시지는 사람 말이고, 다음 부탁이 새 엔진으로 간다.
- 상류가 고치면(절을 못 얻었을 때 초기화를 실패시키거나 청크 mmap) 2 의 `isEngineBroken` 은 좁혀도 된다.
- 폰 실기기 게이트(`lazymemo-jarvis-local` #benchmark-phone)는 이 entitlement 를 넣은 판으로 해야 뜻이 있다.