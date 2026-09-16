# lazymemo 개인 비서 — 기기별 로컬 모델 조사

조사일: 2026-09-15 · 작성: codex · 구현 인계: [JARVIS_IMPLEMENTATION.md](../JARVIS_IMPLEMENTATION.md)

## 1. 결론과 확실성

**iPhone 15 Pro와 M1부터의 Mac 모두 Gemma 4 E2B IT + LiteRT-LM Metal을 기본으로 추천한다.** 사용자가 조사 도중 “M1 사용자부터 이용할 수 있도록 더 가벼운 모델”을 요청해, Mac 기본을 9B에서 E2B로 변경했다. **M1·8GB를 최소 검증 구성으로 선택**한다. 이는 공식 배포물·엔진 지원·메모리 부담을 함께 고려한 설계 선택이다. 두 기기에서 lazymemo 한국어 업무를 직접 돌린 최종 우승 모델이라는 뜻은 아니다. 출하 모델은 구현 명세의 실측 게이트를 통과한 뒤 고정한다.

| 환경 | 1순위 모델·엔진 | 대안 | 추천 이유 — 설계 판단 |
|---|---|---|---|
| 사용자의 iPhone 15 Pro | `google/gemma-4-E2B-it`, 공식 LiteRT용 배포물, LiteRT-LM Metal | 한국어 품질 부족 시 Qwen3-4B-Instruct-2507 4bit/MLX; 그다음 Qwen3.5-4B 4bit/MLX | 폰에서는 지속 추론보다 짧은 응답·발열·메모리 회수가 중요하다. 실제 iOS용 공식 Swift 경로와 모바일 최적화 자료가 있는 조합을 먼저 검증 |
| Mac: M1·8GB부터 | `google/gemma-4-E2B-it`, LiteRT-LM Metal | 한국어 품질 부족 시 Qwen3-4B-Instruct-2507/MLX를 같은 자원 예산에서 비교 | 최소 기기에서도 가벼운 대기·응답을 우선. 폰과 모델/엔진을 공유해 배포와 검증 단순화 |
| Mac: 16GB 이상, 후속 선택 옵션 | Gemma 4 E4B IT/LiteRT-LM | E2B 유지 | E2B보다 유의미한 품질 개선과 메모리 합격이 확인될 때만 제공. 자동 다운로드/자동 상향하지 않음 |

확인된 환경: 로컬 명령으로 Mac 칩·24GB·macOS 27.0 확인. 활성 `xcodebuild`는 **26.6**이다. 아이폰 기종은 사용자가 15 Pro라고 확인했으며 iOS 버전·가용 저장 공간·앱 메모리 한도는 아직 측정하지 않았다. 장치 일련번호 등은 기록하지 않는다.

## 2. 실제 배포물

