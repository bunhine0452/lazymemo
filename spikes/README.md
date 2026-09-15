# spikes — 로컬 모델 검증 (명세 §7·§8)

제품 타깃(`Package.swift`)과 **분리된** 독립 SwiftPM 패키지들이다. LazyMemoCore·MCP·Share Extension 은
추론 엔진을 링크하지 않는다. 여기서 확인한 것만 제품 어댑터로 옮긴다.

| 패키지 | 역할 | 의존 |
|---|---|---|
| `SpikeKit` | fixture 읽기·채점·속도/메모리 기록·보고서. 엔진 무관 | 없음 |
| `LiteRTSpike` | `litert-spike` CLI — Gemma 4 E2B/LiteRT-LM 로딩·스트리밍·취소·벤치 | LiteRT-LM **v0.16.0 고정** |
| `MLXSpike` | `mlx-spike` CLI — Qwen3-4B-Instruct-2507/MLX 비교 경로 | mlx-swift-lm **3.31.4 고정** |

## 가중치 — 저장소 밖, 파일 하나만

용량을 아끼려고 저장소 전체를 받지 않는다. 기본은 `gemma-4-E2B-it.litertlm` **하나**다.

```sh
mkdir -p ~/Library/Caches/lazymemo-models && cd ~/Library/Caches/lazymemo-models
curl -L -C - -o gemma-4-E2B-it.litertlm \
  "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1/gemma-4-E2B-it.litertlm"
shasum -a 256 gemma-4-E2B-it.litertlm   # 181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c · 2,588,147,712 bytes
```

지우려면 그 폴더를 지우면 된다. iCloud·백업·vault 와 무관하다.

## 돌리기

```sh
cd spikes/LiteRTSpike
swift run -c release litert-spike smoke --model ~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm
swift run -c release litert-spike bench \
  --model ~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm \
  --fixtures ../../Tests/Fixtures/Assistant \
  --device "M4 Pro 24GB · macOS 27.0" \
  --out ../../docs/research/local-model-benchmark-$(date +%F).md
```

- `smoke`: 로드 → 한국어 스트리밍 → 첫 글자 뒤 300ms 취소 → 해제 → 재로드. 취소 뒤 delta 수와 멈추기까지 시간을 찍는다.
- `bench`: `--repeat N`(전체 suite 반복, 매번 재로드 → cold 측정), `--speed-repeat 3`, `--kinds answer,command`, `--no-speed`, `--no-quality`, `--verbose`.
- 보고서의 숫자는 **그 기기의 값**이다. iPhone 15 Pro·M1 8GB 가 아니면 §8 게이트 판정에 쓰지 않는다.

## fixture — `Tests/Fixtures/Assistant/`

`spikes/fixtures/make_fixtures.py` 가 만든다 (seed 고정). 사용자 실제 메모를 넣지 않는다.

- `memos.json` 143장: 닻 메모(질문의 정답)·오늘 메모(브리핑)·지시가 든 메모·다듬기 원문·채움 메모.
- `questions.json` 80문항. 명세 §8 표와의 대응: 검색 답변 20(A), 단일 도구 20(C), 다듬기 10(T), 브리핑 10(B),
  모호/충돌/근거 없음 10(X — 근거 없음·충돌은 kind `answer`), 메모 속 지시/취소/중복 10(S — 하나는 kind `answer`).
  각 문항은 근거 후보(`candidates`)를 정답+오답으로 넘긴다. **검색(Recall@6)은 여기서 재지 않는다** — 그건 FTS 위의 `#evidence-retrieval` 몫.
- `speed.json` 10개: 1K×4·2K×3·4K×3 목표 입력. 목표는 글자 수 추정이고 실제 토큰은 runner 가 엔진 tokenizer 로 세어 보고서에 적는다.

## 아직 안 한 것

- iPhone 15 Pro·M1 8GB 실기기 측정 (`#benchmark-phone`, `#benchmark-m1`). iOS 는 이 CLI 를 그대로 못 돌리므로
  SpikeKit 을 링크한 얇은 호스트 앱이 필요하다.
- MLX/Qwen 가중치는 받지 않았다 (약 2.3GB). 비교가 필요할 때 `MLXSpike/README` 의 명령으로 받는다.

## 첫 결과 (2026-09-15 · M4 Pro 24GB · 참고용)

`docs/research/local-model-benchmark-2026-09-15.md`(temp 1.0), `…-temp03.md`(temp 0.3). 속도는 넉넉하고(warm TTFT 1K 0.29s·decode ≈105 tok/s),
다듬기는 통과, **도구 요청·모호함·메모 속 지시·브리핑은 게이트 미달**. 1회 측정이라 다음 실험 방향으로만 읽는다:
ResponseFormat JSON schema 제약 디코딩, 브리핑 출력 상한, 날짜 계산을 앱 파서로 넘기는 계약, Qwen3-4B 비교.

`--schema`(JSON schema 제약 디코딩, `…-schema.md`): kind 가 allowlist 밖으로 새는 일은 사라졌고 ambiguous 0→57%, brief 50→60%.
그러나 answer 는 46% 로 오히려 내려갔다(스키마 안에서 `found:false` 로 도망치거나 `id:` 접두어를 붙임), 상대 날짜(「금요일」「다음 주 월요일」)는 여전히 틀린다.
제약 디코딩은 **구조**를 보장하지 **뜻**을 보장하지 않는다 — 명세 §8 「정확도 실패를 JSON 파싱 성공으로 대체하지 않는다」 그대로.
앱 쪽(`LazyMemoAssistant`)은 `id:` 접두어를 걷고 없는 id 를 버리며, 날짜 계산은 다음 실험에서 `NaturalDateParser` 로 넘긴다.

## 제품 쪽으로 옮겨 간 것 (2026-09-15)

`LazyMemoAssistant`(계약·Coordinator·검증·실행기·모델 저장/다운로드), `LazyMemoLocalLiteRT`(provider), `LazyMemoAssistantUI`(화면).
실모델 배관 테스트: `LAZYMEMO_MODEL_PATH=~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm ./scripts/test.sh --filter RealModelTests`.

## 이제 기준은 앱 파이프라인 벤치다 (2026-09-15 저녁)

이 spike 벤치는 **모델의 날 출력**을 채점한다. 그런데 제품은 모델의 말을 그대로 쓰지 않는다 — 검색(`MemoRanker`)이 근거를
모으고, 날짜·대상·동사는 앱(`CommandResolver`·`NaturalDateParser`)이 정하며, 모델의 JSON 은 검증(`OutputValidator`)을 지난다.
그래서 지시문도 갈라졌다: `SpikeKit/Prompts.swift` 는 날 모델 기준선이고, 제품 지시문은 `Sources/LazyMemoAssistant/Prompts.swift` 다.
**사용자가 받는 결과**는 메인 패키지의 벤치로 잰다:

```sh
swift run -c release lazymemo-assistant-bench \
  --model ~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm \
  --device "M4 Pro 24GB · macOS 27.0" \
  --out docs/research/local-model-benchmark-$(date +%F)-app.md
```

- 기본은 fixture 의 후보를 근거로 넘긴다(spike 와 같은 조건). `--retrieval` 이면 앱의 검색으로 근거를 모은다 — 실제 앱과 같은 길.
- `--retrieval-only` 는 모델 없이 검색 Recall@6 만. 같은 검사가 `swift test` 의 `RetrievalTests` 에도 있다.
- `--kinds answer,command` · `--temperature 0.3` · `--verbose`.
- 결과: `docs/research/local-model-benchmark-2026-09-15-app.md`.
