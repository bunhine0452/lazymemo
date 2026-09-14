---
schema_version: 1
type: chore
slug: "asc-record-and-metadata"
status: done
difficulty: medium
created_at: "2026-09-14T17:53:02+09:00"
session_id: "20260914-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/STORE_LISTING.md"
    op: create
  - path: "README.md"
    op: update
related:
  - ref: "20260914/Chores/1715_chore_mac-store-screenshots-and-checklist-fix.md"
    kind: "followup"
  - ref: "20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md"
    kind: "followup"
tags:
  - "app-store"
  - "asc"
  - "metadata"
  - "ios"
  - "mac"
  - "browser"
  - "mcp-tool"
---
[x] ASC 에 `lazymemo` 레코드(Apple ID 6811815255)를 만들고 빌드 빼고 전부 채웠다 — 사용자가 브라우저에 로그인해 둔 세션을 Chrome 도구로 조작

## 한 것

- **원고를 먼저 파일로** — `docs/STORE_LISTING.md`. 이름·번들 id·SKU·카테고리·연령·URL 셋·개인정보 응답·심사 메모·부제·홍보 문구·키워드·설명(ko)·스크린샷 순서·영어 부제/키워드. 글자 수 제한을 전부 재어 넣었다. README 설계 절에서 링크.
- `git push origin main` (19 커밋) — `site/privacy/` 가 Pages 로 나가야 개인정보 URL 이 200 이다. 푸시 뒤 https://bunhine0452.github.io/lazymemo/privacy/ → 200 확인.
- **레코드**: 플랫폼 iOS+macOS, 한국어, `io.github.bunhine0452.lazymemo`(Xcode 가 등록해 둔 XC App ID 그대로), SKU `lazymemo`, 전체 액세스.
- **앱 정보**: 부제 「한 줄이면 메모, 날짜는 앱이 읽는다」(부제는 플랫폼별이 아니라 앱 공통 한 칸이다), 카테고리 생산성. 연령 등급 7단계 설문 전부 「없음/아니요」 → **4+** (대한민국 「전체」).
- **개인정보**: 처리방침 URL + 「데이터를 수집하지 않음」 게시.
- **가격**: $0.00 기준 175개 국가 · 사용 가능 여부 모든 국가.
- **iOS 1.0 / macOS 1.0 버전 페이지**: 홍보 문구·설명·키워드·지원 URL·마케팅 URL·저작권 `2026 Kim Hyunbin`·심사 메모(영어)·연락처(이름·이메일; **전화번호는 사용자가 직접 브라우저에서 넣었다**)·「로그인 필요」 해제. 스크린샷 iPhone 6.9″ 5장(`dist/store/ios/`), Mac 5장(`dist/store/mac/`).

## 부딪힌 것

- 폼의 체크박스·<select> 는 `form_input` 으로 값만 바꾸면 React 가 못 본다 — 실제 클릭이 필요했다. 텍스트는 `type` 으로 치면 한글 IME 가 한 글자를 바꿔치기했다(「바뀌면」→「바뀝면」). **native setter + input 이벤트**로 값을 박고 JS 로 원문과 대조해 IDENTICAL 을 확인하는 쪽이 확실했다.
- 버전 페이지 첫 화면의 iPhone 드롭존은 6.5″ 규격만 받는다 — 6.9″(1320×2868)는 「미디어 관리」의 6.9 슬롯에 올려야 하고, 그러면 6.5 슬롯이 「6.9 디스플레이 사용」으로 따라온다.
- 여러 장을 한 번에 올리면 순서가 뒤섞인다. iPhone 쪽은 끌어서 바꿀 수 있었지만 Mac 미디어 관리는 끌기가 안 먹어 **모두 삭제 → 한 장씩 차례로 업로드**로 순서를 맞췄다.
- 홍보 문구의 `⌥⌘N` 이 「유효하지 않은 문자」로 거절 — 「단축키 한 번」으로 바꿨다. 설명 본문의 같은 기호는 통과.
- macOS 저장에서 409 — 첫 저장이 이미 `appStoreReviewDetails` 를 만들었는데 페이지가 POST 를 반복했다. 강제 새로고침 뒤 확인하니 값은 전부 남아 있었다(Network 탭으로 봄).
- 사용자와 같은 페이지를 동시에 만졌다 — 이름·이메일이 두 번 찍혀(`KimKim`) JS 로 바로잡았고, 그러다 `byVal('Kim')` 이 저작권 칸을 먼저 잡아 덮어써 다시 넣었다. **같은 폼을 둘이 만지면 라벨로 찾아 값을 박고 다시 읽어 확인한다.**

## 검증

- 두 버전 페이지 모두 강제 새로고침 뒤 JS 로 모든 칸을 읽어 원고와 대조 — 설명은 IDENTICAL, 연락처·메모·로그인 해제 남아 있음, 「저장」 비활성(변경 없음)·「심사에 추가」 활성.
- 미디어 관리: iPhone 6.9″ 5장 pen→datesheet→list→calendar→editor, Mac 5장 capture→desk→drawer→folder→desk-dark.

## 남은 것

- 빌드. `xcodebuild archive` 가 여전히 `No Accounts` — Xcode › Settings › Accounts 로그인 뒤 `./ios/scripts/archive.sh` 와 `./ios/scripts/archive.sh mac`. 올라오면 버전 페이지 「빌드」에서 고르고 「심사에 추가」.
- 심사 메모의 대표 이메일은 사용자 계정 메일. 영어 로컬라이제이션은 아직 안 넣었다(첫 제출에 필수는 아님).