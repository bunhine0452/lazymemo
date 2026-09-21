---
schema_version: 1
type: feature
slug: "web-page-evidence-and-digest-memo"
status: done
difficulty: high
created_at: "2026-09-18T19:09:44+09:00"
session_id: "20260918-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoAssistant/PageReader.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Digest.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/ClaudeProvider.swift"
    op: create
  - path: "Sources/LazyMemoAssistant/Contracts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Coordinator.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/Prompts.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/WebSearch.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/WebFollowUp.swift"
    op: update
  - path: "Sources/LazyMemoAssistant/OutputValidator.swift"
    op: update
  - path: "Sources/LazyMemoAssistantUI/AssistantModel.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/PageReaderTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/DigestTests.swift"
    op: create
  - path: "Tests/LazyMemoAssistantTests/WebSearchTests.swift"
    op: update
  - path: "Tests/LazyMemoAssistantTests/WebFollowUpTests.swift"
    op: update
  - path: "Tests/Fixtures/Assistant/page-ko-blog.html"
    op: create
  - path: "Tests/Fixtures/Assistant/page-en-wiki.html"
    op: create
  - path: "Tests/Fixtures/Assistant/page-nav-heavy.html"
    op: create
  - path: "docs/PRIVACY.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260917/Features_to_add/1228_feature_assistant-web-search-ddg.md"
    kind: "followup"
  - ref: "20260917/Features_to_add/2002_feature_web-answer-follow-ups-results-list.md"
    kind: "followup"
tags:
  - "assistant"
  - "web-search"
  - "readability"
  - "digest"
  - "privacy"
  - "claude-cli"
  - "mcp-tool"
---
[x] 웹의 답을 정확하게, 남긴 메모를 읽기 좋게 — 결과 페이지 본문을 근거로 읽고 「정리해서 남기기」에 자리를 준다

## 추가 기능

사용자: 「AI 가 어떠한 질문이라도 정확하게 답변해야하며, 웹 검색 후 정리하여 메모 내용이 어떤 데이터라도 "잘" 정리되어 사용자가 보기 편하게 해야한다.」 · 소유자 제약(2026-09-17): **API 키는 끝까지 없다.**

앞선 판(09-17 12:28)의 마지막 줄이 이 판의 과제였다 — 「대한민국 수도 인구」에 모델이 *총인구* 를 답한 것은 모델이 틀려서가 아니라 **발췌에 그것밖에 없었기 때문**이다. 근거를 넓히고, 그 위에 메모의 자리를 세웠다.

