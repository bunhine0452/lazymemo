---
oculpm_plan: v1
id: lazymemo-jarvis-local
title: "로컬 자비스 — iPhone 15 Pro와 M1부터의 Mac"
status: active
created: 2026-09-15
updated: 2026-09-15
owner: codex
---

구현 명세: [docs/JARVIS_IMPLEMENTATION.md](../../docs/JARVIS_IMPLEMENTATION.md), 모델 근거: [조사 문서](../../docs/research/local-models-2026-09-15.md). 사용자 결정: M1부터 쓸 수 있는 가벼운 Mac 모델; 공통 기본 추천 Gemma 4 E2B/LiteRT-LM, M1·8GB와 iPhone 15 Pro 실측 뒤 확정.

## 조사와 구현 인계 {#research}
- [x] 기기별 모델 조사·M1 경량화 결정·구현 명세·검증 기준·플래너 작성 {#research-handoff}

## 환경과 모델 검증 — 제품 구현 전 {#validation}
- [~] 명세 §0: Xcode27·OS27·iPhone15Pro·M1 8GB 검증 환경 확인; 기존 출시 변경과 분리 {#device-toolchain}
- [~] 명세 §7: LiteRT-LM v0.16.0/E2B 양 플랫폼 로딩·스트리밍·취소 spike; Qwen3-4B-Instruct/MLX 3.31.4 비교 경로 {#runtime-spikes}
- [x] 명세 §8: 한국어 80문항·가상 메모 fixture·cold/warm/품질/메모리 벤치 runner 작성 {#benchmark-fixtures}
- [ ] 기기별 모델 비교와 기본 프로필 확정 {#model-benchmark}
  - [ ] iPhone15Pro 실기기 E2B/LiteRT vs Qwen3-4B-Instruct/MLX; 한국어·발열·잠금·jetsam 검증 {#benchmark-phone}
  - [ ] M1 8GB 실기기 동일 비교; peak 3GB 예산·다른 앱 병행·유휴 해제 검증; M4 수치로 대체 금지 {#benchmark-m1}
  - [ ] 두 기기 합격 결과를 문서화하고 모델 revision·파일 SHA256·엔진·컨텍스트·기능별 허용 프로필 고정 {#model-manifest}

## 공통 비서 계층과 모델 관리 {#runtime}
- [x] 명세 §2~3: AssistantRequest/Evidence/ProposedAction/provider 계약·Coordinator; Core/MCP/Share Extension 엔진 의존 격리 {#assistant-contracts}
- [x] 명세 §7: 파일 선택 다운로드·진행/재개/취소·무결성·저장 부족·삭제·원자 교체; vault/iCloud 밖 저장 {#model-download}
- [x] 명세 §6~7: 양 기기 단일 엔진·예산·취소·압박 해제; M1 2분 유휴·iOS 백그라운드 중단 {#model-lifecycle}

## 기억과 검증된 행동 {#memory-actions}
- [x] 명세 §4: FTS·날짜/폴더·질의 확장·최대6근거·hash·토큰 예산·인용 검증 {#evidence-retrieval}
- [x] 명세 §4/8: 동의어 회상 Recall@6 검증; 미달이면 한국어 임베딩 평가/구현, 합격이면 근거를 남기고 후속 이월 {#semantic-retrieval}
- [x] 명세 §5: allowlist·명시 필드 patch·MemoService 조건부 변경·대상 명확성·되돌리기·중복/취소 보호 {#action-executor}
- [~] 명세 §8: 근거 없음/충돌·메모 속 지시·부분 JSON·동시 수정·원문 숫자/날짜/첨부 보존 테스트 {#assistant-regressions}

## 세 가지 사용 흐름 {#experience}
- [x] 명세 §1: 양쪽 질문 UI·스트리밍·근거 메모 열기·찾지 못함/기기 미다운로드 상태 {#ask-memos}
- [x] 명세 §1/5: 자연어 메모 생성·다시보기/일정/폴더 변경·명확화·결과/되돌리기 {#natural-commands}
- [x] 기존 다듬기를 로컬 provider에 연결; 원문 보존·실패 시 원문 유지·App Store판 사용 {#local-tidy}
- [~] 명세 §6: 오늘 최대3개 근거 브리핑·기기별 fingerprint 캐시·기존 지금/Recall 순서와 권한 보존 {#daily-brief}

## 실기기 완성 검증과 배포 {#release}
- [ ] 명세 §9: iPhone15Pro/M1 8GB에서 질문→근거→시각변경→재시작·오프라인·iCloud 왕복·잠금 검증 {#device-e2e}
- [~] OS27 빌드 설정·Mac/iOS sandbox archive·모델 미설치 회귀·서명/엔타이틀먼트 검증 {#sandbox-release}
- [x] README/PRIVACY/스토어 문구에 로컬 모델 다운로드·상주 한계·지원 기기·삭제 반영 {#privacy-copy}

## 기본 기능 검증 뒤 확장 {#extensions}
- [ ] 명세 §10: 16GB 이상 Mac의 E4B/LiteRT 선택 옵션 평가; 품질 이득/예산 통과 때만 도입 {#mac-quality-profile}
- [ ] 명세 §10: 눌러서 음성 입력/읽어주기·한국어 온디바이스 ASR 평가; 상시 청취 제외 {#voice-entry}
- [ ] 명세 §10: 선택적 폰→Mac 위임 설계부터; 페어링/암호화/timeout/중복/오프라인 복귀 검증 {#mac-relay}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-15T14:21:56+09:00 | #research-handoff | codex | ☐→x | .oculpm/journal/20260915/Chores/1421_chore_jarvis-local-models-handoff.md | 모델 조사·M1 경량화 반영·구현 인계 문서 검증 완료; 제품 구현/실기기 벤치는 미착수 |
| 2026-09-15T14:48:48+09:00 | #device-toolchain | claude-code | ☐→~ | .oculpm/journal/20260915/Chores/1448_chore_jarvis-device-toolchain-check.md | Xcode 26.6 만 설치(27 없음)·iPhone/M1 미연결. spike 는 26.6 으로 가능. Xcode27·실기기 연결은 사용자 몫 |
| 2026-09-15T14:54:21+09:00 | #benchmark-fixtures | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md | 메모 143·문항 80·속도 10 fixture + SpikeKit 채점/속도/메모리 runner. M4 에서 한 바퀴 실행 확인 |
| 2026-09-15T14:54:28+09:00 | #runtime-spikes | claude-code | ☐→~ | .oculpm/journal/20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md | 맥: LiteRT v0.16.0/E2B 로딩·스트리밍·취소 확인. 남음: iOS 호스트 앱 로딩·취소, MLX 3.31.4 경로 컴파일(가중치 2.3GB 미다운로드) |
| 2026-09-15T15:04:05+09:00 | #assistant-contracts | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1503_feature_assistant-contracts-coordinator.md | LazyMemoAssistant 타깃(Core 만 의존)·Coordinator·validator·mock 테스트 11개. 실행/CAS 는 #action-executor, 실엔진 provider 는 #model-lifecycle |
| 2026-09-15T15:12:04+09:00 | #action-executor | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1511_feature_action-executor-conditional-modify.md | MemoVault.modify(hash 대조, await 없음)·ActionExecutor(요청당 쓰기 1·trash 확인·undo stale 거부). 테스트 11개 |
| 2026-09-15T15:18:25+09:00 | #model-download | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1523_feature_model-download-store-litert-provider.md | ModelManifest(revision·sha 고정)·ModelStore(staging→검증→원자 교체·백업 제외)·이어받기 다운로더. UI(크기 안내·Wi-Fi 선택)는 ask-memos 화면에서 |
| 2026-09-15T15:28:04+09:00 | #model-lifecycle | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1518_feature_model-download-store-litert-provider.md | LiteRTProvider: 단일 엔진·유휴 해제(profile.idleUnload)·메모리 압박 해제·요청별 취소; iOS background → suspend(). M1 2분 값 실측은 benchmark-m1 에서 |
| 2026-09-15T15:28:37+09:00 | #ask-memos | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md | 맥 창·폰 시트 공용 AssistantView: 답+근거 칩(메모 열기)·찾지 못함·모델 없음(받기 패널). 스트리밍은 tidy 만, 답은 검증 뒤 표시 |
| 2026-09-15T15:29:45+09:00 | #natural-commands | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md | 시키기: 제안을 말로(정확한 시각) → 적용/아니요 → 되돌리기; ask 는 질문 표시; trash 확인. 맥 종이의 진입점은 없음(창에서). 모델 품질 게이트는 별도 |
| 2026-09-15T15:29:59+09:00 | #local-tidy | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md | claude 없는 맥(App Store 판)은 종이 ✧ 가 LocalTidy → AssistantModel.tidy; 원문 보존 검증(숫자·이름·첨부)은 assistant-regressions 에서 |
| 2026-09-15T15:30:38+09:00 | #daily-brief | claude-code | ☐→~ | .oculpm/journal/20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md | 「오늘」 버튼으로 ≤3 근거 브리핑·기기별 fingerprint 캐시·지금 띠 순서 보존. 남음: 앱 전경 첫 진입 자동 생성, 맥 아침 트리거 |
| 2026-09-15T15:30:48+09:00 | #privacy-copy | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md | PRIVACY ko/en 표 행·STORE_LISTING 심사 메모·README 절. 지원 기기 문구는 실기기 게이트 뒤 다시 |
| 2026-09-15T21:17:51+09:00 | #evidence-retrieval | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md | QueryTerms+MemoRanker(낱말·동의어·점수) 로 검색, 근거 ≤6·hash·인용 검증·원문 인용. fixture Recall@6 21/22. LLM 질의 확장은 안 씀(불필요) |
| 2026-09-15T21:17:59+09:00 | #semantic-retrieval | claude-code | ☐→x | .oculpm/journal/20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md | 동의어 표+어간 부분 일치로 fixture Recall@6 21/22(95%) ≥ 90% 통과 — RetrievalTests 가 지킨다. 임베딩은 이월(실사용 메모에서 미달이 보이면) |
| 2026-09-15T21:18:06+09:00 | #assistant-regressions | claude-code | ☐→~ | .oculpm/journal/20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md | 근거 없음/충돌·메모 속 지시·부분 JSON·지어낸 인용 테스트 36개 + 앱 파이프라인 벤치(lazymemo-assistant-bench). 남음: 동시 수정, 다듬기 첨부 보존 단위 테스트 |
| 2026-09-15T21:30:55+09:00 | #device-toolchain | claude-code | ~→~ | .oculpm/journal/20260915/Chores/2130_chore_testflight-upload-assistant-quality.md | Xcode 27.0(27A266a) 설치·라이선스 동의 확인, 아카이브·업로드 동작. CoreSimulator 구판 경고 — 실기기·시뮬레이터는 Xcode 27 첫 실행 뒤. iPhone15Pro·M1 연결은 아직 |
| 2026-09-18T16:51:46+09:00 | #sandbox-release | claude-code | ☐→~ | .oculpm/journal/20260918/Bugs/1650_bug_ios-litert-per-layer-embedding-null.md | 폰 entitlement 둘(넓힌 주소 공간·올린 메모리 한도) 추가, 기기 빌드 서명 확인 — 실기기 확인은 다음 TestFlight |
<!-- oculpm:plan-log end -->
