---
schema_version: 1
type: feature
slug: "assistant-web-search-ddg"
status: done
difficulty: medium
created_at: "2026-09-17T12:28:55+09:00"
session_id: "20260917-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/WebSearch.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Intent.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/OutputValidator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Prompts.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureModel.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureView.swift"
    op: update
  - path: "Sources/LazyMemoUI/QuickCapture/QuickCaptureController.swift"
    op: update
  - path: "Sources/LazyMemoUI/Views/PreviewRenderer.swift"
    op: update
  - path: "ios/LazyMemo/PenModel.swift"
    op: update
  - path: "ios/LazyMemo/PenBar.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/WebSearchTests.swift"
    op: create
  - path: "Tests/Fixtures/Assistant/duckduckgo-html.html"
    op: create
  - path: "Tests/LazyMemoLocalLiteRTTests/RealModelTests.swift"
    op: update
  - path: "Tests/LazyMemoUITests/CaptureAssistTests.swift"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/2225_feature_capture-assistant-merged.md"
    kind: "followup"
  - ref: "20260916/Features_to_add/1505_feature_ios-pen-assistant-one-place.md"
    kind: "followup"
tags:
  - "assistant"
  - "web-search"
  - "privacy"
  - "ux"
  - "mcp-tool"
---
[x] 웹에서 찾기 — 키 없는 DuckDuckGo 검색을 비서의 근거로 (맥·폰)

## 추가 기능

사용자: 「웹 검색 기능을 모바일과 pc 에 넣을수있나? 지금 모델은 너무 작은가?」 → 「api키를 넣으면 안돼. 켜는방식은 "잘"」.

**모델은 안 키웠다.** 2026-09-15 앱 파이프라인 벤치가 답이다 — 날 E2B 는 answer 62%·command 30% 였고, 앱이 검색·날짜·대상을 맡고 모델에게 「여섯 장 중 답 찾아 id 대라」만 시키니 95~100%. 웹도 같은 틀: **검색은 앱이, 읽기는 모델이.** 모델이 못 하는 것(검색할지 판단·검색어 짓기·링크 골라 열기·여러 페이지 합치기)은 시키지 않는다. 에이전트식 검색은 8B+/클라우드 영역이라 범위 밖.

- **키 없는 검색**: `DuckDuckGoSearcher` — `html.duckduckgo.com/html/?q=…&kl=kr-kr` (JS 없는 브라우저용 페이지, 12:10 실측 한국어 질문에 제목·주소·발췌 열 줄; `lite.` 판은 202 봇 확인으로 막힘). 문서화된 API 가 아니다 — `NaverWebRouter` 와 같은 결정(키 필요한 검색은 두지 않는다). 쿠키·캐시 없는 ephemeral 세션. 광고 블록(`result--ad`)·`uddg=` 감싼 주소 처리. 200 인데 결과 0 이면 `no-results` 유무로 「없음」과 「막힘」을 가른다.
- **근거 재사용**: `Evidence(hit:)` — 새 ULID + url·title. 프롬프트는 「[결과 id]」로 렌더, 검증은 기존 `OutputValidator.answer` 그대로(허용 id 만·질문 낱말 겹침·원문 인용). `AssistantAnswer.sources: [WebSource]` 가 화면의 링크. `webAnswer` 태스크·`webUnavailable`/`webEmpty` 실패.
- **켜는 방식 「잘」** = 밖으로 나가는 순간이 사람의 손에 있게, 그러면서 손이 한 번만 가게:
  1. 메모 먼저. 걸리는 메모가 한 장도 없으면 모델을 부르지 않고 바로 「찾지 못했습니다」(코디네이터 변경 — 전에는 빈 근거로도 모델을 불렀다).
  2. 못 찾으면 줄이 「메모에서 찾지 못했습니다 · **웹에서 찾기**」. 맥은 빈 상자에서 ⌘↵ 한 번(`Intent.web`·`Commit.searchWeb`), 폰은 카드의 단추. 새 글을 치면 권유는 물러난다(옛 물음이 몰래 안 나가게).
  3. 「웹에서 …」「… 검색해줘」「구글에서 …」면 메모를 거치지 않고 바로(`AssistantIntent.wantsWeb`, `classify` 의 맨 앞 — 「알려줘」가 시키는 동사라도 이것이 먼저). 「인터넷」·「찾아봐」 홀로는 트리거가 아니다 — 「인터넷 요금 언제 냈지?」는 메모 질문.
  4. 검색어는 `WebQuery.make` — 「검색해줘」「웹에서」「알려줘」·물음표만 떼고 나머지는 그대로(「구글 캘린더 공유 방법」의 「구글」은 남긴다).
