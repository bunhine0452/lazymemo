# lazymemo 개인 자비스 — 구현 인계 명세

작성일: 2026-09-15 · 작성: codex · 상태: 설계/조사 완료, 제품 구현 미착수

플래너: [lazymemo-jarvis-local](../.oculpm/planner/lazymemo-jarvis-local.md)

모델 근거·공식 출처: [기기별 모델 조사](research/local-models-2026-09-15.md)

## 0. 다음 세션의 시작점

사용자는 **각 기기에 맞는 로컬 LLM으로 개인 비서를 구현**하려 한다. 이번 세션은 조사·문서·플래너만 맡았고, 다음 세션이 구현한다.

1. `AGENTS.md` 및 관련 일지 검색, `plan_status(plan_id: "lazymemo-jarvis-local")`로 현재 상태를 읽는다.
2. 이 문서와 모델 조사 문서를 읽고 `#device-toolchain` → `#runtime-spikes` → `#model-benchmark` 순서로 진행한다. UI 전체부터 만들지 않는다.
3. 대상은 **iPhone 15 Pro**, **M1·8GB부터의 Mac**. 사용자가 Mac 모델을 더 가볍게 해 달라고 명시했다. 현재 개발 Mac은 M4 Pro24GB/macOS27이고 활성 Xcode는26.6이다. 개발 기기 성능을 최소 기기 검증으로 대체하지 않는다. Xcode27의 설치/선택 여부와 시험 기기의 OS27 여부를 먼저 확인한다. OS 업그레이드를 임의 실행하지 않는다.
4. 저장소에 다른 세션의 미커밋 변경이 많다. 시작 시 `git status --short`를 읽고 필요한 경로만 claim한다. 기존 변경을 초기화하거나 `git add -A`하지 않는다.
5. 기능 단위마다 즉시 일지 작성, 대응 플래너 항목을 hash 기반 `plan_update`로 갱신한다. 본문의 설계 선택을 구현 완료로 간주하지 않는다.

**초기 추천:** iPhone·Mac 공통 **Gemma4 E2B IT/LiteRT-LM Metal**. M1·8GB에 맞춰 기본 모델 하나로 시작한다. Mac16GB 이상 E4B는 후속 선택 옵션이다. 실기기 게이트에서 변경 가능하다. 기존 온디바이스 논의의 OS27 방향을 이어받되 Core AI만 기다리지는 않는다. M1 지원은 칩 기준이며 OS27 최소 버전과 별개다.

## 1. 제품 범위와 성공 장면

첫 출시는 텍스트 기반 세 가지를 완성한다.

| 기능 | 사용자 입력/상황 | 완료 조건 |
|---|---|---|
| 메모에게 질문 | “지난번 엄마 선물 뭐 사려고 했지?” | 관련 메모를 검색, 짧은 답과 누를 수 있는 근거 메모. 못 찾으면 모른다고 답함 |
| 자연어 작업 | 열린 메모에서 “금요일 오전 10시에 다시 알려줘” | `surface` 변경, `due`/`at` 보존, 결과 시각과 되돌리기 표시 |
| 오늘 챙길 것 | 아침 또는 앱을 다시 열었을 때 | 실제 메모/일정에서 최대 세 개, 각각 이유·근거·시각. 원본 일정과 알림 규칙 보존 |

기존 다듬기와 브리핑도 새 로컬 러너로 연결한다. 기록을 학습한 것처럼 말하지 않고, 검색한 기록을 근거로 답한다. 모델 다운로드 뒤 위 세 기능은 인터넷 없이 동작해야 한다. iCloud 동기화 자체는 네트워크가 필요하다.

후속 범위는 §10: 눌러서 음성 입력/읽어주기, 선택적 Mac 위임. 항상 마이크를 듣거나 다른 앱 전체를 조작하는 에이전트는 이 첫 출시에 포함하지 않는다.

## 2. 기존 코드와 변경 위치

