---
schema_version: 1
type: feature
slug: "site-launch-edition-store-switch"
status: done
difficulty: medium
created_at: "2026-09-15T13:40:06+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/ko/index.html"
    op: update
  - path: "site/index.html"
    op: update
related:
  - ref: "20260915/Chores/1339_chore_release-readiness-tests-privacy-store-copy.md"
    kind: "followup"
tags:
  - "site"
  - "release"
  - "app-store"
  - "marketing"
  - "mcp-tool"
---
[x] 소개 페이지 출시판 — App Store 단추·아이폰·다시 보기 절, 한 낱말 출시 스위치

## 추가 기능

페이지가 「0.4 서랍에 폴더」·「아이폰은 TestFlight 준비 중」·「나가는 건 MCP 뿐」·영어판 「한국어만」 상태였다. 출시판으로 다시 썼다 (ko·en 같은 구조).

- **출시 스위치 하나.** `<body data-store="soon">` — 심사 중에는 머리 배지 「심사 중」, 스토어 단추는 회색 「심사 중」, 폰 절은 「나오면 단추가 생긴다」. `"live"` 로 바꾸면 그 자리들이 검은 App Store 단추(맥·아이폰, `apps.apple.com/app/id6811815255?platform=…`)와 「나왔습니다」로 한꺼번에 바뀐다. 두 판이 같은 파일에 살아 심사 전에 밀어도 거짓이 없고, 승인 날 고칠 것이 한 낱말이다. 스토어 배지는 바깥 자원을 못 부르는 약속(pages.yml 의 검사) 때문에 인라인 SVG 로 그렸다.
- **받기 절을 둘로.** App Store(맥·아이폰 — 권하는 길, 애플 서명·샌드박스·iCloud 기본, Claude 없음) 위에, GitHub 판(Homebrew·소스 — Claude 연동·자체 업데이트는 여기만) 아래. 미공증 안내는 GitHub 판 것으로 고쳐 App Store 판을 대안으로 적었다.
- **「다시 보기」 절** — 종이 우클릭·폰의 종, 일정은 그대로, 「지금」 띠 흉내(카드 셋), 알림은 켠 기기에서만. **「메모는 파일」** 절에 iCloud 「LazyMemo」 폴더와 스토어 판 기본 자리. **프라이버시** 절은 처리방침과 같은 말로 — 본문이 나가는 길은 iCloud 와 GitHub 판의 Claude 둘, 나머지는 주소·좌표 하나, 알림은 기기 안.
- 머리: 「그리고 같은 메모를 보는 아이폰 앱」, meta 에 iOS 26·무료. nav 에 아이폰·다시 보기·받기. 영어판 「A note on language」는 영어·한국어 둘 다 되고 영상은 한국어로 찍혔다는 말로.

## 동작 흐름

정적 HTML 그대로 — CSS 두 줄(`body[data-store="soon"] .live-only`·`body[data-store="live"] .soon-only { display:none }`)이 스위치다. 승인 날: 두 파일의 `data-store` 를 `live` 로 → main 에 push → pages.yml 이 낸다 (`docs/APP_STORE_READINESS.md` 출시 날 할 일 4).

## 검증
- 로컬 서버로 띄워 ko 머리·받기·다시 보기 절을 soon/live 두 상태로 눈으로 확인, en 머리도 확인.
- pages.yml 의 외부 자원 grep 통과 (`외부 요청 없음 ✓`).