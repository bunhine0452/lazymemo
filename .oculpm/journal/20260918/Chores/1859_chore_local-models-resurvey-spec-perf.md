---
schema_version: 1
type: chore
slug: "local-models-resurvey-spec-perf"
status: done
difficulty: medium
created_at: "2026-09-18T18:59:10+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/research/local-models-2026-09-18.md"
    op: create
related:
  - ref: "20260915/Chores/1421_chore_jarvis-local-models-handoff.md"
    kind: "followup"
tags:
  - "research"
  - "local-model"
  - "jarvis"
  - "license"
  - "mcp-tool"
---
[x] 로컬 모델 재조사 — 사양(15 Pro·M1·≤3GB)과 성능을 함께 본 후보 6 + 시스템 모델

## 배경

사용자가 먼저 "Claude/GPT/Gemini 구독 로그인으로 모델을 쓸 수 있나" 물었다 — 2026년 세 곳 모두 제3자 앱의 구독 OAuth 를 금지(Anthropic 2026-02-20 약관·4/4 시행, OpenAI 는 Codex 한정, Google 은 2월 계정 정지·6/18 개인 로그인 경로 제거)했으므로 불가. 이어서 "진짜 괜찮은 로컬 모델을 사양과 성능 둘 다 고려해 샅샅이 찾아 달라"는 요청.

## 한 것

`docs/research/local-models-2026-09-18.md` 작성. 09-15 조사(E2B 기본) 위에 다음을 더했다.

- **새 후보 LFM2.5-2.6B**(2026-08-04): 지시·도구 벤치에서 Gemma 4 E4B·Qwen3.5-4B 를 앞섬(IFBench 59.2·Multi-IF 80.1·ToolSandbox 77.8), MLX 4bit 1.52GB, mlx-swift-lm `lfm2` 지원. 한국어는 지원 목록에만 있고 측정치 없음 → 1순위 실측 대상.
- **iPhone 17 Pro 런타임 실측**(john-rocky 하네스): E2B 는 LiteRT 497MB/61 tok/s 이지만 MLX 로는 3,010MB — 폰에선 LiteRT 전용. 지속 부하 10분 유지율 LiteRT 48%·MLX 38%·ANE 67% → §8 발열 게이트의 실제 변수.
- **한국어 최강은 Kanana-2-3B**(KoMT 6.92·KoSimpleQA 22.3·BFCL 71.9, `qwen3` 구조라 MLX 바로 로드)이나 **Kanana Open License §4.1(iii) "on-device 임베딩 제3자 제공"은 별도 상업 라이선스** → 출하 후보에서 제외, 평가 기준선으로만.
- EXAONE 4.0 1.2B 는 NC 라이선스로 제외. Mi:dm 2.0 Mini(MIT)는 한국어 폴백. Qwen3-4B-Instruct-2507 은 litert-community 에 .litertlm 이 있어 엔진 추가 없이 A/B 가능.
- **Apple AFM 3(OS 27)** 재평가: ctx 8,192·한국어·guided generation·`LanguageModel` 프로토콜(MLX/Core AI 구현 오픈소스). 이전 결정(오픈 모델 방향)은 유지하되 근거를 적어 둠. PCC 는 §7 원격 추론 금지와 충돌해 후보 아님.
- 라이선스 표(출하 가능 여부)와 다음 세션 실측 순서를 적음.

## 검증

- 수치는 전부 1차 출처(모델 카드 raw README·HF API·벤치 저장소·라이선스 원문)에서 가져와 문서 끝에 링크. Kanana 라이선스는 §4.1(iii) 원문을 직접 인용해 확인.
- 코드·빌드 변경 없음. 가중치 다운로드 없음.

## 메모

- 모든 속도·메모리 수치는 17 Pro·M4/M5 것 — 15 Pro·M1 합격 판정에 쓰지 않는다(명세 §8).
- 한국어 하네스가 카카오/KT 로 갈려 열끼리 직접 비교 불가 — 문서에 명시.