- **모델 없이도**: 결과 셋을 문장 없이 「웹에서 찾은 것」+ 출처·발췌로 그대로. 시뮬레이터(모델 없음)에서 이 길로 확인했다.
- 답 카드: 문장 밑에 출처(제목 accent · host tertiary)와 발췌, 누르면 브라우저(맥 `NSWorkspace.open`, 폰 `openURL`). 「웹에서 찾는 중」/「찾는 중」 라벨. 렌더 장면 `capture-web-offer`·`capture-web-answer` 추가.
- PRIVACY 표·README 표에 한 줄: **물은 말 한 줄**이 DDG 로, 누르거나 말할 때만, 메모 본문은 안 나간다.

## 동작 흐름

「달러 환율 얼마야?」→ 메모 검색 0장 → (모델 안 부름) 「메모에서 찾지 못했습니다 · 웹에서 찾기」→ ⌘↵/탭 → DDG 0.9s → 다섯 줄을 E2B 가 읽음 → 한두 문장 + 출처 링크 둘. 「웹에서 서울 내일 날씨」→ 바로 DDG.

## 검증

- `swift test` 전체 904 초록. 새 시험: DDG HTML 실물 fixture 파싱(10건·엔티티·`&amp;` 쿼리)·광고/`uddg` 처리·검색어·의도 분류, 코디네이터 웹 갈래 7건(인용→sources·못 찾음→webEmpty·빈 검색은 모델 안 부름·막힘·창구 없음·모델 없이 raw·메모 0장은 모델 안 부름), 맥 상자 라우팅(`webRouting`).
- opt-in 실접속: `LAZYMEMO_LIVE_WEB=1 LAZYMEMO_MODEL_PATH=… swift test --filter "LiveDuckDuckGoTests|RealModelTests/webAnswer"` — DDG 5건 0.9s; 실모델 「웹에서 대한민국 수도 인구 검색해줘」 5.7s(콜드 로드 포함)에 `51,084,159명` 을 k-calc.com·위키백과 둘을 인용해 답함(수도 인구 대신 총인구 — snippet 이 그러했다, E2B 읽기의 한계이자 다음 판의 본문 추출 과제).
- `scripts/render-ui.sh` 로 맥 두 장면 PNG 확인 뒤 지움. 시뮬레이터(iPhone 17) 임시 XCUITest 로 펜 「웹에서 찾기」 라벨 → 답 카드(출처 셋) 스크린샷 확인 뒤 시험 파일·PNG 삭제. 실기기·실모델이 든 폰의 손검증은 아직.
- 커밋 `d9b490d`.

## 메모

- 다음 판: 상위 1~2 페이지 본문을 Readability 류로 뽑아 ~600 토큰씩 넣으면 답 질이 한 단계 오른다(지금은 snippet 만). DDG 가 막으면 「웹에 닿지 못했습니다」— `WebSearcher` 가 프로토콜이라 갈아 끼울 자리는 있다.
- 설정 「메모에 없으면 바로 웹에서」(자동)는 넣지 않았다 — 기본은 누르기 한 번, 필요해지면 그때.
- `JARVIS_IMPLEMENTATION.md` §7 「원문 추론을 원격으로 보내지 않는다」는 그대로 참이다 — 추론은 기기 안, 나가는 것은 검색어뿐.