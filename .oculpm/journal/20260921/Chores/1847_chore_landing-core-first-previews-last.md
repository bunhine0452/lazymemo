---
schema_version: 1
type: chore
slug: "landing-core-first-previews-last"
status: done
difficulty: low
created_at: "2026-09-21T18:47:31+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
related:
  - ref: "20260918/Chores/2037_chore_landing-page-redesign-0-9-0.md"
    kind: "followup"
tags:
  - "site"
  - "landing"
  - "trust"
  - "preview"
  - "mcp-tool"
---
[x] 소개 페이지의 차례 — 핵심 메모 기능을 앞에, 비서·가는 길은 뒤로 「미리보기」 한 줄과 함께

## 한 일

비서·웹 검색·네이버 길찾기는 비공식 엔드포인트에 기대므로 언제든 끊길 수 있다. 소개에서 그것들이 넷째·아홉째 절에 서 있으면 첫인상이 그 위에 놓인다 — 끊긴 날 페이지가 거짓말이 된다.

- 절의 차례 (ko·en 같이): `lazy → film → themes → paper → widgets → phone → features → **assistant → route** → privacy → install`. 전에는 `themes` 다음이 `assistant`, `phone` 다음이 `route` 였다. 상단 nav 도 「종이 · 위젯 · 아이폰 · 비서 · 가는 길 · 프라이버시 · 받기」 차례로.
- 두 절의 `<h2>` 바로 밑에 `p.note.preview` 한 줄 — 「미리보기입니다. … 키 없는 공개 웹 검색(DuckDuckGo)/네이버 지도 웹의 공개 길찾기에 기댑니다 — 공식 API 가 아니라 언제든 끊길 수 있고, 끊기면 앱이 그렇다고 말합니다. 누를 때만 나갑니다」. 영어도 같은 말.
- 위젯 절에 체크상자 한 문장, 아이폰 절에 Siri 한 문장(같은 세션의 다른 두 일지).

## 검증

- 두 파일의 `<section id>` 차례를 스크립트로 읽어 위와 같음을 확인. `.note.preview` 규칙(`margin: 0 0 22px`)을 두 CSS 에 추가.
- 브라우저 렌더는 보지 않았다 — 절을 통째로 옮긴 것이라 안의 마크업은 그대로다. `verify-landing.sh` 는 이름과 달리 맥 창 검증이라 무관.

## 메모

- README 는 이미 「이 기기의 비서 (선택, 미리보기)」가 핵심 절들 뒤에 있어 손대지 않았다.