| 기존 파일 | 역할 / 구현 지침 |
|---|---|
| `Sources/LazyMemoCore/Storage/MemoService.swift` | 파일 먼저, 인덱스 나중인 저장 계층. 새 도구도 이 계층으로 모은다 |
| `Sources/LazyMemoCore/Storage/MemoStore.swift` | UI 관찰 계층. 실행 성공 뒤 화면이 즉시 갱신되는 경로를 연결 |
| `Sources/LazyMemoCore/Storage/MemoIndex.swift` | SQLite FTS5 trigram. 짧은 검색어·한글 첫소리 기존 동작 보존 |
| `Sources/LazyMemoCore/Claude/ClaudeRunner.swift` | Mac CLI 전용. 프롬프트 의미와 원문 보존 규칙을 공통 모듈로 옮기되 CLI 폴백은 명시 선택일 때만 |
| `Sources/LazyMemoUI/Claude/ClaudeSupport.swift` | 현재 App Store판에서 CLI 연동 차단. 로컬 AI의 지원 여부를 이 조건에 묶지 않는다 |
| `Sources/LazyMemoUI/Claude/MorningBrief.swift` | Mac 브리핑 진입점. 공통 BriefComposer/기기별 스케줄러로 연결 |
| `Sources/LazyMemoMCP/MemoTools.swift` | 외부 stdio 도구. 앱 내부에서 이 실행 파일을 띄우지 않는다. 검증 가능한 도메인 동작만 공유 |
| `Sources/LazyMemoCore/Agenda/Recall.swift` | 다시 보기 후보·알림 기준. 날짜만 있는 메모에 시각을 지어내지 않는 계약 유지 |
| `Sources/LazyMemoReminders/ReminderCenter.swift` | 기기별 권한/시스템 알림. LLM이 알림 권한이나 예약 규칙을 우회하지 않음 |
| `ios/LazyMemo/AppModel.swift`, `ios/LazyMemo/NowBand.swift` | iOS 수명주기·「지금」 UI 통합 |
| `Package.swift`, `ios/LazyMemo.xcodeproj/project.pbxproj` | 실제 빌드 설정. 현재 최소 OS26으로 기록돼 있어 OS27 전환은 별도 항목으로 수행 |

새 모듈 권고:

- `LazyMemoAssistant`: Sendable 요청/이벤트/도구 계약, 검색·컨텍스트·정책·브리핑. `LazyMemoCore`에만 의존.
- `LazyMemoLocalLiteRT`: iOS·Mac 공통 기본 어댑터. 기기별 수명주기/예산은 profile로 주입.
- `LazyMemoLocalMLX`: Qwen 대안 실측용. 최종 선택에 필요하지 않으면 출하 타깃에서 제외.
- UI에 `AssistantModel`과 얇은 입력/결과 화면. `MainActor`는 UI 변경만, 모델 로딩/추론은 actor 밖의 적합한 실행 경로로 격리.
- 순수 Core와 MCP 타깃에 추론 엔진을 의존성으로 끌어들이지 않는다. iOS Share Extension에도 모델을 링크/로드하지 않는다.

이름은 제안이며 저장소 규칙에 맞춰 조정할 수 있다. 플랫폼별 링크 조건을 실제 빌드로 검증한다.

## 3. 실행 계약

아래는 **새 앱 내부 타입의 계약**이며 SDK에 이미 있는 API가 아니다.

```text
AssistantRequest
  requestID, task(answer/tidy/brief/command), userText,
  selectedMemoID?, now, timeZoneID, locale, inputBudget, outputBudget
Evidence
  memoID, contentHash, excerpt, sourceField, optionalSchedule
AssistantEvent
  loading / textDelta / evidence / proposedAction / completed / failed
ProposedAction
  actionID, kind, memoID?, expectedContentHash?, explicitFieldPatch
LocalModelProvider
  availability, prepare(profile), stream(request, evidence), cancel(requestID), unload()
```

