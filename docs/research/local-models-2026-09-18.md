# lazymemo 개인 비서 — 로컬 모델 재조사 (사양 × 성능)

조사일: 2026-09-18 · 작성: claude-code · 이전 조사: [local-models-2026-09-15.md](local-models-2026-09-15.md) · 명세: [JARVIS_IMPLEMENTATION.md](../JARVIS_IMPLEMENTATION.md)

**질문:** 15 Pro(8GB)·M1(8GB)·peak ≤3GB·한국어라는 사양 안에서, Gemma 4 E2B 말고 *진짜* 더 나은 후보가 있는가.
**전제:** 여기 수치는 전부 남의 측정(대부분 iPhone 17 Pro·M4/M5)이다. 15 Pro·M1 합격은 명세 §8 실측으로만 정한다. 클라우드 구독 로그인(Claude/ChatGPT/Gemini)은 2026년 세 곳 모두 제3자 앱을 금지했으므로 후보가 아니다.

## 1. 결론 — 후보 6 + 시스템 모델 1

| 순위 | 모델 | 출시 | 총 파라미터 | 4bit 자산 | 엔진(Apple) | 라이선스 | 왜 |
|---|---|---|---|---|---|---|---|
| **A** | **LFM2.5-2.6B** (Liquid) | 2026-08-04 | 2.69B | MLX 4bit **1.52GB** | MLX Swift LM(`lfm2`), llama.cpp, Core ML ANE 변형 | LFM Open v1.0 — 연매출 $10M 미만 상업 무료 | 지시 따르기·도구 호출이 이 급에서 1위(IFBench 59.2 · Multi-IF 80.1 · ToolSandbox 77.8 — Gemma 4 E4B·Qwen3.5-4B 보다 위). 메모리 <2.5GB, 폰 30 tok/s. **한국어는 지원 목록에만 있고 측정치가 없다 — 유일한 위험** |
| **B** | **Gemma 4 E2B** (현 기본) | 2026-04 | 5.1B(유효 2.3B) | .litertlm 2.59GB | LiteRT-LM | Apache 2.0 | 17 Pro 에서 peak **497MB**·61 tok/s·에너지 최저 — 폰 사양 적합성은 1위. 약점은 지시·도구(IFBench 34.1 · ToolSandbox 52.4) — 우리 spike 벤치의 command 30~45% 와 일치. 한국어 자연스러움은 커뮤니티 평이 Qwen 보다 좋음 |
| C | Qwen3-4B-Instruct-2507 | 2025-07 | 4B | .litertlm 있음 · MLX 2.28GB | **LiteRT-LM 그대로**, MLX | Apache 2.0 | non-thinking 전용, IFEval 83.4·MMLU-Pro 69.6. 엔진 추가 없이 E2B 와 A/B 가능. 한국어 답에 한자 섞임 보고 |
| D | Gemma 4 E4B | 2026-04 | 8B(유효 4.5B) | .litertlm | LiteRT-LM | Apache 2.0 | E2B 대비 IFBench 39.2·ToolSandbox 65.0·MMMLU 76.6. 17 Pro 25 tok/s·TTFT 0.9s. Mac 16GB 옵션, 15 Pro 는 메모리 실측 뒤 |
| E | Mi:dm 2.0 Mini 2.3B (KT) | 2025-07 | 2.3B | GGUF Q4 ≈1.4GB | llama.cpp(Llama 계열) | **MIT** | 한국어 폴백: HAERAE 70.8·Ko-MTBench 74.0·LogicKor 7.7 (Qwen3-4B 50.6·63.0·5.6). 영어·추론은 약함(IFEval 73.6) |
| ✗ | Kanana-2-3B-instruct (카카오) | 2026-07-27 | ~3.4B | MLX 4bit 1.85GB | MLX(`qwen3` 구조) | **Kanana Open — §4.1(iii) on-device 임베딩 판매는 별도 상업 라이선스** | 한국어는 이 급 최강(KoMT-Bench 6.92 vs Qwen3.5-2B 5.21 · KoSimpleQA 22.3 vs 3.2 · BFCL-v3 71.9). **라이선스 협의 없이는 출하 불가**, 평가 기준선으로만 |
| ✗ | EXAONE 4.0 1.2B (LG) | 2025 | 1.2B | — | llama.cpp | NC(비상업) | 제외 |
| 별도 | **Apple Foundation Models — AFM 3 Core 3B** | OS 27 | 3B | 다운로드 0 | 시스템(FoundationModels) | 무료 | ctx 8,192 · 한국어 · 도구 호출 개선 · **guided generation(@Generable)이 부분 JSON 문제를 구조적으로 없앰** · 새 `LanguageModel` 프로토콜로 MLX/Core AI 모델을 같은 API 로 꽂을 수 있음. Apple Intelligence 켜진 기기만 |

