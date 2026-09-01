---
oculpm_plan: v1
id: lazymemo-v2-surface-place
title: "v2 — 에이전트의 표면과 장소"
status: done
created: 2026-08-31
updated: 2026-08-31
owner: claude-code
---

토의 `lazymemo-agent-surface` 의 열 안을 전부 실행한다. 한 문장으로 — lazymemo 는 언제·어디를 잡아 두고, 그것을 에이전트가 놓고 갈 수 있는 바탕화면이다. 순서 기준은 **권한 비용 오름차순**: 이 앱의 가장 값진 자산이 「첫 실행에 아무것도 묻지 않는다」이므로, 묻지 않고 되는 것을 먼저 다 하고 묻는 것을 뒤로 민다.

## 문을 연다 — 권한 0 {#p1-doors}
- [x] `lazymemo://add?text=` URL 스킴 — Info.plist `CFBundleURLTypes` + 핸들러. **글자만 받는다**: 파일 경로·명령·자바스크립트는 받지 않는 선을 테스트로 못 박는다 {#url-scheme}
- [x] 서비스 메뉴 「lazymemo 에 적기」 — `NSServices` 항목. 어느 앱에서든 글자를 선택하고 우클릭 {#services-menu}
- [x] `lazymemo add "…"` CLI — MCP 바이너리에 서브커맨드 하나 (`MemoService` 를 이미 쓰고 있다). 이 문으로 cron·Raycast·Alfred·Hazel·다른 에이전트가 들어온다 {#cli-add}
- [x] MCP 프롬프트 문구 5개 확정 — `/이번 주 정리`, `/오늘 뭐부터` 등. **코드보다 문장이 먼저다**: 나쁜 프롬프트는 「치워야 할 것을 하나 더」를 만든다 {#prompt-copy}
- [x] MCP `prompts/list`·`prompts/get` 구현 — 도구 목록은 모델이 읽고 프롬프트 목록은 사람이 읽는다. 지금 비어 있는 쪽이 사람 쪽이다 {#mcp-prompts}
- [x] 외부에서 들어온 임의 이름 .md 를 앱이 정본 이름(ULID)으로 받아 앉히는지 확인하고, 안 되면 그 관용을 넣는다 — 아이폰 단축어의 전제 {#vault-tolerance}
- [x] 아이폰 단축어 + README 한 문단 — iOS 앱 없이 vault 에 메모를 꽂는다. iCloud 반영 지연을 정직하게 적는다 {#ios-shortcut}

## 에이전트의 표면 — 권한 0, 차별의 핵심 {#p2-surface}
- [x] `surface_at` 이 `due`/`at` 과 어떻게 **구별되어 보이는지** 먼저 정한다 — 회의는 3시, 종이는 2시 30분. 이 구별이 화면에서 안 읽히면 필드를 넣지 않는다 {#surface-semantics}
- [x] `Memo.surface` 필드 + `knownKeys`·encode·decode·테스트. `preserved` 가 미지 키를 보존하므로 구버전 파일 호환은 이미 깨지지 않는다 {#surface-field}
- [x] `DueClock` 에 갈래 추가 — surface 시각에 `riseBriefly`. **시스템 알림 권한을 쓰지 않는다** (창 레벨 전환뿐) {#surface-clock}
- [x] MCP `create_memo`/`update_memo` 에 `surface_at` 인자 + `surface_memo(id, at)` 도구 — 「회의 30분 전에 이거 띄워줘」가 성립한다 {#surface-mcp}

## 장소 — 새 축이지만 자리를 바꾸지 않는다 {#p3-place}
- [x] `place:` 프론트매터 + 선택 `geo: 위도,경도`. `knownKeys`·encode(시간 뒤에 놓아 우선순위를 적는다)·decode·테스트. 좌표 없이 문자열만으로도 성립해야 한다 {#place-field}
- [x] `PlaceParser` — 읽는 규칙은 **둘뿐**: `@강남역` 형태와 한국 주소 패턴(시/도·구/군·로/길·번지, 우편번호 5자리). **산문에서 추측하지 않는다** — 오탐은 안 읽느니만 못하다 {#place-parser}
- [x] 종이 위 잉크 자국 + 누르면 시스템 지도. **앱 안에 지도 뷰를 만들지 않는다** — 재질이 둘이 되면 §14.5 가 깨진다 {#place-ink}
- [x] 달력 줄에 `3시 치과 · 강남역` + 그 줄에서 바로 길찾기 — **나가기 전에 필요한 전부가 한 줄에 있다.** 시간과 장소를 함께 가진 값이 여기서 나온다 {#place-in-calendar}
- [x] `⌥⌘L` 「지금 여기」 — 현재 위치를 역지오코딩해 종이 한 장. `NSLocationWhenInUseUsageDescription` 추가(지금 plist 엔 usage description 이 하나도 없다). **처음 누를 때만 묻고, 거절하면 그 단축키는 조용히 없는 것이 된다** {#here-hotkey}
- [x] 클립보드에서 온 주소 알아보기 — `⌥⌘V` 와 합류. 카카오맵·네이버지도 공유 텍스트는 정형이라 오탐이 낮다 {#place-from-clipboard}
- [x] MCP 에 `place`/`geo` 인자 + 장소 부분일치 찾기 — 「강남에서 할 일 뭐 있어?」 {#place-mcp}
- [x] 아이폰 단축어에 「현재 위치」를 물려 `place:`+`geo:` 가 박힌 .md 를 떨군다 — **iOS 앱 없이 아이폰 위치 메모.** macOS 쪽 코드는 0줄 {#ios-shortcut-place}

## 받침을 메운다 — 차별이 아니라 없으면 무너지는 것 {#p4-foundations}
- [x] EventKit 읽기 전용 연동 — **달력을 처음 열 때만** 묻고, 거절하면 영영 안 묻는다. `surface_at` 이 「회의 30분 전」을 하려면 회의를 알아야 한다 {#eventkit-read}
- [x] 남의 일정과 우리 종이를 **재질로** 구별해 그린다 — 착각하면 지울 수 없는 것을 지우려 든다 {#eventkit-ink}
- [x] 반복 일정과 `Tidy.past` 의 충돌 해소안 먼저 — 지나면 물러나는 대신 **다음 회차로 걸어간다**. 규칙을 정하지 않고 필드를 넣지 않는다 {#recurring-vs-tidy}
- [x] `every:` 필드 + `NaturalDateParser` 확장(「매주 화요일 8시」). 분리수거·약·정기결제 — 지금은 적을 수가 없다 {#recurring-field}
- [x] 빠른 입력 시간·형태 칩 — `@어제`, `@지난주`, `#링크`, `#사진`, 그리고 장소 칩 `@강남` {#recall-chips}
- [x] 결과 5개 상한을 넓히고 최근 본 것·자주 여는 것 순으로 — Stickies 가 죽은 이유 중 하나가 검색 부재다 {#recall-ranking}

## 대담한 것 — 새 실패 유형과 신뢰 비용 {#p5-bold}
- [x] `which claude` 탐지 — **있으면 켜지고 없으면 조용히 없다.** 광고하지 않고 스크린샷에도 넣지 않는다 {#claude-cli-detect}
- [x] 앱이 처음 갖는 「기다리는 상태」를 종이의 낱말로 말하는 법 — 서브프로세스 지연·실패를 종이 위에서 어떻게 적을 것인가 {#claude-wait-state}
- [x] 종이 위 조작 「정리」 — `claude` 서브프로세스로 이 메모를 다듬는다. API 키 불필요 원칙 유지(구독 인증 재사용) {#claude-tidy-action}
- [x] 아침 브리핑 한 장 — 사용자가 아무것도 하지 않아도 매일 Claude 가 종이를 놓는다. 에이전트 표면의 완성형 {#claude-morning-brief}
- [x] 지오펜스 프라이버시 문단 다시 쓰기 + 설정 표시 — **Always 권한**은 링크 카드와 비교가 안 되는 무게다. 켜져 있다는 사실이 메뉴에서 보이지 않으면 약속을 지킨 것이 아니다 {#geofence-design}
- [x] 「가면 떠오른다」 — `CLCircularRegion` 으로 마트에 도착하면 장보기 종이가 뜬다. **기본 꺼짐**, 설정에서 명시적으로 켤 때만 {#geofence-surface}

## 앱 안에서 업데이트 {#p6-update}
- [x] `SemanticVersion` — 0.10.0 은 0.9.0 보다 **뒤**다. 문자열로 견주면 틀리는 자리라 시험이 먼저다 {#version-compare}
- [x] `UpdateCheck` — GitHub 릴리스에서 최신 판과 zip 주소를 읽는다. 받아오는 함수를 주입해 네트워크 없이 시험한다 {#update-check}
- [x] 설치 경로 판별 — **Homebrew 로 깔았으면 스스로 바꾸지 않는다.** 바꾸면 brew 의 장부가 어긋나 다음 `brew upgrade` 가 깨진다 {#update-source}
- [x] 설정 `checksForUpdates` + 프라이버시 문단 — 네트워크 경로가 하나 더 생긴다. 끌 수 있고, 나가는 것은 메모가 아니며, README·설계문서에 적는다 {#update-privacy}
- [x] 릴리스에 `.sha256` 자산을 함께 올린다 — 받은 것이 온전한지 앱이 스스로 본다 {#release-sha-asset}
- [x] 내려받아 바꾸기 — sha256 대조 → 서명 확인 → 판 확인 → 번들 교체 → 다시 열기 {#update-apply}
- [x] 메뉴에 업데이트 한 줄 — 새 판이 있으면 그 사실이 **묻지 않아도 보이게** {#update-menu}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-08-31T15:38:53+09:00 | #place-field | claude-code | ☐→x | 20260831/Features_to_add/1538_feature_place-field-parser-and-mcp.md | place/geo 프론트매터 + hasPlace. 깨진 geo 는 preserved 로 보존 |
| 2026-08-31T15:38:58+09:00 | #place-parser | claude-code | ☐→x | 20260831/Features_to_add/1538_feature_place-field-parser-and-mcp.md | @낱말 + 통째 주소만. 산문 속 주소·우편번호는 오탐 위험으로 뺐다 |
| 2026-08-31T15:39:03+09:00 | #place-mcp | claude-code | ☐→x | 20260831/Features_to_add/1538_feature_place-field-parser-and-mcp.md | create/update 에 place·geo, list_memos 에 부분일치 필터. verify-mcp 5항목 추가 |
| 2026-08-31T16:17:10+09:00 | #place-ink | claude-code | ☐→x | 20260831/Features_to_add/1617_feature_place-ink-on-paper-and-calendar.md | 꼬리에 핀 잉크 + 시스템 지도. 세 줄로 접혀 ViewThatFits 로 다시 짰다 |
| 2026-08-31T16:17:15+09:00 | #place-in-calendar | claude-code | ☐→x | 20260831/Features_to_add/1617_feature_place-ink-on-paper-and-calendar.md | 쉴 때 장소, 포인터 오면 핀 버튼. 낱말 캡슐은 둘까지가 한계였다 |
| 2026-08-31T16:29:59+09:00 | #version-compare | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | SemanticVersion — 0.10.0 > 0.9.0 을 시험으로 못 박았다 |
| 2026-08-31T16:30:04+09:00 | #update-check | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | GitHub 릴리스 파싱. 받아오는 함수를 주입해 네트워크 없이 시험 |
| 2026-08-31T16:30:10+09:00 | #update-source | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | brew 가 놓은 자리의 앱만 brew 에 미룬다 — 다른 데 둔 앱은 스스로 바꾼다 |
| 2026-08-31T16:30:15+09:00 | #update-privacy | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | checksForUpdates + 메뉴 표시 + README·DESIGN §9.3/§12.4 |
| 2026-08-31T16:30:21+09:00 | #release-sha-asset | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | 세 갈래 업로드 모두에 .zip.sha256 을 함께 올린다. 다음 태그부터 붙는다 |
| 2026-08-31T16:30:26+09:00 | #update-apply | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | 검사 셋 + 밀어 두고 쓰는 자리 바꾸기. 스크립트 양쪽 경로를 시험이 실제로 돌린다 |
| 2026-08-31T16:30:32+09:00 | #update-menu | claude-code | ☐→x | 20260831/Features_to_add/1629_feature_in-app-update.md | 창을 띄우지 않는다 — 메뉴 한 줄. brew 면 명령을 클립보드에 넣어 준다 |
| 2026-08-31T16:45:43+09:00 | #url-scheme | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | 글자만 받는다 — run?cmd= 류가 파싱조차 안 되는 것을 시험으로 못 박았다 |
| 2026-08-31T16:45:48+09:00 | #services-menu | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | NSServices + servicesProvider. NSMessage 와 셀렉터의 짝을 시험이 지킨다 |
| 2026-08-31T16:45:54+09:00 | #cli-add | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | 인자 없으면 예전대로 MCP 서버 — 이미 등록한 사람의 연동을 깨지 않는다 |
| 2026-08-31T16:45:59+09:00 | #prompt-copy | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | 문구 규칙 셋 — 지우기 전에 묻는다·적게 돌려준다·날짜와 장소를 채운다 |
| 2026-08-31T16:46:05+09:00 | #mcp-prompts | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | prompts/list·get 구현 + capabilities. verify-mcp 6항목 추가 |
| 2026-08-31T16:46:10+09:00 | #vault-tolerance | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | MemoVault.adopt — 이름을 맞추라 하지 않고 우리가 붙인다. reconcile 첫 줄 |
| 2026-08-31T16:46:16+09:00 | #ios-shortcut | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | README 「어디서든 던지기」 — 두 동작짜리 단축어. iCloud 지연을 정직하게 적었다 |
| 2026-08-31T16:46:21+09:00 | #place-from-clipboard | claude-code | ☐→x | 20260831/Features_to_add/1645_feature_inbound-doors-and-mcp-prompts.md | ClipboardCapture 를 InboundDoor 로 넘긴 부수 효과 — 복사한 주소가 place 가 된다 |
| 2026-08-31T17:01:24+09:00 | #surface-semantics | claude-code | ☐→x | 20260831/Features_to_add/1701_feature_surface-at-agent-surface.md | 두 칩으로 나누지 않는다 — 「오후 2:30 · 30분 전」한 조각. 일정 없으면 홀로 서되 못 누른다 |
| 2026-08-31T17:01:30+09:00 | #surface-field | claude-code | ☐→x | 20260831/Features_to_add/1701_feature_surface-at-agent-surface.md | surface 필드 + surfacesAt + surfaceLead. isScheduled 는 여전히 안 본다 |
| 2026-08-31T17:01:35+09:00 | #surface-clock | claude-code | ☐→x | 20260831/Features_to_add/1701_feature_surface-at-agent-surface.md | DueClock 네 자리를 surfacesAt 하나로. 알림 권한은 여전히 안 쓴다 |
| 2026-08-31T17:01:41+09:00 | #surface-mcp | claude-code | ☐→x | 20260831/Features_to_add/1701_feature_surface-at-agent-surface.md | create/update 에 surface_at + surface_memo 도구. 일정을 안 건드리는 것을 verify 가 센다 |
| 2026-08-31T17:25:31+09:00 | #eventkit-read | claude-code | ☐→x | 20260831/Features_to_add/1725_feature_eventkit-read-only-agenda.md | 묻는 자리는 달력 첫 열기 하나. 거절하면 그 사실이 설정 메뉴에 보인다 |
| 2026-08-31T17:25:38+09:00 | #eventkit-ink | claude-code | ☐→x | 20260831/Features_to_add/1725_feature_eventkit-read-only-agenda.md | 속 빈 막대·흐린 글씨·조작 없음. 격자의 번진 잉크에는 일부러 안 넣었다 |
| 2026-08-31T17:26:22+09:00 | #recurring-vs-tidy | claude-code | ☐→x | 20260831/Features_to_add/1726_feature_recurring-walks-instead-of-retreating.md | Tidy.reason 이 건너뛰고 Tidy.rolled 가 앞으로 보낸다. 걸어가기가 치우기보다 먼저 |
| 2026-08-31T17:26:28+09:00 | #recurring-field | claude-code | ☐→x | 20260831/Features_to_add/1726_feature_recurring-walks-instead-of-retreating.md | every 는 주기만 말한다 — 요일·일은 날짜가 들고 있다. 파서·문·MCP 전부 읽는다 |
| 2026-08-31T17:44:20+09:00 | #recall-chips | claude-code | ☐→x | 20260831/Features_to_add/1744_feature_lazy-recall-filters-and-recency.md | 새 문법 없이 #·@·날짜칩 그대로. 무엇으로 걸렀는지 화면에 적는다 |
| 2026-08-31T17:44:26+09:00 | #recall-ranking | claude-code | ☐→x | 20260831/Features_to_add/1744_feature_lazy-recall-filters-and-recency.md | 상한은 이미 5→20+pool 200. 읽은 것도 「요즘」에 넣었다. 「자주 여는 것」은 감쇠 위험으로 뺐다 |
| 2026-08-31T19:07:06+09:00 | #claude-cli-detect | claude-code | ☐→x | 20260831/Features_to_add/1906_feature_claude-on-the-paper.md | GUI 앱 PATH 함정 — 고정 목록 뒤에 로그인 셸에게 묻는 길을 뒀다. 찾은 자리는 적어 둔다 |
| 2026-08-31T19:07:13+09:00 | #claude-wait-state | claude-code | ☐→x | 20260831/Features_to_add/1906_feature_claude-on-the-paper.md | 상한 90초·글이 바뀌면 버림·되돌리기 8초·실패는 말한다. 종이를 덮지는 않는다 |
| 2026-08-31T19:07:19+09:00 | #claude-tidy-action | claude-code | ☐→x | 20260831/Features_to_add/1906_feature_claude-on-the-paper.md | 종이 위 ✧. 버튼이 다섯이 되며 꼬리가 비울 폭도 함께 바뀐다(controlCount) |
| 2026-08-31T19:07:25+09:00 | #claude-morning-brief | claude-code | ☐→x | 20260831/Features_to_add/1906_feature_claude-on-the-paper.md | 기본 꺼짐 — 누르지 않았는데 값이 드는 유일한 기능. 종이는 한 장을 다시 쓴다 |
| 2026-08-31T19:28:36+09:00 | #here-hotkey | claude-code | ☐→x | 20260831/Features_to_add/1928_feature_here-hotkey-and-geofence.md | ⌥⌘L — 처음 누를 때만 묻고 한 번 재고 끊는다. 거절하면 설정 메뉴가 적어 둔다 |
| 2026-08-31T19:28:43+09:00 | #ios-shortcut-place | claude-code | ☐→x | 20260831/Features_to_add/1928_feature_here-hotkey-and-geofence.md | 단축어에 place+geo 를 물린다 — 좌표까지 넣으면 「가면 떠오르기」에도 걸린다 |
| 2026-08-31T19:28:49+09:00 | #geofence-design | claude-code | ☐→x | 20260831/Features_to_add/1928_feature_here-hotkey-and-geofence.md | 본론은 지오펜스가 아니라 문서였다 — claude CLI 로 거짓이 된 문장을 표 둘로 다시 썼다 |
| 2026-08-31T19:28:55+09:00 | #geofence-surface | claude-code | ☐→x | 20260831/Features_to_add/1928_feature_here-hotkey-and-geofence.md | 기본 꺼짐·좌표 있는 메모만·스무 개 상한을 세어 적음·도착만. 알림 권한은 여전히 안 쓴다 |
<!-- oculpm:plan-log end -->
