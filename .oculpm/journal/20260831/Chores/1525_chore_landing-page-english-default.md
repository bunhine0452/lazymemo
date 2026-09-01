---
schema_version: 1
type: chore
slug: "landing-page-english-default"
status: done
difficulty: low
created_at: "2026-08-31T15:25:59+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: create
  - path: ".github/workflows/pages.yml"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "site"
  - "docs"
  - "i18n"
  - "pages"
  - "mcp-tool"
---
[x] 소개 페이지를 다시 짓는다 — 영어를 기본으로, 말투는 예의 바르게

사용자 요청: 랜딩 페이지를 제대로 만들고, 말투를 예의 바르게, **영어를 기본 언어로**.

## 바꾼 것

- `site/index.html` 을 **영어 정본**으로 다시 썼다. 말투는 명령형·단정형(「…한다」)에서 독자에게 말을 거는 정중한 어조로 옮겼다 — 특히 공증 문단은 변명이 아니라 **먼저 밝히는 고지**로 다시 적었다("One thing we owe you up front").
- 기존 한국어 본문은 버리지 않고 `site/ko/index.html` 로 옮기되, 같은 규칙으로 **존댓말**로 고쳐 썼다. 두 페이지가 `hreflang`(en·ko·x-default)과 상단/바닥의 언어 전환 링크로 서로를 가리킨다. canonical 은 각자 자기 자신.
- 페이지 자체도 손봤다 — 상단 이동줄, 히어로 화면(종이 한 장), 설치 카드에 **복사 단추**, 조작 표(단축키 8줄), 화면 3장, 파일·Claude·프라이버시 절.
- **앱 UI 가 한국어뿐이라는 사실을 영어 페이지에 적어 두었다.** 화면 그림이 전부 한국어라, 적지 않으면 그림이 거짓말이 된다. 영어 화면을 새로 렌더하는 대신 사실을 밝히는 쪽을 골랐다 — 앱이 실제로 그렇게 나가기 때문이다.
- `README.md` 의 소개 페이지 링크를 한국어판으로 돌리고 영어판을 괄호로 덧붙였다.

## 배포 검사도 함께 넓혔다

`pages.yml` 의 「바깥으로 나가는 것이 없는지」가 `site/index.html` **한 파일만** 보고 있었다. 페이지가 둘이 된 순간 그 검사는 한국어판을 통과시켜 준다 — 웹폰트 한 줄이 조용히 들어와도 못 잡는다. 그래서 `site/` 아래 모든 html 로 넓히고, 거는 자리를 **가져오는 자리**(`src=`·`url(`·`rel=stylesheet|preconnect|preload`)로 한정했다. 본문의 `<a href>` 와 `og:image` 까지 막으면 GitHub 링크조차 못 달기 때문이다.

## 검증

로컬 정적 서버로 두 페이지를 브라우저에서 직접 따라갔다 — 밝은/어두운 모드, 386px 폭(가로 넘침 0), 복사 단추 동작(「Copy → Copied」, 폭 고정으로 옆 덩이 밀림 없음)까지 눈으로 확인했다. 히어로 그림이 `.wrap` 의 `margin: 0 auto` 를 뒤엎어 왼쪽으로 붙던 것과, 좁은 화면에서 상단 이동줄이 상표 위로 올라타던 것을 그 과정에서 잡았다. CI 와 같은 grep 을 그대로 돌려 「외부 요청 없음 ✓」.