| 용도 | 다운로드 위치 / 자산 | 조사 시 표시 크기 | 주의 |
|---|---|---|---|
| iPhone·Mac 기본 | [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/main)의 **`gemma-4-E2B-it.litertlm`** | 약 2.59GB | 저장소 전체는 여러 하드웨어 변형으로 27.3GB다. 파일 하나만 선택. `-gpu` 변형은 별도 실측 뒤 교체 |
| 비교 조사만, 기본 제외 | [mlx-community/Qwen3.5-9B-4bit](https://huggingface.co/mlx-community/Qwen3.5-9B-4bit/tree/main) | 저장소 약 5.98GB | 사용자의 M1·경량화 요구로 기본 및 필수 벤치에서 제외 |
| 폰 대안 | [mlx-community/Qwen3-4B-Instruct-2507-4bit](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit/tree/main) | 약 2.28GB | non-thinking 전용 |
| 품질 미달 시 추가 비교 | [mlx-community/Qwen3.5-4B-4bit](https://huggingface.co/mlx-community/Qwen3.5-4B-4bit/tree/main) | 약 3.06GB | 생각 모드 해제 후 별도 평가 |
| 제한 기능 후보 | [mlx-community/Qwen3.5-2B-4bit](https://huggingface.co/mlx-community/Qwen3.5-2B-4bit) | 모델 페이지 약 1.72GB | 작다는 이유로 도구 실행 담당에 자동 채택하지 않음 |

크기는 다운로드 자산의 표시값이며 **프로세스의 최대 메모리가 아니다**. 런타임·캐시·입력 길이·사진·앱 UI가 추가된다. 구현 세션은 저장소 revision 전체 SHA와 자산별 SHA-256·바이트 수를 manifest에 고정한다. `main` URL을 출하 manifest에 넣지 않는다. 이번 조사에서는 가중치를 내려받거나 해시를 검증하지 않았다.

## 3. 후보 비교

### A. Gemma 4 E2B — iPhone·Mac 공통 1순위

Google의 [2026-09-04 LiteRT-LM 자료](https://developers.google.com/edge/litert-lm/models/gemma-4)는 E2B의 iPhone **17 Pro** GPU 측정으로 decode 56 tok/s, 첫 토큰 0.3초를 싣는다. E4B는 같은 표에서 25 tok/s, 0.9초다. 이 수치는 **15 Pro 측정값도, lazymemo 응답 시간도 아니다**. 표의 Peak CPU Memory 역시 GPU를 포함한 앱 전체 물리 메모리와 같지 않다. 폰의 시작 후보를 E2B로 정하는 근거이지 속도 약속은 아니다.

[원본 모델 카드](https://huggingface.co/google/gemma-4-E2B-it)에 따르면 E2B는 2.3B effective지만 embeddings를 포함하면 5.1B다. E4B도 4.5B effective/8B total이다. 따라서 `E2B × 0.5byte`로 파일 크기를 계산하면 틀린다. 한국어 메모의 사람 이름·금액·날짜 보존과 도구 인자 정확도는 직접 평가해야 한다.

[Google 메모리 표](https://ai.google.dev/gemma/docs/core)는 E2B의 일반 Q4와 LiteRT 모바일 경로를 구분한다. 모바일 최적화 수치를 MLX/GGUF에 그대로 적용하지 않는다. 모델 규모가 작아 복잡한 여러 단계 작업을 맡기기보다 검색·짧은 답변·한 번의 명시적 변경에 사용한다.

### B. Qwen3.5 9B — 조사했으나 Mac 기본에서 제외

[공식 카드](https://huggingface.co/Qwen/Qwen3.5-9B)는 9B·다국어·도구 사용 및 기본 thinking 동작을 설명한다. 약 6GB인 실제 MLX 배포물은 현재 24GB Mac에서는 후보였으나 M1·8GB 사용자에게 OS/다른 앱과 함께 상주시키기에는 기본 자산부터 크다. 사용자의 경량화 요구를 반영해 제외했다. 실행 가능성과 제품 기본으로 적합함은 별개다.

앱 기본은 non-thinking, 짧은 문맥이다. 카드의 일반 벤치마크를 짧은 문맥·4bit·한국어·non-thinking 성능으로 간주하지 않는다. 생각 모드를 끈 뒤에도 검색 근거 연결과 변경 인자 정확도가 통과해야 한다.

### C. Qwen3-4B-Instruct-2507 — iPhone의 중요한 비교 기준

[공식 카드](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507)는 non-thinking 전용임을 명시한다. 도구 사용·다국어·글 다듬기를 지원하고, 실제 MLX 자산도 작다. 최신 세대가 아니어도 지연이 짧은 한국어 텍스트 업무에서 이길 수 있으므로 폰 평가에서 제외하지 않는다.

[Qwen3.5 2B 카드](https://huggingface.co/Qwen/Qwen3.5-2B)의 자체 비교에서 non-thinking IFEval은 2B가 61.2, Qwen3-4B-2507이 83.4다. 이는 한국어 도구 정확도 점수가 아니지만, “작고 최신이면 충분하다”는 가정을 반박한다. 2B는 단순 분류·요약으로 제한하고 쓰기 기능은 별도 합격 없이는 제공하지 않는다.

### D. Qwen3.5 4B / Gemma 4 E4B / Gemma 4 12B

- [Qwen3.5 4B](https://huggingface.co/Qwen/Qwen3.5-4B): E2B 및 Qwen3-Instruct가 품질에 실패했을 때 비교 후보. 3GB 자산과 런타임을 감당하는지 실측. 이미지 기능을 지금 켤 필요는 없다.
- [Gemma 4 E4B](https://ai.google.dev/gemma/docs/core): E2B보다 무거운 폰 품질 옵션. 15 Pro 기본으로 고정하기 전에 E2B 대비 품질 이득과 지연·발열을 확인한다.
- [Gemma 4 12B IT](https://huggingface.co/google/gemma-4-12B-it): 조사했으나 M1·8GB 기본 범위에서 제외. 가벼운 개인 비서에 필요한 자원을 넘어가므로 필수 비교 실험으로 넣지 않는다.

### E. 큰 최신 모델과 다른 경량 모델

- [Qwen3.8 공식 목록](https://huggingface.co/collections/Qwen/qwen38)의 27B와 [Qwen3.6 35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B)는 조사에 포함했다. 단순 4bit 가중치만 계산해도 각각 약 13.5/17.5GB이며 실제 자산·런타임은 다르다. 24GB 개발용 Mac의 상주 기본으로는 여유가 작아 보류. MoE의 active 3B는 총 가중치가 3B라는 뜻이 아니다.
- [Liquid LFM2.5 1.2B](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct)는 경량 후보지만 한국어 개인 비서의 품질을 입증하는 비교가 부족해 1차 평가 우선순위에서 내린다.
- Apple `SystemLanguageModel`은 모델 다운로드 부담을 줄이는 대안이나 사용자의 오픈 모델 방향과 다르다. 활성화·지원 상태에 의존하므로 필수 폴백으로 삼지 않는다. 로컬 모델 오류를 클라우드 호출로 바꾸지 않는다.

## 4. 실행 엔진 — 모델과 따로 결정

| 엔진 | 확인한 근거 | 이번 권고 |
|---|---|---|
| LiteRT-LM | [공식 Swift API](https://developers.google.com/edge/litert-lm/swift): Metal·스트리밍·도구·thinking 설정. [v0.16.0 Package.swift](https://raw.githubusercontent.com/google-ai-edge/LiteRT-LM/v0.16.0/Package.swift): Apple용 binary target과 Swift wrapper | 양 기기 기본. 먼저 공식 패키지 v0.16.0을 고정해 빌드·기기 로딩 확인 |
| MLX Swift LM | [3.31.4 릴리스](https://github.com/ml-explore/mlx-swift-lm/releases/tag/3.31.4): Qwen3.5 캐시/타입/도구 및 Gemma 관련 수정. [model factory](https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLLM/LLMModelFactory.swift): 모델 등록 | Qwen 비교용. 제품에 두 엔진을 필수로 넣지 않는다. 평가 시작 태그 3.31.4, `main` 추적 금지 |
| Core AI | [Apple 공식 안내](https://github.com/apple/coreai-models): OS/Xcode 27 필요. [실제 registry](https://raw.githubusercontent.com/apple/coreai-models/main/python/src/coreai_models/model_registry.py)에서 Qwen3 존재, Qwen3.5/Gemma4 preset 미확인 | 현재 추천 모델의 구현 선행조건으로 두지 않음. 추후 지원·전력 이득을 확인한 뒤 어댑터 교체 |

**과거 논의의 정정:** [기존 문서](../../.oculpm/discussion/lazymemo-on-device-llm/discussion.md)는 Core AI와 OS27 방향을 기록했다. OS27 방향은 유지하되, 최신 모델을 Core AI로 곧바로 export할 수 있다는 가정은 채택하지 않는다. `--experimental`은 미구현 아키텍처를 자동 지원하는 옵션이 아니다. Qwen3-4B preset도 정확히 `Instruct-2507` 지원을 보장하지 않는다. 기존 문서의 고정 tok/s·다운로드 0·항상 warm 추정도 이번 구현의 측정값으로 사용하지 않는다.

## 5. 결정 규칙

1. 폰: Gemma E2B/LiteRT와 Qwen3-4B-Instruct/MLX를 같은 한국어 평가로 비교. 둘이 품질을 통과하면 p95 사용자 응답 시간·발열·메모리 순으로 선택. E2B가 품질에 실패하면 Qwen3-4B를 선택; 둘 다 실패하면 Qwen3.5-4B, 이어 E4B 평가.
2. Mac: M1·8GB에서 E2B/LiteRT를 먼저 검증. 같은 품질 세트로 Qwen3-4B-Instruct/MLX를 비교하되 메모리 예산을 넘으면 제외. 16GB 이상 E4B는 후속 선택 옵션. M4 결과로 M1 합격을 대신하지 않는다.
3. 모든 기능을 한 점수로 합치지 않는다. 검색 답변이 합격해도 쓰기 인자 정확도가 실패하면 쓰기를 끈다.
4. 평가 대상 모델을 여러 개 동시에 RAM에 두지 않는다. 기기별 최종 기본은 하나. 대안은 자동 다운로드하지 않는다.
5. 한국어 품질·15 Pro 발열·M1 속도·실제 peak memory·전력은 **미측정**. 구현 명세 §8의 표를 채우고 나서 최종 확정한다. M1 지원은 출시 목표이며 이번 조사에서 실기기 통과를 확인한 것은 아니다.

## 6. 결정

### Decision 1 — M1부터의 가벼운 기본 모델 {#decision-light-mac}

잠금: 2026-09-15 · codex · 근거: 사용자의 M1 지원·경량화 명시 요청. 최소 검증 구성은 M1·8GB로 잡고, 공통 기본 추천은 E2B/LiteRT로 한다. 9B/12B는 필수 구현·벤치 범위에서 제외한다. 모델의 최종 배포 확정은 실기기 품질·자원 게이트 뒤다.

영향: #benchmark-m1, #model-manifest, #model-lifecycle, #mac-quality-profile.

### Decision 2 — 모델별 추론 결과보다 앱의 근거·변경 계약을 고정 {#decision-local-contract}

잠금: 2026-09-15 · codex · 근거: 기존 MemoService의 파일 우선 저장·미지정 필드 보존·휴지통 정책. 개인 기억은 원문 메모에 두고, 모델 출력은 검증 가능한 제안으로 취급한다. 상주는 이벤트 대기이며 무한 추론이 아니다.

영향: #assistant-contracts, #evidence-retrieval, #action-executor, #daily-brief.