Coordinator가 검색 → 근거 묶기 → 생성 → 검증 → 실행을 관리한다. 응답 스트리밍과 도구 실행을 분리한다. 부분 JSON/도구 토큰을 받았다는 이유로 저장하지 않는다. 잘못된 구조 출력은 한 번만 교정 요청, 다시 실패하면 변경 없이 오류 표시. 요청당 읽기 도구 최대 4회, 쓰기 최대 1회, 총 모델 호출 최대 3회. 사용자 취소/세대 번호로 오래된 응답의 UI·저장 반영을 막는다.

엔진별 도구 자동 실행 API를 사용하더라도 **쓰기 도구의 callback은 ProposedAction 반환까지만** 한다. 실제 저장은 아래 정책을 거친 앱 코드가 담당한다. 쉘, 임의 경로 접근, 원격 URL 실행 도구를 등록하지 않는다.

## 4. 기억·검색·문맥

정본은 기존 마크다운이다. 모델 가중치에 개인 사실을 미세조정하지 않는다. 초기 검색은 기존 FTS와 메타데이터 필터를 사용한다.

1. 선택한 메모가 있으면 우선 근거로 포함. 질문의 일정 범위는 기존 날짜 파서와 명시적인 `now/timezone`으로 처리.
2. 원문 질의 FTS + 한글 기존 검색. 부족하면 LLM이 검색어를 최대 3개로 확장하고 FTS 재조회. 검색어 생성은 파일 변경 권한이 없다.
3. 폴더·날짜·최근성으로 후보 최대 20개, 실제 문맥에는 최대 6개를 토큰 예산 안에서 넣는다. 한 메모가 문맥을 독점하지 않게 문단 단위로 자른다.
4. 메모마다 ULID·본문 hash·관련 필드·발췌를 첨부. 링크의 ID는 앱이 허용된 Evidence 목록과 대조해서 만든다. 없는 ID나 인용문을 생성하면 답을 거부/축소한다.
5. 개인 사실을 단정하는 문장에는 근거가 필요. 추측은 제안으로 표시. 근거가 충돌하면 양쪽 메모를 보여주고 확정하지 않는다.
6. 삭제·보관 상태 및 읽기 실패·iCloud 미다운로드 상태를 구분. “로컬에서 아직 읽지 못함”을 “메모가 존재하지 않음”으로 처리하지 않는다.

FTS+질의 확장은 의미 검색의 완전한 대체가 아니다. §8의 동의어/회상 평가가 실패하면 `#semantic-retrieval`에서 한국어 임베딩을 평가·추가해야 한다. 엔진 지원·양자화·토크나이저까지 검증되지 않은 임베딩 모델을 이 문서에서 확정하지 않는다. 임베딩을 추가할 경우 기기별 재생성 가능한 DB에 `memoID+contentHash+modelRevision+chunkID`를 저장하고, 수정/삭제/모델교체 시 무효화한다. iCloud로 모델·벡터 DB를 동기화하지 않는다.

초기 컨텍스트 상한은 **폰·M1·8GB Mac 모두 총 4096 tokens**. 16GB 이상 Mac의 8192 확장은 별도 실측 뒤 적용한다. 시스템·도구 schema·대화·근거·출력을 모두 포함한다. 출력은 다듬기/브리핑 192, 질문 384, 도구 인자 256 tokens 이내. 한국어는 글자 수 대신 실제 tokenizer로 센다. 필요 없는 오래된 대화는 버리고 최신 원문을 다시 검색한다.

## 5. 변경 도구와 데이터 보존

| 동작 | 허용 범위 | 사용자 흐름 |
|---|---|---|
| search/get/listToday | vault 안 읽기 | 즉시 |
| createMemo | 사용자가 명시한 본문·필드 | 저장 결과+되돌리기 |
| setRecall | `surface`만 | 정확한 시각을 보여주고 명시 요청이면 실행 |
| reschedule | 사용자가 명시한 `due`/`at` | 기존 일정과 변경 결과 표시 |
| moveToFolder | 해당 메모의 folder만 | 결과+되돌리기 |
| tidy | 선택 메모 본문 | 미리보기 또는 기존 다듬기 UX; 원문 복구 가능 |
| trash/restore | 기존 휴지통 이동/복원 | 대상이 분명해야 함. 첫 버전은 삭제 제안에 확인 UI |