**권고 실측 순서:** A(LFM2.5) vs B(E2B) 를 같은 한국어 fixture 로 먼저. LFM 이 한국어에서 무너지면 C(Qwen3-4B-2507/litertlm) 를 엔진 추가 없이 비교. 한국어 지식형 질문이 병목이면 E(Mi:dm). AFM 3 는 별도 spike 로 "다운로드 0·guided generation" 경로의 품질을 확인 — 이전 조사의 "오픈 모델 방향" 결정과 충돌하므로 사용자 판단.

## 2. 사양이 정하는 한계 — 공개 실측 (iPhone 17 Pro)

[apple-silicon-llm-bench](https://github.com/john-rocky/apple-silicon-llm-bench) (같은 하네스, 양자화 명시):

| 모델 | 런타임 | 양자화 | decode tok/s | peak 메모리 |
|---|---|---|---:|---:|
| Gemma 4 E2B | **LiteRT-LM** | QAT wNa8o8 | 61.1 | **497MB** |
| Gemma 4 E2B | MLX-Swift | PTQ 4bit | 49.1 | 3,010MB |
| Gemma 4 E2B | llama.cpp | Q4_K_M | 38.8 | 191MB(mmap, 가장 심하게 throttle) |
| Gemma 4 E2B | Core AI | INT4 | 47.1 | 755MB(표준 프로토콜에서 jetsam) |
| Qwen3.5-2B | MLX-Swift | 4bit | 61.2 | 1,279MB |
| Qwen3.5-2B | llama.cpp | Q4_K_M | 39.1 | 1,479MB |
| Qwen3.5-2B | CoreML/ANE | INT8 | 27.9 | 241MB |

- **지속 부하 10분 뒤 유지율(E2B):** LiteRT 48% · MLX 38% · ANE 67%. 명세 §8 "15분 반복 발열" 게이트는 burst 수치가 아니라 이 유지율로 갈린다.
- **E2B 는 MLX 로 돌리면 폰에서 3GB 예산을 넘는다** (총 5.1B 파라미터). E2B 는 LiteRT 전용으로 본다.
- 15 Pro 는 공개 측정이 없다. 대역폭 기준 17 Pro 의 ~2/3 로 가정하고 실측으로 대체한다 (E2B/LiteRT ≈40 tok/s, 2B/MLX ≈40 tok/s 추정치 — 약속 아님).
- Google 자체 표: E2B 17 Pro GPU 56 tok/s·TTFT 0.3s, E4B 25 tok/s·0.9s.
- LFM2.5-2.6B 자체 발표: 스마트폰 30 tok/s(기종 미상), M5 Max 220 tok/s, CPU 추론 <2.5GB. 하이브리드 conv 구조라 KV 캐시가 작고 prefill 이 빠르다 — 발열 게이트에 유리할 가능성.

## 3. 성능 근거

### 지시·도구 (Liquid 공개 표 — 같은 하네스에서 4개 모델 동시 측정)

| | LFM2.5-2.6B | Gemma 4 E2B | Gemma 4 E4B | Qwen3.5-4B |
|---|---:|---:|---:|---:|
| IFBench | **59.17** | 34.08 | 39.24 | 48.40 |
| Multi-IF | **80.07** | 69.44 | 77.35 | 55.67 |
| ToolSandbox | **77.83** | 52.40 | 65.00 | 75.55 |
| LiveCodeBench v6 | 59.41 | 54.92 | 63.77 | 60.85 |

Liquid 가 낸 표이므로 자사에 유리할 수 있다. 그래도 E2B 의 지시·도구 열세는 우리 spike 벤치(answer 46~62%·command 30~45%)와 방향이 같다.

### 한국어

| | Kanana-2-3B | Qwen3.5-2B | Mi:dm Mini | Qwen3-4B |
|---|---:|---:|---:|---:|
| KoMT-Bench(judge 0~10) / Ko-MTBench(KT, 0~100)* | **6.92** | 5.21 | 74.0* | 63.0* |
| KoSimpleQA | **22.29** | 3.21 | — | — |
| HAERAE | 43.75(CoT) | 27.84(CoT) | **70.8** | 50.6 |
| KMMLU | 43.32(CoT) | 41.75(CoT) | 45.1 | 50.6 |
| IFEval / Ko-IFEval | 80.96 / — | 66.91 / — | 73.6 / 73.3 | 79.7 / 75.9 |
| BFCL-v3 live | **71.94** | 66.96 | — | — |

- 출처가 둘(카카오 카드 = 앞 두 열 · KT 카드 = 뒤 두 열)이라 하네스가 다르다. 같은 출처의 열끼리만 비교한다. `*` 는 KT 하네스(0~100 척도).
- **Gemma 4·LFM2.5 의 한국어 수치는 없다.** Gemma 는 MMMLU(다국어 MMLU) E2B 67.4·E4B 76.6 뿐. 커뮤니티 평(dcinside 로컬LLM·arca)은 "한국어 글쓰기는 Qwen3.5 < Gemma 4", Qwen 은 한국어 중간에 한자가 섞인다.
- Kanana-2-3B 는 Qwen3.5-2B 보다 큰 모델(hidden 2560·32층·vocab 128K)이라 크기 대비 우위는 표보다 작다.

### 일반 (모델 카드)

| | Gemma 4 E2B | Gemma 4 E4B | Qwen3-4B-2507(non-think) | Qwen3.5-2B(non-think) | Qwen3.5-4B(카드, 모드 미구분) |
|---|---:|---:|---:|---:|---:|
| MMLU-Pro | 60.0 | 69.4 | 69.6 | 55.3 | 79.1 |
| IFEval | — | — | 83.4 | 61.2 | 89.8 |
| MMMLU | 67.4 | 76.6 | 64.9 | 56.9 | 76.1 |
| GPQA Diamond | 43.4 | 58.6 | 65.8 | 51.6 | 76.2 |

Qwen3.5-4B 는 thinking 을 끄면 큰 폭으로 내려간다(Liquid 표의 IFBench 48.4 vs 카드 59.2). 앱은 non-thinking 이므로 카드 수치를 믿지 않는다. 자산도 3.06GB(비전 인코더 포함 5B)라 15 Pro 예산에 걸린다 — 이전 조사대로 후순위.

## 4. 라이선스 — 출하 가능 여부

| 모델 | 라이선스 | 앱 배포 |
|---|---|---|
| Gemma 4 | Apache 2.0 (Gemma 3 의 커스텀 약관에서 바뀜) | 가능. 상표 "Gemma" 를 제품명에 쓰지 않음 |
| Qwen3 / 3.5 | Apache 2.0 | 가능 |
| LFM2.5 | LFM Open License v1.0 | 연매출 $10M 미만이면 상업 무료·고지 유지. 넘으면 Liquid 와 계약 |
| Mi:dm 2.0 | MIT | 가능 |
| Kanana-2 | Kanana Open License | §4.1(iii) "Offering or (re)selling to third parties Kanana Materials … embedded in on-device domains" 는 별도 상업 라이선스. §4.2 자체 서비스 운영은 허용 — 유료 앱에 모델을 내려받아 돌리는 것은 (iii) 로 읽는 것이 보수적. "Powered by Kanana" 표기 의무 |
| EXAONE 4.0 | EXAONE AI Model License 1.2 - NC | 불가 |
| HyperCLOVA X SEED 1.5B/3B | 자체 라이선스, 상업 허용 | 2025-04 판. Kanana-2 에 밀려 후보에서 뺌 |
| Apple AFM 3 | OS 기능 | 가능. Apple Intelligence 꺼진 사용자에겐 없음 → 폴백 필요 |

## 5. Apple Foundation Models 재평가 (OS 27)

이전 조사는 "오픈 모델 방향과 다르고 활성화 의존"이라며 필수 폴백에서 뺐다. 그 결정은 유지하되, WWDC26 에서 바뀐 것을 적어 둔다 — 결정을 다시 볼 근거다.

- 새 온디바이스 모델(AFM 3 Core 3B): **ctx 8,192**(`model.contextSize`), 논리·도구 호출 개선, 25개 언어(한국어 포함), 이미지 입력, 가드레일 오탐 감소.
- **guided generation**: `@Generable` 로 스키마를 주면 제약 디코딩으로 JSON 이 깨지지 않는다. 우리 실패 문항의 "없는 id 인용·잘린 JSON·필드 누락" 류가 구조적으로 사라진다(의미 정확도는 별개).
- **`LanguageModel` 프로토콜**: `CoreAILanguageModel`·`MLXLanguageModel` 이 오픈소스로 나옴 — 앱을 이 API 에 맞춰 짜면 시스템 모델과 오픈 모델(LFM/Qwen/MLX)을 같은 코드로 갈아끼운다. 명세 §7 의 "LanguageModelSession 공통화 여부는 SDK27 컴파일 후 결정" 항목이 이것.
- 부수: Spotlight 검색 도구(로컬 RAG), 평가 프레임워크, `fm` CLI(macOS 27), Python SDK.
- PCC(서버) 모델: ctx 32K·reasoning·2M 다운로드 미만 앱 무료·키/로그인 없음. **원문을 원격으로 보내지 않는다는 명세 §7 규칙과 충돌** — 후보로 넣지 않고 사실만 적는다.
- 모르는 것: 15 Pro·M1 에서의 실제 속도, 한국어 품질의 공개 수치(Apple 은 지역 묶음 human eval 만 공개), 앱 프로세스 밖에서 도는 메모리 회계.

## 6. 다음 세션이 할 일

1. `spikes/` 에 MLX 경로로 `mlx-community/LFM2.5-2.6B-4bit`(1.52GB) 를 받아 E2B 와 같은 fixture(`Tests/Fixtures/Assistant`)를 돌린다 — 파일 하나만, `~/Library/Caches/lazymemo-models/`. 결과는 `local-model-benchmark-2026-MM-DD-lfm25.md`.
2. 한국어에서 LFM 이 미달이면 `litert-community/Qwen3-4B-Instruct-2507` 을 같은 LiteRT 엔진으로 — 자산 크기 먼저 확인.
3. Kanana-2 는 **평가 기준선**으로만 돌린다(출하 후보 아님). 한국어 상한을 알기 위해.
4. AFM 3 spike 는 사용자가 "시스템 모델도 본다" 고 정할 때만.
5. 실측은 15 Pro·M1 실기기에서. 17 Pro·M4 수치를 옮겨 적지 않는다.

## 출처

- Liquid AI — [LFM2.5-2.6B 블로그](https://www.liquid.ai/blog/lfm2-5-2-6b) · [모델 카드](https://huggingface.co/LiquidAI/LFM2.5-2.6B) · [LFM Open License](https://www.liquid.ai/lfm-license) · [mlx-community 4bit](https://huggingface.co/mlx-community/LFM2.5-2.6B-4bit)
- Google — [Gemma 4 model card](https://ai.google.dev/gemma/docs/core/model_card_4) · [Apache 2.0 전환](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html) · [litert-community](https://huggingface.co/litert-community)
- [apple-silicon-llm-bench (john-rocky)](https://github.com/john-rocky/apple-silicon-llm-bench) · [iPhone 런타임 비교 글](https://rockyshikoku.medium.com/local-llm-on-iphone-which-runtime-is-actually-fastest-58096685481e)
- Qwen — [Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) · [Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B)
- 카카오 — [kanana-2-3b-instruct](https://huggingface.co/kakaocorp/kanana-2-3b-instruct) · [LICENSE](https://huggingface.co/kakaocorp/kanana-2-3b-instruct/raw/main/LICENSE) · [보도자료](https://www.kakaocorp.com/page/detail/11854)
- KT — [Midm-2.0-Mini-Instruct](https://huggingface.co/K-intelligence/Midm-2.0-Mini-Instruct) · [기술 보고서](https://arxiv.org/abs/2601.09066)
- LG — [EXAONE-4.0-1.2B](https://huggingface.co/LGAI-EXAONE/EXAONE-4.0-1.2B) (NC 라이선스)
- Apple — [AFM 3 소개](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models) · [WWDC26 What's new in Foundation Models](https://developer.apple.com/videos/play/wwdc2026/241/)
- [mlx-swift-lm supported models](https://github.com/ml-explore/mlx-swift-lm/blob/main/skills/mlx-swift-lm/references/supported-models.md)
- 한국어 커뮤니티 평 — [dcinside 로컬LLM](https://m.dcinside.com/board/localllm/31) · [arca gemma4/qwen3.5 비교](https://arca.live/b/alpaca/166717707) · [bibitlabs E4B vs 9B](https://bibitlabs.com/gemma4-e4b-vs-qwen3-5-9b-%eb%a1%9c%ec%bb%ac-llm%ec%9d%84-%ed%95%9c%eb%8b%ac-%ec%8d%a8%eb%b3%b8-%ec%86%94%ec%a7%81%ed%95%9c-%ed%9b%84%ea%b8%b0/)
