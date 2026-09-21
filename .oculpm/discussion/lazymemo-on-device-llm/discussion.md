---
oculpm_discussion: v1
id: lazymemo-on-device-llm
title: "폰에 상주하는 LLM — 어떤 모델·엔진으로, 얼마나 빠르게"
status: resolved
created: 2026-09-14
updated: 2026-09-21
owner: claude-code
---

## 문제 정의

lazymemo 가 LLM 에 시키는 일은 둘뿐이다 — **✧ 다듬기**(`ClaudePrompts.tidy`, 메모를 읽기 좋게 고쳐 쓰기)와 **아침 브리핑**(`ClaudePrompts.morningBrief`, 오늘 메모 20줄에서 세 개 고르기). 둘 다 `claude` CLI 가 있는 **맥 GitHub 판에서만** 된다. 아이폰 판과 맥 App Store 판(샌드박스)에는 LLM 이 없다. 날짜 읽기는 규칙 파서라 LLM 이 필요 없고, MCP 는 Claude 가 밖에서 앱을 부르는 방향이라 기기 안의 일이 아니다.

물음: **폰(과 샌드박스 맥)에 LLM 을 두어 이 두 일을 기기 안에서 할 수 있나. 어떤 모델·엔진으로. 속도는 어떻게 지키나.**

제약 — 이 앱이 이미 약속한 것들:

- README 프라이버시 표: "메모 본문이 컴퓨터 밖으로 나가는 길은 넷뿐". 온디바이스 모델은 이 표에 줄을 **늘리지 않는다**. 서버 모델은 늘린다.
- 앱 크기 — release zip 1.6MB 를 자랑한다. 모델 내려받기는 이 앱에 처음 생기는 큰 짐이다.
- "사용자는 게으르다" — 기다림을 말하는 낱말이 화면에 없다(`{#claude-wait-state}` 가 첫 예외). 새 대기 상태를 만들면 안 된다.
- iOS 에서 앱은 상주하지 못한다. "상주" 는 곧 "모델이 기기에 있고 앱이 열릴 때 깨어난다" 다. 8시 브리핑은 폰에서는 "8시 이후 첫 열기" 로 번역된다.

### 배경 — OS 27 이 바꾼 것

- **`LanguageModel` 프로토콜.** `LanguageModelSession` 하나에 모델을 한 줄로 갈아 꽂는다 — 애플 기본 모델·내려받은 오픈 모델·애플 서버(PCC)·Claude. `@Generable` 구조체 출력·툴 호출·스트리밍이 어느 모델에서나 같다. 26 은 애플 모델 전용 콘센트였고 27 은 HDMI 단자다.
- **Core AI.** 오픈 모델(`.aimodel`)을 폰에서 돌리는 애플제 엔진 + `apple/coreai-models` 의 내보내기 레시피. 카탈로그(2026-09-14 기준): Qwen3 0.6/1.7/4/8B, Qwen3-MoE, Gemma 3, Gemma 3n, Phi, SmolLM2, OLMo2, gpt-oss, Mistral 등. **Qwen 3.5·Gemma 4 는 아직 없다.** iOS/macOS 27 + Xcode 27 필수. iOS 는 내보낼 때 컨텍스트 길이 고정, 4bit 팔레타이즈 기본, 큰 모델은 `increased-memory-limit` 엔타이틀먼트.
- 애플 기본 모델 재구축(사진 입력·컨텍스트 확대, `contextSize` 런타임). `PrivateCloudComputeLanguageModel` (32K, 키·계정 없음, 일일 한도). `ClaudeLanguageModel`.

## 후보 해결 방안

### 방안 A — 애플 기본 모델 (`SystemLanguageModel.default`) {#opt-apple}

- 장점: 다운로드 0·앱 크기 0. OS 가 늘 띄워 둬 첫 글자가 가장 빠르다. 한국어 됨. 프라이버시 표에 줄이 안 는다. 다듬기는 Writing Tools 「다시 쓰기·목록으로」와 같은 계열의 일이라 이 모델이 훈련된 바로 그 작업이다. 맥 `claude` 유무처럼 `availability` 한 줄로 켜고 끈다.
- 단점: Apple Intelligence 기기(15 Pro 이상·16·17·M 시리즈)에서 **켜져 있어야** 한다. 3B 급 — Qwen3-4B·Gemma3-4B 와 비기는 수준이고 한국어에서 더 떨어진다. 가드레일이 멀쩡한 메모를 거부할 수 있다. 세션 4096 토큰(27 에서 확대).
- 비용: ~50줄. `ClaudeRunner.ask(prompt, about:)` 와 같은 모양의 러너 하나.

### 방안 B — 오픈 모델을 Core AI 로 {#opt-coreai}