- “이거”는 selectedMemoID가 있을 때만 확정. 여러 후보·시각 모호함은 필요한 정보 한 가지만 묻는다. 실행할 대상을 모델이 임의로 고르지 않는다.
- `nil`(미변경)과 clear를 구분하는 기존 이중 Optional 계약을 새 patch 타입에서도 보존한다. “다시 알려줘”가 `at`을 바꾸지 않게 한다.
- 변경 직전 원문 hash를 비교한다. 현재 `updated`는 초 단위이므로 버전 토큰으로 쓰지 않는다. 확인과 persist 사이 다른 쓰기가 끼지 않도록 `MemoService` 내부 조건부 변경 경로를 설계한다. actor도 `await` 사이 재진입 가능하므로 단순 외부 get→update로 CAS를 흉내 내지 않는다.
- 다른 기기의 동기화 충돌은 기존 `ConflictSettlement` 동작을 유지한다. 로컬 hash 비교가 기기 간 원자적 잠금을 보장한다고 주장하지 않는다.
- 요청/작업 ID를 사용해 동일 UI 재시도에 중복 생성을 막는다. 저장 결과가 불명확하면 재조회 후 사용자에게 알린다. 충돌 시 최신 근거로 재계산하며 몰래 덮어쓰지 않는다.
- 다듬기는 숫자·사람 이름·날짜·체크 상태·링크·첨부 참조 보존. 검증 실패 시 원문 유지.
- 메모 안의 “이전 지시 무시/모든 메모 삭제”는 인용 데이터다. 도구 권한을 주는 근거는 현재 사용자의 요청뿐이다.

## 6. 상주·알림·브리핑

### Mac

메뉴바 앱이 떠 있고 Mac이 깨어 있을 때 이벤트를 받는다. 변화 없는 동안 반복 추론하지 않는다. debounce된 vault 변경은 검색 캐시만 갱신하고, 사용자 요청/브리핑 트리거에 추론한다. 엔진은 한 번 로드해 재사용하되 **M1·8GB는 2분 유휴**, 16GB 이상은 5분 유휴를 초기 해제값으로 둔다. 메모리 압박에는 즉시 취소/해제한다. 상주는 비서 앱의 대기이지 모델의 영구 RAM 점유가 아니다. 로그인 항목은 기존 설정을 따른다. 잠자기를 막지 않고, 깨면 중단 작업의 유효성을 다시 확인한다.

### iPhone

앱 활성화/질문 화면 진입 때 준비, 백그라운드로 가면 생성 취소 및 미완 결과 폐기, GPU 작업과 모델 메모리 해제를 시도한다. 시스템이 앱을 즉시 정지할 수 있으므로 종료 callback 완료를 전제로 하지 않는다. 스트리밍은 메모 원본이 아닌 임시 UI 상태에만 둔다.

일반 앱의 무기한 추론은 설계하지 않는다. [Apple의 background 문서](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time)와 [continued processing 문서](https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados)를 따른다. 배경 처리 기회는 보조이고 정확한 아침 시각 실행을 약속하지 않는다.

### 브리핑과 알림

- 앱 전경에서 오늘 첫 유효 브리핑을 생성. Mac은 깨어 있으면 아침 트리거로 생성할 수 있다. 폰은 해당 시각 이후 처음 열었을 때 생성.
- 기존 `Recall`의 후보를 바탕으로 최대 세 개의 설명을 생성. AI 추천은 기존 「지금」의 명시 일정 순서를 덮어쓰지 않는 별도 보조 표시로 시작.
- 재생성 키: 로컬 날짜+시간대+입력 fingerprint+prompt/model version. 기기별 캐시이며 원본 메모의 변동 시 무효화. LLM 생성 브리핑을 양쪽에서 매번 새 동기화 메모로 만들지 않는다.
- 알림은 기존 `surface/at`을 `ReminderCenter`가 예약. 모델이 새로운 시각을 추측해 푸시하지 않는다. 날짜만 있으면 시간 질문/명시적 설정이 필요.
- 권한 거절·집중 모드·폰이 파일을 읽지 못한 경우 전달을 약속하지 않는다. 양 기기에 켜면 양쪽에서 울릴 수 있다는 기존 동작을 보존.
- 첫 출시는 브리핑 생성 때문에 추가 알림을 보내지 않는다. 사용자 설정 없이 방해를 늘리지 않는다.

