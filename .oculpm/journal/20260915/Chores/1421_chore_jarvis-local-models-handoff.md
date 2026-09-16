---
schema_version: 1
type: chore
slug: "jarvis-local-models-handoff"
status: done
difficulty: medium
created_at: "2026-09-15T14:21:47+09:00"
session_id: "20260915-002"
agent:
  id: "codex"
  version: "GPT-6"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/JARVIS_IMPLEMENTATION.md"
    op: create
  - path: "docs/research/local-models-2026-09-15.md"
    op: create
  - path: ".oculpm/planner/lazymemo-jarvis-local.md"
    op: create
related:
  - ref: "20260828/Features_to_add/1734_feature_mcp-server-stdio.md"
    kind: "followup"
tags:
  - "local-llm"
  - "jarvis"
  - "handoff"
  - "gemma4"
  - "litert"
  - "m1"
  - "iphone15pro"
  - "mcp-tool"
---
[x] 로컬 자비스 모델 조사와 구현 인계 — iPhone 15 Pro·M1 경량 기본

## 변경 내용

공식 모델 카드·배포물·Apple/Google 엔진 문서·패키지 소스로 후보를 비교했다. 사용자가 iPhone15Pro를 지정하고 Mac은 M1부터 가벼운 모델을 원한다고 정정하여, 양쪽 기본 추천을 Gemma4 E2B IT/LiteRT-LM Metal로 정했다. M1 8GB를 최소 검증 구성으로 잡고 16GB 이상 E4B는 후속 선택 옵션, Qwen3-4B-Instruct/MLX는 품질 비교 후보로 남겼다. 9B/12B는 필수 구현에서 제외했다.

모델 조사 문서와 224줄 구현 명세를 작성했다. 기존 MemoService/FTS/Recall/Claude 경로와 연결 지점, 근거 검색·조건부 쓰기·취소/중복 방지·다운로드 manifest·기기별 모델 해제·한국어80문항 평가·실기기 합격 기준을 명시했다. 새 활성 플랜 lazymemo-jarvis-local에 7단계 작업을 생성했다. 제품 코드와 기존 출시 플랜은 변경하지 않았다.

## 인계와 한계

현재 개발 Mac은 M4 Pro24GB/macOS27, 활성 Xcode26.6이다. 다음 세션은 #device-toolchain부터 시작하며 iPhone15Pro와 M1 8GB 실측을 해야 한다. 이번에는 가중치 다운로드·추론 벤치·제품 구현을 하지 않았다. 공식 iPhone17Pro/M4 수치를 대상 기기의 측정값으로 사용하지 않았다. 기존 Core AI 논의는 보존하고 지원 registry 미확인 및 추정 속도에 대한 정정을 새 문서에 남겼다. 현재 연결된 다른 수신 세션이 없어 task_create로 임의 전달하지 않고 문서/플래너로 인계한다.

## 검증

로컬 문서 링크·코드펜스·플래너 ID 유일성/줄끝/중첩·명세의 항목 참조를 스크립트로 확인했다. 공식 배포물 파일 크기와 Swift package 태그·엔진 지원을 교차 확인했다. 문서 작업이므로 앱 테스트는 실행하지 않았다.