- **페이지 본문이 근거다** (`PageReader.swift`). DDG 가 결과를 주면 앞의 **세 쪽**을 나란히 받아(쿠키 없는 ephemeral 세션 · 한 쪽 8초 · 1MB · HTML/XML/텍스트만) 읽을 만한 글만 뽑는다. 뽑는 규칙 셋 — ① 글이 아닌 것(script·style·nav·header·footer·aside·form)을 통째로 버리고 **줄줄이 선 링크 넷 이상**도 차림표로 본다(한국 사이트의 차림표는 `<nav>` 가 아니라 `<div id="gnb">` 안의 `<a>` 열이고, 그것을 두면 「홈 날씨 태풍 로그인…」 한 줄이 40자를 넘어 본문 행세를 한다) ② `<article>`·`<main>` 중 **글이 가장 많은 것**만 본다(「관련 기사」 카드도 `<article>` 이다) ③ 남는 부스러기는 **긴 문단이 처음 나온 줄부터**로 자르되, **마지막 문단 뒤로는 한 걸음 더** 간다 — 가격·사양·시각표는 하필 글의 맨 끝에 붙고 거기서 자르면 「어떤 데이터든」의 그 데이터가 통째로 사라진다(바닥글을 만나면 멈춘다). EUC-KR 는 헤더·`<meta charset>` 이 말하는 대로 읽는다(IANA 이름을 그대로 넘긴다). `Evidence.passage` 는 **덧붙는 자리**다 — 화면은 여전히 `excerpt`(검색 발췌)를 그리고, 모델·검증만 `readable` 로 둘을 함께 읽는다. 몫은 `PageBudget` — 셋이면 한 쪽에 800자(합 2400자), 4096 토큰 안에 지시문·물음 자리가 남는다.
- **정확도** — ① 검색어 `WebQuery.make` 가 시키는 말을 더 뗀다(「찾아줘」「궁금해」「please」「좀」·느낌표), **이름·숫자·날짜는 한 글자도 안 건드린다**(「2026년」이 빠지면 검색 엔진은 올해를 답한다). ② 첫 검색이 빈손이면 `WebQuery.simplify` 로 **한 번 더** — 물음말·풀이말을 떼고 알맹이만, 글자는 원문 그대로(「Swift 6.2 에서 뭐가 바뀌었는지」→「Swift 6.2」). 줄일 것이 없으면 같은 검색을 두 번 던지지 않는다. ③ 프롬프트가 「베껴라」에서 **「견줘 묶어라」**로 — 결과들을 함께 읽고, 여럿이 같은 말을 하면 그것이 답, 묻지 않은 것은 적지 마라(「수도의 인구」를 물었는데 나라 전체 인구가 보이면 답이 아니다), evidence 는 쓴 순서대로 여럿. ④ `webAnswer` 출력 예산 384 → **512**(여러 쪽을 견주라 시킨 뒤로 JSON 끝이 잘렸다), digest 는 640. ⑤ 인용 검증은 그대로이되 개념 세기를 `readable`(발췌+본문)로 — 발췌에만 없고 본문에 있는 낱말이 흔하다. ⑥ 엔티티 풀기에서 **`&amp;` 를 맨 나중에** — 먼저 풀면 `&amp;lt;` 가 `<` 가 되어 글에 적힌 「&lt;」를 태그로 둔갑시킨다(사전 순회라 순서가 운에 달려 있던 자리).
- **정리한 메모에 자리가 생겼다** (`Digest.swift`, 새 `AssistantTask.digest`). `# 제목`(물은 말) · 답 한두 문장 · `## 핵심` 목록 · 값이 여럿이면 `## 세부`(표·번호 목록·`- [ ]`) · `## 출처`(제목 — 주소) · 꼬리. **틀은 앱이 들고 모델은 가운데만 쓴다** — 제목·출처·꼬리를 시키면 작은 모델은 주소를 지어내고 제목을 두 번 적는다. 2B 를 위해 본보기 한 장(날씨 표)을 프롬프트에 넣었다. 앱이 다시 보는 것 넷: 코드펜스·제 손으로 단 제목·「출처」 아래 전부·본문에 흘린 주소(마크다운 링크는 이름만 남긴다)를 걷고, 「핵심」이 없으면 발췌로 세우고, 쓸 게 없으면 `Digest.compose` 로 **앱만으로** 같은 자리를 채운다 — 「정리해서 남기기」를 눌렀는데 아무것도 안 남는 일은 없다. 정리는 **다시 검색하지 않는다**: 앱이 쥔 답·본문을 초안(`Digest.draft`)으로 넘긴다. 「메모로 남기기」도 같은 자리다(`WebFollowUp.body` → `Digest.keep`) — 앞선 판은 제목 없이 «제목/발췌/주소» 뭉치를 쌓아 목록에 설 제목조차 없었다.
- **맥에 `claude` 가 있으면 빌린다** (`ClaudeCLIProvider`, `AssistantCoordinator.adopt(cli:)`). 빌리는 일은 **셋뿐** — 웹의 답·다듬기·정리. 메모에서 답 찾기와 시키기는 **메모 본문이 나가는 일**이라 언제나 이 기기 안이다(DESIGN §9.3 의 표가 그대로 참이어야 한다). 키는 여전히 없다(사용자 구독, §9.4). 없는 사람에게는 아무것도 달라지지 않는다. **아직 꽂히지 않았다** — `AppDelegate` 의 한 줄(`assistant.adoptClaude(runner)`)은 그 파일을 가진 쪽에 넘겼다.

## 동작 흐름