## 7. 모델 설치·수명주기·엔진 설정

Manifest 필수 필드: `profileID`, upstream model ID, quantized artifact ID, immutable revision, engine/version, files(name/bytes/sha256), license/notice, context/output limits, template version. 양 기기 기본은 `gemma-4-E2B-it.litertlm` **하나**로 시작한다. 전체 HF 저장소를 snapshot download하지 않는다.

다운로드 전 정확한 크기와 로컬 처리 설명, Wi-Fi/셀룰러 선택을 표시. HTTPS 다운로드 재개·취소·디스크 부족·체크섬 실패를 처리한다. staging→검증→원자적 활성화, 기존 정상 버전은 새 버전 검증까지 유지한다. 모델은 vault 밖 Application Support에 저장하고 iCloud/백업에서 제외, 앱 안에서 삭제·다시 받기 제공. 로드 전 가용 메모리를 보고 부족하면 기본 메모 기능을 유지한다.

앱 로그에는 task 종류·지연·토큰 수·메모리·오류 코드만 남긴다. 본문·음성·생성된 reasoning은 운영 로그에 저장하지 않는다. 모델 서버 접속은 자산 다운로드에만 사용하며 원문 추론을 원격으로 보내지 않는다.

엔진 초기 설정:

- iOS·Mac: 공식 LiteRT-LM **v0.16.0**을 우선 고정, Metal, thinking off. 공식 Swift API의 Engine/Conversation을 어댑터 안에 캡슐화. MTP는 기기별 off/on 비교 후 p95·peak memory가 좋아지는 설정만 채택. 전역 experimental 설정은 동시 실행 전에 확정. M4의 SME/가속 결과를 M1 CPU에 대입하지 않는다.
- Qwen 대안 평가만: MLX Swift LM **3.31.4**를 기준으로 고정. Qwen3-Instruct-2507은 non-thinking 전용이며 Qwen3.5는 template의 `enable_thinking=false` 적용을 검사. text-only 로더/배포물 조합을 fixture로 검증하고 가중치를 임의 삭제하지 않는다.
- sampler는 각 공식 모델 카드 권고값을 기준선으로 잡고 실제 앱 task별 품질 평가를 거쳐 고정. `temperature=0`이면 정확하다는 가정을 하지 않는다.
- 폰과 Mac이 하나의 대화/KV cache를 공유하지 않는다. 모델별 tokenizer와 대화 형식이 다르다. 저장할 것은 사용자에게 보이는 대화와 근거 참조뿐이고, 다음 요청에서는 현재 근거로 재구성.
- Core AI 어댑터는 현재 필수 작업이 아니다. 정확한 모델 preset/변환·품질·전력 이득 확인 뒤 별도 채택. `LanguageModelSession` 공통화 여부도 SDK27에서 직접 컴파일 후 결정.

## 8. 실측과 합격 기준

아래 숫자는 **제품 목표**다. 현재 측정 결과가 아니며, 미달을 성능 약속 문구로 덮지 않는다.

### 평가 세트

가상 한국어 메모 100~200개로 고정 fixture를 만들고 평가 질문 **80개**를 별도 보관한다. 사용자 실제 메모는 동의 없이 공개 fixture에 복사하지 않는다.