| 모델 | 4bit 크기 | 한국어 | 라이선스 | 폰 등급 |
|---|---|---|---|---|
| **Qwen 3.5 4B** | ~2.5GB | 201개 언어, 계열 전통상 강함 | Apache 2.0 | 8GB (15 Pro·16·17) |
| **Qwen 3.5 2B** | ~1.3GB | 같은 계열 | Apache 2.0 | 6GB (14·15) 까지 |
| **Gemma 4 E2B** | ~1.5GB | 140개+ 언어 | Apache 2.0 | 6GB 까지 |

- 제외: EXAONE(LG) — 한국어는 좋으나 **비상업 라이선스**. 8B 급 — 폰에서 무리. Kanana 2.1B(카카오, Apache) — 세대가 오래돼 보류.
- 장점: 품질·한국어가 A 보다 낫다. Apple Intelligence 게이트 없음(메모리만 본다). 애플 공식 엔진이라 프롬프트 형식·구조 출력을 내가 안 짠다. 프라이버시 표 그대로. 맥 App Store 판도 같은 코드(맥은 4B 고정).
- 단점: **1.3~2.5GB 내려받기 + 호스팅**(HF 미러·GitHub Release·자체). 기기 등급이 세 갈래(4GB 폰은 ✧ 숨김 / 6GB 는 2B / 8GB 이상 4B). 콜드 로드 1~3초, 발열. Qwen 3.5·Gemma 4 가 카탈로그에 없어 `--experimental` 내보내기이거나 등재 대기. **최소 버전 27.**

### 방안 C — 오픈 모델을 MLX Swift 로 {#opt-mlx}

- 장점: iOS 26 유지 가능. 커뮤니티가 새 모델을 며칠 안에 올려 Qwen 3.5·Gemma 4 가 이미 있다.
- 단점: 바이너리 수십 MB. 엔진·템플릿·양자화 유지보수가 내 몫. 2GB 넘으면 메모리 엔타이틀먼트. → **최소 27 결정으로 필요성이 줄었다.** Core AI 카탈로그가 늦을 때의 대안.

### 방안 D — 서버 모델 (PCC / Claude) {#opt-cloud}

- 장점: 품질 최고, 다운로드 0, 27 에서는 한 줄.
- 단점: 프라이버시 표에 줄이 는다. 오프라인 불가. 일일 한도. → **기본이 아니라 도망갈 길.** 온디바이스가 못 미칠 때 인자 하나로 갈아탄다.

## 속도

병목은 답을 **쓰는** 속도(decode)고, 시간은 **답 길이에 비례**한다. 한국어는 토큰이 비싸 메모 한 장 다듬기 ≈ 60~100 토큰.

| 단계 | 애플 기본 | Qwen 3.5 4B | Qwen 3.5 2B |
|---|---|---|---|
| 모델 올리기(첫 1회) | ~0 | 1~3초 | ~1초 |
| 답 쓰기 (16/17 Pro) | ~30 tok/s | ~15~25 tok/s | ~35~50 tok/s |
| 다듬기 한 장 | 2~3초 | 3~5초 | ~2초 |

폰은 맥보다 3~5배 느리다 — 맥 수치로 안심하지 말 것. 대책, 효과 큰 순:

1. **스트리밍** — `streamResponse` 로 종이 위에 글이 흘러들게. 체감 "전체 4초" → "첫 글자 0.5초". 구조체 출력도 부분 구조체로 흐른다.
2. **미리 데우기** — `prewarm()`. 종이를 열거나 ✧ 에 손이 갈 때. 모델 인스턴스는 앱 생애에 하나만 잡고 놓지 않는다(요청마다 올리면 매번 1~3초).
3. **브리핑은 보기 전에** — 앱이 뜨고 몇 초 뒤 조용히, 하루 한 번만. 사용자는 기다린 적이 없다.
4. **생각 모드 끄기** — Qwen 3.5 는 기본이 생각 뒤 답하기. 켜 두면 답 전에 수백 토큰을 혼자 쓴다. 반드시 끈다.
5. **답을 짧게** — "원문보다 길면 다듬은 게 아니다" 가 곧 속도 규칙. 브리핑 세 줄.
6. **크기는 재서** — 다듬기는 2B 로 충분할 가능성, 브리핑만 4B 같은 **일마다 다른 모델**도 한 줄이다.

예산: **첫 글자 ≤ 1초, 다듬기 완료 ≤ 3초(8GB 폰), 브리핑은 사용자가 보기 전에 끝.** 지금 맥 Claude CLI 경로가 상한 90초·실제 수 초~수십 초라, 이 예산이면 어느 길이든 지금보다 빠르다.

## 토의 / 메모