「2026년 최저임금 얼마야?」→ DDG 0.9s(5건) → 앞의 세 쪽을 나란히 8초 안에 받아 각 800자 본문 → 모델이 셋을 견줘 「시간당 10,320원, 2025년보다 2.9% 인상」 + 출처 둘 → 「이걸 어떻게 할까요?」 → [정리해서 남기기] → 모델이 답·핵심·세부를 쓰고 앱이 제목·출처·꼬리를 달아 메모 한 장. 빈손이면 「2026년 최저임금이」로 한 번 더 던지고, 본문을 한 쪽도 못 읽으면 발췌가 근거로 남고, 모델이 넘어지면 결과 그대로 — 어느 길로도 끝이 있다.

## 검증

- `./scripts/test.sh --filter LazyMemoAssistantTests` **87건 초록**(15 suite). 새 시험: 페이지 읽기 6건(한국어 블로그 `<article>`·영어 위키 `<main>`+엔티티·차림표뿐인 페이지·PDF/이미지/JSON 거르기·EUC-KR·문장 경계 자르기, fixture 3장), 정리 9건(모델 글 끼우기·제목/출처/지어낸 주소 걷기·핵심 빠짐 메우기·모델 없이·빈 답·구조 검사·초안·「메모로 남기기」), 코디네이터 7건(앞 세 쪽만 본문·못 읽어도 답·재검색·두 번 빈손·같은 검색 안 던짐·정리는 재검색 없음·CLI 는 셋만), 검색어 3건.
- `swift build` 전체 초록. `swift run lazymemo-assistant-bench --retrieval-only` — 검색 Recall@6 **21/22**(모델 없이 도는 길, 이번 변경과 무관하게 그대로).
- **실접속 end-to-end**(`LAZYMEMO_LIVE_WEB=1`, 새 시험 「검색 → 앞의 세 쪽 본문 → 모델 없이 정리한 메모 한 장」): DDG 5건 → 세 쪽 본문 794·770·744자 → 정리한 메모에 「2026년 1월 1일부터 최저시급 10,320원, 2025년 10,030원에서 290원(2.9%) 인상」과 출처 셋. 1.2초.
- 사람이 손으로 본 화면은 없다 — 맥 앱을 띄우거나 시뮬레이터를 돌리지 않았다(같은 워킹트리에서 다른 세션이 UI 를 고치는 중이었다). **실모델(E2B)로 재 본 것도 없다** — 모델을 받지 않는 것이 규칙이라, 출력 예산 512 가 실모델에서 정말 안 잘리는지는 다음 사람이 잰다.

## 메모

- **프라이버시 표를 같이 고쳤다** (`docs/PRIVACY.md`·`README.md`). 나가는 것이 하나 늘었다 — 검색어뿐이던 것이 이제 **결과 앞 세 쪽에 접속**한다. 물은 말은 그 사이트로 안 가지만 **어느 페이지를 열었는지는 그 사이트가 알게 된다**. 링크 카드 때와 같은 잣대다(§9.3 의 조건 셋): 적지 않으면 문서가 거짓말이 된다. `docs/DESIGN.md` §9.3 의 표에는 「웹에서 찾기」 행이 **원래부터 없다** — 그 빠짐은 이번에 만든 것이 아니고, 고칠 때 이 행도 같이 넣을 것.
- `claude` 를 꽂으면 **검색 결과 본문과 물은 말이 claude 로 나간다**(메모 본문은 아니다). `adoptClaude` 를 부르는 한 줄을 넣는 사람이 PRIVACY 표에 그 행도 함께 넣어야 한다.
- `WebPageReader` 의 1MB 상한은 **읽는 양**이지 받는 양이 아니다(`URLSession.data` 는 다 받고 나서야 크기를 안다). 받는 쪽은 8초가 잡는다 — 더 조이려면 delegate 로 `didReceive response` 에서 끊어야 하고, 그 기계를 지금 들일 값은 없다고 봤다.
- 모델 없이 짓는 「핵심」은 DDG 발췌를 그대로 옮긴다(140자로 자름). 실측에서 첫 줄이 「🚨 최저임금 위반 시 처벌은?」으로 시작했다 — 정확하지만 물음의 한가운데는 아니다. 모델(또는 `claude`)이 있으면 이 자리는 모델의 글이다.