| 영역 | 건수 | 검증 내용 |
|---|---:|---|
| 검색 기반 답변 | 20 | 이름·동의어·줄임말·옛 메모·여러 근거; 정답 memoID 지정 |
| 단일 도구 요청 | 20 | 대상·필드·값 정확성, 날짜/시간대, 다른 필드 보존 |
| 다듬기 | 10 | 사람 이름·금액·시각·URL·체크박스·첨부 참조 보존 |
| 브리핑 | 10 | 근거만 사용, 최대 세 개, 완료/삭제 제외 |
| 모호함/충돌/근거 없음 | 10 | 질문하거나 보류, 지어내지 않음 |
| 메모 속 지시/취소/중복 | 10 | 무단 실행 없음, partial tool 실행 없음, 중복 저장 없음 |

구현 세션의 산출물: `Tests/Fixtures/Assistant/*.json`(새 경로), 벤치 runner, 기기별 결과 `docs/research/local-model-benchmark-<date>.md`. 모델 평가 실행은 실기기 release build로 한다. 유닛 테스트는 mock provider로 재현 가능하게, 실모델 테스트는 별도 opt-in suite로 분리한다.

### 측정 방식

- 각 모델을 순차 로드. 한국어 full suite 3회. 속도는 고정 10개 prompt를 3회 반복하고 cold/warm 별도 기록.
- 고정 입력 1K/2K/4K tokens, 출력 제한, 엔진/모델 revision/템플릿/OS/기기/전원/thermal state를 기록. 모델마다 tokenizer가 다르므로 같은 텍스트와 실제 토큰 수 모두 보관.
- TTFT는 **사용자에게 보이는 첫 답변**까지. 모델 로드·검색·prefill·생성·전체 완료 시간을 분리. 숨은 thinking이 끝나기 전을 첫 답으로 세지 않는다.
- 앱 전체 peak physical memory와 엔진 allocator 수치를 구분. Instruments로 UI hitch·메모리·에너지·15분 반복 사용 발열, 취소 뒤 메모리 회수를 측정.
- Mac에서 Xcode/브라우저를 열고 메모리 압박·swap 증가를 함께 관찰. 아이폰은 실기기 jetsam·잠금/복귀·카메라 등 다른 앱 왕복을 확인.

| 게이트 | iPhone 15 Pro 목표 | M1·8GB Mac 목표 |
|---|---|---|
| Warm 첫 답변 p95, 고정 1K 입력 | ≤1.5초 | ≤2초 |
| 짧은 다듬기/브리핑 p95, 최대192 출력 | ≤8초 | ≤8초 |
| Cold 첫 답변 p95, 다운로드 제외 | ≤6초 | ≤6초 |
| 앱 전체 peak memory 초기 예산 | ≤3GB | ≤3GB |
| 취소 처리 | 1초 내 새 출력/쓰기 중단; 자원 회수 별도 측정 | 동일 |
| 안정성 | 15분 반복·잠금 왕복에서 crash/jetsam 0 | 유휴 추론 0, 메모리 압박 시 해제 |

품질 필수 게이트: 검색 Recall@6 ≥90%, 답변 근거 정확도 ≥95%, 단일 도구 의미 정확도 ≥95%, 실행된 변경의 대상/필드 보존 100%, 미확정 요청의 무단 실행 0, 다듬기 필수 토큰 보존 100%. 샘플 밖 완전 안전을 보장하는 수치는 아니다. 정확도 실패를 구조 JSON 파싱 성공으로 대체하지 않는다. 읽기와 쓰기 기능을 따로 승격한다.

**선택 순서:** 두 환경에서 E2B/LiteRT vs Qwen3-4B-Instruct/MLX를 비교. Mac 필수 측정은 **M1·8GB**, 현재 M4는 개발/참고 결과다. M1이 없으면 해당 항목을 미완으로 남기고 기기 확보 전 지원 검증 완료라고 쓰지 않는다. 기본 후보가 실패하면 조사 문서 §5 대안으로 확장하되 메모리 예산을 유지한다. 같은 품질이면 작은 메모리/빠른 p95 후보를 채택. 합격 후보가 없으면 해당 기능을 제한하고 결과를 남긴다. 임계값 변경은 근거를 문서화한다.