<!-- oculpm:discussion-log begin v1 -->
| 시각 | 작성자 | 내용 |
|---|---|---|
| 2026-09-14T21:10:00+09:00 | claude-code | 사용자: 폰에 상주하는 로컬 LLM 메모 앱이 되나. → 된다. 이 앱이 LLM 에 시키는 일은 다듬기·브리핑 둘뿐이고 둘 다 작은 모델의 일. 날짜 파서·MCP 는 해당 없음 |
| 2026-09-14T21:20:00+09:00 | claude-code | 사용자 우려: 애플 기본 모델 성능. → Claude 급은 아니나 다듬기는 Writing Tools 와 같은 작업. 실측하려 했으나 이 맥은 Apple Intelligence 꺼짐(`appleIntelligenceNotEnabled`) — 프로브는 스크래치패드 `fm_probe.swift` 에 있음 |
| 2026-09-14T21:28:00+09:00 | claude-code | 사용자 확인: 클라우드 아닌가. → `SystemLanguageModel.default` 는 온디바이스. 클라우드는 PCC·Claude 를 꽂을 때만. 프라이버시 표 기준으로 갈라 둠 |
| 2026-09-14T21:35:00+09:00 | claude-code | **사용자 결정: 오픈소스 중 가장 괜찮은 모델로.** → {#opt-coreai}. Qwen 3.5 4B 1순위, 6GB 폰은 2B, Gemma 4 E2B 대안. EXAONE 은 비상업 라이선스로 제외. 대가는 모델 내려받기 |
| 2026-09-14T21:45:00+09:00 | claude-code | **사용자 결정: 앱 최소 버전 27.** → {#opt-mlx} 는 대안으로 내려감. Core AI + `LanguageModelSession` 공통 코드가 본선 |
| 2026-09-14T21:50:00+09:00 | claude-code | 사용자 우려: 속도. → 모델을 빠르게 하기보다 기다리는 순간을 없애기 — 스트리밍·prewarm·브리핑 선행·생각 모드 끄기·짧은 답·크기 실측. 예산 첫 글자 ≤1초·다듬기 ≤3초 |
<!-- oculpm:discussion-log end -->

## 결론

아직 열려 있다. 정해진 것과 남은 것:

**정해진 것**
- 앱 최소 버전 iOS/macOS **27**.
- 오픈 모델을 **Core AI** 로 돌린다 ({#opt-coreai}). 애플 기본 모델({#opt-apple})은 내려받기 전·미지원 기기의 폴백 후보, 서버({#opt-cloud})는 도망갈 길.
- 코드는 `LanguageModelSession` 에 대고 **한 번만** 쓴다 — 다듬기·브리핑. 모델은 인자 하나.
- 속도는 스트리밍·prewarm·선행 생성으로 지키고, 예산은 첫 글자 ≤ 1초·다듬기 ≤ 3초.

**남은 것**
- 모델 확정 — 벤치마크가 아니라 **이 앱의 한국어 메모로 돌려 본 결과**로. Qwen 3.5 4B vs 2B vs Gemma 4 E2B.
- 호스팅 자리, 기기 등급 경계, 4GB 폰 처리, 애플 모델을 폴백으로 둘지.
- Qwen 3.5·Gemma 4 의 Core AI 카탈로그 등재 여부.

## 다음 단계

- [ ] 이 맥을 macOS 27 + Xcode 27 로 — Core AI 가 없으면 아무것도 못 잰다 {#next-toolchain}
- [ ] Qwen 3.5 4B·2B·Gemma 4 E2B 를 `tidy`·`morningBrief` 프롬프트 + 한국어 메모 넉 장으로 맥에서 실측 — 품질·tok/s 나란히 (`fm_probe` 확장, `llm-benchmark`) {#next-mac-bench}
- [ ] Qwen 3.5·Gemma 4 가 `coreai-models` 카탈로그에 있는지 / `--experimental` 내보내기가 되는지 {#next-catalog}
- [ ] 앱 안 디버그 화면 — 모델·첫 글자·tok/s. 아이폰 실기기에서 재고, 모델 바꿀 때마다 다시 쓴다 {#next-device-bench}
- [ ] 모델·기기 등급 확정 + 호스팅 자리 {#next-model-pick}
- [ ] `LocalRunner` — `ClaudeRunner.ask` 와 같은 모양, 스트리밍·prewarm·생각 모드 끔, 원문의 숫자·시각이 결과에 남는지 확인해 아니면 조용히 버리는 가드 {#next-runner}
- [ ] 내려받기 UX — 첫 ✧ 에 "N GB 를 받습니다" 한 번 묻고 Background Assets 로 {#next-download}
- [ ] 브리핑을 폰에서는 "8시 이후 첫 열기, 뜨고 몇 초 뒤 조용히" 로 {#next-brief-phone}
