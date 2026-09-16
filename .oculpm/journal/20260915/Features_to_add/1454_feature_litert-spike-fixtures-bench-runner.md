---
schema_version: 1
type: feature
slug: "litert-spike-fixtures-bench-runner"
status: done
difficulty: high
created_at: "2026-09-15T14:54:10+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched:
  - path: "spikes/SpikeKit/Package.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/TextGenerator.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Footprint.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Fixtures.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Prompts.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Scoring.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Bench.swift"
    op: create
  - path: "spikes/SpikeKit/Sources/SpikeKit/Report.swift"
    op: create
  - path: "spikes/LiteRTSpike/Package.swift"
    op: create
  - path: "spikes/LiteRTSpike/Sources/LiteRTSpike/LiteRTGenerator.swift"
    op: create
  - path: "spikes/LiteRTSpike/Sources/LiteRTSpike/Smoke.swift"
    op: create
  - path: "spikes/LiteRTSpike/Sources/LiteRTSpike/main.swift"
    op: create
  - path: "spikes/MLXSpike/Package.swift"
    op: create
  - path: "spikes/MLXSpike/Sources/MLXSpike/MLXGenerator.swift"
    op: create
  - path: "spikes/MLXSpike/Sources/MLXSpike/main.swift"
    op: create
  - path: "spikes/MLXSpike/README.md"
    op: create
  - path: "spikes/README.md"
    op: create
  - path: "spikes/fixtures/make_fixtures.py"
    op: create
  - path: "Tests/Fixtures/Assistant/memos.json"
    op: create
  - path: "Tests/Fixtures/Assistant/questions.json"
    op: create
  - path: "Tests/Fixtures/Assistant/speed.json"
    op: create
  - path: "docs/research/local-model-benchmark-2026-09-15.md"
    op: create
  - path: "docs/research/local-model-benchmark-2026-09-15-temp03.md"
    op: create
  - path: ".gitignore"
    op: update
related:
  - ref: "20260915/Chores/1448_chore_jarvis-device-toolchain-check.md"
    kind: "followup"
  - ref: "20260915/Chores/1421_chore_jarvis-local-models-handoff.md"
    kind: "followup"
tags:
  - "jarvis"
  - "litert"
  - "benchmark"
  - "fixtures"
  - "spike"
  - "mcp-tool"
---
[x] LiteRT-LM v0.16.0/E2B 맥 spike·한국어 80문항 fixture·벤치 runner — M4 참고 측정에서 속도는 넉넉, 도구·모호함 품질은 게이트 미달

## 추가 기능

제품 `Package.swift` 와 분리된 `spikes/` 아래 세 패키지.

- **SpikeKit** (엔진 무관): `TextGenerator` 계약(load/unload/generate 스트리밍/cancel), fixture Codable, task 별 지시문, 종류별 채점기(JSON 추출·id 허용 목록 대조·필드 patch 비교·clear/미변경 구분·`*` 와일드카드), 속도/메모리 기록, 마크다운 보고서(§8 게이트를 표에 나란히).
- **LiteRTSpike** — `litert-spike` CLI, LiteRT-LM **v0.16.0 exact**. `smoke`(로드→한국어 스트리밍→첫 글자 뒤 300ms 취소→해제→재로드), `bench`(fixture 전체). thinking off, 요청마다 새 Conversation, 4096 컨텍스트, 엔진 benchmark 플래그로 prefill/decode 수치 수집.
- **MLXSpike** — Qwen3-4B-Instruct-2507/MLX 비교 경로, mlx-swift-lm **3.31.4 exact**. 3.31.4 공개 시그니처를 보고 썼으나 **이 세션에서 컴파일하지 않았다**(mlx-swift 빌드·가중치 2.3GB — 용량 때문에 미룸). README 에 revision 고정 다운로드 명령.
- **fixture** `Tests/Fixtures/Assistant/` — `spikes/fixtures/make_fixtures.py`(seed 고정)가 생성. 메모 143(닻 27·지시 포함 6·다듬기 원문 10·오늘 12·채움 88), 문항 80(A20/C20/T10/B10/X10/S10 — 명세 §8 표 대응, 근거 없음·충돌·인젝션 답변은 kind `answer`), 속도 프롬프트 10(1K×4·2K×3·3.5K×3; 4096 상한이 출력을 포함하므로 4K 대신 3584). 검색 Recall@6 은 여기서 재지 않는다 — FTS 위 `#evidence-retrieval` 몫.

## 동작 흐름

`bench`: 로드(시간·footprint) → 속도 프롬프트 × 3(첫 프롬프트의 첫 회를 cold) → 80문항 순차(구조 오류만 한 번 교정 재시도, 명세 §3) → 해제 → 수명 peak footprint. 엔진 오류는 문항 실패로 기록하고 계속 간다(첫 실행에서 4K 프롬프트가 컨텍스트 초과로 죽어 고침).

## M4 Pro 24GB 참고 측정 (게이트 판정용 아님)

- smoke: 로드 0.3s(페이지 캐시 warm), 취소 → 스트림 종료 0.01s, 취소 뒤 delta 1개, 해제 뒤 footprint 130MB, 재로드 0.26s.
- 속도: warm TTFT 1K 0.29s · 2K 0.59s · 3.5K 1.10s, decode ≈105 tok/s, cold TTFT 0.34s, 프로세스 peak 1.1GB. **주의:** 가중치가 mmap 파일 페이지라 phys_footprint 에 잡히지 않는다. M1 8GB 판정에는 Instruments/메모리 압박 관찰이 따로 필요하다.
- 품질(temp 1.0 / 0.3, 각 1회): tidy 100%/90% · answer 62%/50% · command 30%/45% · brief 50%/30% · ambiguous 0%/14% · safety 44%/44%. **모든 게이트 미달(tidy 1.0 만 통과).**
  - 반복되는 패턴: kind 를 allowlist 밖 이름(`surface`·`move`·`patch`·`delete`)으로 냄, createMemo 에 `at`/`due` 누락, 「금요일」「다음 주 월요일」계산 오류, 모호한 요청을 되묻지 않고 실행, 「취소」·「전부 지워」에 실행/다중 JSON, id 앞에 `id:` 붙임, brief 는 192 토큰에 JSON 이 잘려 파싱 실패.
  - 1회 측정이라 분산이 크다(§8 은 3회). 결론이 아니라 다음 실험의 방향: ResponseFormat JSON schema(enum kind) 제약 디코딩, brief 출력 상한 재검토, 날짜 계산은 앱의 기존 파서로 넘기고 모델은 상대 표현만 내게 하는 계약, Qwen3-4B 비교.

## 용량

가중치 2.4GB(파일 하나) + LiteRT 캐시 0.8GB + spike 빌드 3.6GB(그중 git 미러 2.7GB). 전역 SwiftPM 미러 복사본 2.7GB 는 지웠다. 여유 80GB.

## 검증

- `swift build -c release` 통과(경고 0), `smoke`·`bench` 실행 완료, 보고서 두 개 생성 `docs/research/local-model-benchmark-2026-09-15*.md`.
- `make_fixtures.py` 재실행 시 동일 파일. 문항 80·종류 분포 assert.
- iOS 로딩·취소, M1 8GB, Qwen/MLX 는 **미검증**.