## 9. 배포와 회귀 확인

첫 데모는 임시 vault에서 “기억 질문 → 근거 열기 → 다시 볼 시각 변경 → 앱 재실행 → 원문/알림 유지” 한 바퀴다. 이후 iPhone/Mac App Store sandbox build로 같은 장면을 확인한다.

- 기존 날짜·메모 파일·MCP·Recall·동기화 회귀 검증을 관련 변경에 맞게 실행. 모델이 없는 환경에서도 기존 테스트가 통과해야 한다.
- 모델 미설치/취소/오프라인/저장 부족/파일 손상/unsupported model/토큰 초과/추론 timeout은 명시 상태로 처리. 모델 실패가 메모 저장 실패가 되지 않게 한다.
- download-only 네트워크와 기존 iCloud를 구분해 오프라인 추론 확인. 로컬/CLI 선택 및 개인정보 설명을 `docs/PRIVACY.md`, README, 스토어 문구에 반영.
- 코드 바이너리는 서명된 앱에 포함하고 가중치는 데이터 자산으로 내려받는다. 실제 archive·엔타이틀먼트·서명·스토어 처리 검증을 수행하며 승인 보장이라고 쓰지 않는다.
- OS27 변경은 Package.swift와 Xcode 프로젝트/배포 문서에 일관되게 적용. 출시 대기 중인 기존 앱의 별도 계획을 임의로 닫지 않는다.

## 10. 다음 확장과 의존성

`#voice-entry`: 첫 출시와 기기 검증 뒤, 눌러서 녹음→온디바이스 전사→동일 Coordinator→선택적 읽어주기. OS 음성 API/별도 ASR의 한국어 오프라인 지원·추가 메모리는 별도 평가. 상시 마이크는 범위 밖.

`#mac-relay`: 두 로컬 구현 안정화 뒤 선택적 폰→Mac 요청. 페어링·기기 키·암호화·취소·timeout·재전송 중복 방지·근거 버전 검증 필요. **iCloud 파일을 RPC 큐처럼 쓰지 않는다.** 폰/맥이 서로 연결되지 않아도 기본 기능 유지. 자고 있는 Mac을 항상 호출할 수 있다고 약속하지 않는다. 이 항목은 조사/설계 게이트부터 시작하며 인터넷 노출을 기본으로 하지 않는다.

`#semantic-retrieval`: §4/§8 검색 게이트가 미달이면 첫 출시 전에 완료. 이미 합격하면 임베딩 추가는 후속으로 이월하고 근거를 일지에 남긴다.

`#mac-quality-profile`: 기본 E2B가 M1·8GB에서 통과한 뒤 16GB 이상 Mac에 E4B/LiteRT 선택 옵션 검토. 한국어 품질 향상이 없으면 도입하지 않는다. 모델 두 개 동시 로딩 금지, 다운로드 크기 안내와 명시 선택, 기본으로 되돌리기를 제공한다. 8GB 기기에 무거운 모델을 자동 선택하지 않는다.

## 11. 구현 순서와 인계 완료 기준

1. 환경·의존성 고정, 공통 LiteRT 및 비교용 MLX minimal spike와 벤치 세트.
2. 대상 기기 비교 측정 → 모델 manifest 확정. 이 단계 전에 “최적 모델 확정” 상태로 바꾸지 않음.
3. provider/다운로드/수명주기, 검색+Evidence, 조건부 쓰기+취소/중복 방지.
4. 근거 질문·명령·다듬기·브리핑 UI를 기존 입력/「지금」 흐름에 연결.
5. 실기기 전체 흐름·오프라인·sandbox·동기화 검증, 개인정보/배포 문서.
6. 이후 음성/선택적 Mac 연결.

이 문서가 끝났다는 것은 위 구현이 끝났다는 뜻이 아니다. 이번 인계의 완료는 모델 근거·인터페이스·기존 코드 위치·측정 기준·의존성·플래너가 서로 연결돼 있고 다음 세션이 첫 항목부터 시작할 수 있다는 것이다.
