# 빠른 입력 × 비서 — 「메모에게 묻기」 창을 없애고 ⌥⌘N 말풍선 하나로

> 2026-09-15 · 설계만. 코드는 다음 세션이 옮긴다. 캔버스: 「빠른 입력 비서」(아트보드 A~G).
> 근거는 애플 원문(`apple-design-principles.md` §10 에 오늘 더한 맥 popover·검색 필드·텍스트 필드·피드백·되돌리기·데이터 입력)과 lazymemo 의 결정(DESIGN.md §8·§7.1·§14, D6, JARVIS §5). 부딪히는 자리는 §4 에 판정을 적었다.

## 0. 한 문장

**상자는 하나고, 사람은 모드를 고르지 않는다.** 적으면 메모, 찾으면 검색, 물으면 답, 시키면 한다 — 어느 것인지는 앱이 가린다(`AssistantIntent`). 힌트 줄의 ⌘↵ 라벨이 «지금 무엇을 할지» 를 말하고, 앱이 하나를 더 알아야 할 때만 **그 한 가지를 묻고 상자가 닫히지 않는다.**

## 1. 결정과 근거

| # | 결정 | 근거(원문) | lazymemo 의 결정 |
|---|---|---|---|
| D1 | 「메모에게 묻기…」 창·메뉴 항목을 없애고 빠른 입력 하나로 | Searching "Aim to make your app's content searchable through a single location." · Popovers "Show one popover at a time." · WWDC25 359 "tabs are for navigation, not for taking action" | §8 「한 상자가 입력과 검색을 겸한다. 모드 전환이 없어야 조작 수가 준다」 |
| D2 | 묻기/시키기/적기/찾기는 앱이 가른다. 물음말(뭐·언제·어디·?)이면 답, 동사(알려줘·미뤄·폴더로·지워)나 「…8시로」면 시키기, 날짜·장소가 든 서술이면 새 메모, 나머지는 적기. 화면에는 모드 조작이 없다 | Entering data "Get information from the system whenever possible." · Designing for iOS "limiting the number of onscreen controls" | §14.1 「완성을 요구하지 않는다」 |
| D3 | 안내 문구·힌트 줄에 「물으면 답」을 더한다. 빈 상자 힌트: 「적으면 메모, 찾으면 검색, 물으면 답」. 열 때마다 바뀌는 안내 문구(`CapturePrompt`)에 질문 예 하나(「치과 언제였지?」)를 섞는다 | Search fields "Use placeholder text to help people know what they can search for." · Text fields "Show a hint in a text field to help communicate its purpose." | §8 안내 문구는 첫 글자에 사라진다 |
| D4 | 자리 칩. 날짜 칩(호박색 「9월 30일 (수) · 달력으로」) 옆에 **자리 칩**(세이지 잉크 「자리 · 홍대입구」). 지도 링크는 본문에 그대로 두고 칩만 선다. 칩은 «앱이 읽은 결과» 이지 원문이 아니다 | Entering data "Dynamically validate field values… provide feedback as soon as you detect a problem" | §8 「칩에 보여줄 글은 해석한 결과」 · `NoteReader` 한 규칙 |
| D5 | ⌘↵ 라벨이 곧 동사다: 「메모 남기기」「달력에 남기기」「메모에게 묻기」「「치과 예약」에 적용」「답하기」. 프로미넌트 단추는 늘 하나 | Buttons "use a button that has a prominent visual style for the most likely action" · "Keep the number of prominent buttons to one or two per view." · "consider starting the label with a verb" | §8 「힌트 줄이 지금 ⌘↵ 가 할 일을 말한다」 |
| D6 | **되묻기는 상자를 닫지 않는다.** 약속인데 시각이 없으면 ⌘↵ 뒤 상자가 남아 위에 초안 요약 줄(「친구랑 밥 먹기로 했어 · 9월 30일 (수) · 자리 홍대입구」), 아래에 질문 줄 「약속 시간이 언제인가요?」, 그 아래 **고를 수 있는 칩**(「12시」「점심」「저녁 7시」「시각 없이」), 입력 칸은 비워지고 자리표 「12시야」. 목록·찾기 단축은 물러난다(질문 하나만 남는다) | Entering data "When possible, offer choices instead of requiring text entry." · "make sure people understand that they must provide the required data before they can proceed" · Text fields "include a separate label describing the field to remind people of its purpose" · Popovers "limit the amount of functionality in the popover to a few related tasks" | §8 지운 뒤 상자를 닫지 않는 것과 같은 이유 — 닫히면 단축키를 다시 눌러야 한다 |
| D7 | 답이 오면 **새 메모는 기존 길로 끝난다** — 상자가 닫히고 달력이 잠깐 나온다(§7.2). 상자 안에 「적혔다」 줄을 세우지 않는다: 나온 물건이 곧 확인이다 | Feedback "When it makes sense, confirm that a significant action or task has completed" · Undo "Show the results of an undo or redo… highlight the result" | §8 「확정한 메모는 포커스를 뺏지 않는다 — 날짜를 적었으면 나오는 것이 달력이다」 |
| D8 | **기존 메모를 바꾸는 시키기**(다시 보기·일정·폴더)는 상자가 남고 목록 아래에 결과 줄 「「치과 예약」 9월 18일 (금) 10:00 에 다시 보여 줍니다 · 되돌리기」. D6 의 「지웠습니다 · 되돌리기」와 같은 자리·같은 낱말. 확인 대신 되돌리기; 휴지통만 되묻는다 | Undo "Help people predict the results of undo… modify the menu item labels to identify the result" · Feedback "Consider integrating status feedback into your interface" | D6 · JARVIS §5 「저장 결과+되돌리기」 |
| D9 | 묻기: 치는 동안 목록은 **낱말 랭킹**(`MemoRanker`) 결과 — 이것이 곧 근거 후보다. ⌘↵ 「메모에게 묻기」→ 힌트 줄이 「메모를 읽는 중 · esc 그만」 → 답 한 문장(본문 크기) + 원문 인용 줄(2pt 세로 막대) + 목록이 **근거 메모만**으로 줄고 머리글 「근거 2장」. ↓·⌘↵ 로 연다(기존 손짓). 못 찾으면 「메모에서 찾지 못했습니다」+ 머리글 「관련 메모」. 답이 선 뒤 글을 고치면 답은 물러나고 검색으로 돌아간다 | Search fields "If possible, start search immediately when a person types." · "Provide the most relevant search results first" · WWDC17 802 Consistency "representing similar design features in similar ways" · Feedback "Show people when a command can't be carried out and help them understand why." | §8 「낱말이 바뀌면 목록은 다른 물건」 · §9.4 기다리는 상태 규칙(상한·글이 바뀌면 답을 버림) |
| D10 | 대상: ↓ 로 고른 줄이 있고 글이 **시키는 말**이면 그 줄이 대상 — 라벨 「「치과 예약」에 적용」. 글이 시키는 말이 아니면 고른 줄 ⌘↵ 는 전처럼 「메모 열기」. 고른 줄 없이 대상이 필요하면 상자에 「어느 메모를 말하는지 골라 주세요」 줄 + 목록 머리글 「어느 메모? ↓ 로 고르고 ⌘↵」(목록이 곧 후보). 종이 우클릭 「이 메모에게 시키기…」는 이 상자를 열고 「열린 메모 · 치과 예약 ×」 칩을 세운다 — × 로 놓는다 | Entering data "offer choices instead of requiring text entry" · WWDC17 802 Proximity "the distance between a control and the object that it affects" | §8 「자리가 아니라 그 메모 자체를 들고 있는다」 · JARVIS §5 「실행할 대상을 모델이 임의로 고르지 않는다」 |
| D11 | 모델이 없을 때: 시키기·적기·찾기는 그대로 되고(앱이 읽는다), 묻기 ⌘↵ 만 「모델을 받으면 답합니다 · 받기 2.6GB」 한 줄. 받기를 누르면 그 줄이 진행 막대가 되고, 상자를 닫아도 계속 받으며 같은 줄이 메뉴 → 설정에도 선다. 받기 전에는 아무 곳에도 「AI」 라는 말이 서지 않는다 | Feedback "Show people when a command can't be carried out and help them understand why." · Privacy "wait to request permission until people actually use an app feature that requires access." | §9.4 「있으면 켜지고 없으면 조용히 없다」 |
| D12 | esc: 되묻기 중 esc 는 **「시각 없이」와 같다** — 초안을 날짜만으로 적고 닫는다. 사용자는 이미 ⌘↵ 로 «적어라» 했으므로 초안은 검색어가 아니라 메모다 | Popovers "Always save work when automatically closing a nonmodal popover." | §14.1 완성을 요구하지 않는다 · §8 「닫을 때 저장하면 검색어가 메모가 된다」는 ⌘↵ 전의 글에만 해당 |
| D13 | 150ms: 모델은 ⌘↵ 로 묻거나 낯선 시키기일 때만 올린다. 치는 동안은 파서·랭커뿐 | WWDC18 803 "If you introduce any amount of lag, things all of a sudden just kind of fall off a cliff" | §8·§11 표시 예산 |
| D14 | 상자 폭 440 고정, 높이만 자란다. 되묻기·답이 서도 폭은 안 변한다 | Popovers "Make a popover only big enough to display its contents" · "Provide a smooth transition when changing the size of a popover." | `CaptureHostingView` 가 잰 높이로 창을 맞춘다 |

## 2. 장면별 — 캔버스 아트보드와 같은 차례

- **A 빈 상자** — 지금 그대로. 힌트 줄만 「적으면 메모, 찾으면 검색, 물으면 답」.
- **B 서술** 「9월 30일에 https://naver.me/… 여기서 친구랑 밥 먹기로 했어」 — 날짜 칩 + 자리 칩(링크에서 읽은 이름; 못 읽으면 칩 없이 링크만 남는다), 목록은 찾은 것, 라벨 「달력에 남기기」.
- **C 되묻기** — 초안 요약 줄 · 질문 줄 · 선택 칩 넷 · 빈 입력(자리표 「12시야」) · 힌트 「↵ 줄바꿈 · esc 시각 없이 남기기」 · 라벨 「답하기」.
- **D 시키기 결과** — 「치과 예약」에 다시 보기를 건 뒤: 목록은 그대로, 아래 결과 줄 + 되돌리기, 입력은 비워진다. (새 메모는 여기 오지 않는다 — 닫히고 달력이 나온다.)
- **E-1 읽는 중** — 질문 그대로, 목록 그대로, 힌트 줄 「메모를 읽는 중 · esc 그만」, 라벨 없음.
- **E-2 답** — 답 한 문장 · 인용 줄 · 머리글 「근거 2장」 · 근거 줄 둘 · 힌트 「↑↓ 선택 · ⌘↵ 열기」.
- **E-3 못 찾음** — 「메모에서 찾지 못했습니다」 · 머리글 「관련 메모」 · 줄 셋.
- **F-1 대상 있음** — 고른 줄 + 글 「금요일 10시에 다시 알려줘」 → 라벨 「「치과 예약」에 적용」.
- **F-2 어느 메모?** — 질문 줄 + 머리글 「어느 메모? ↓ 로 고르고 ⌘↵」.
- **G 모델 없음** — 질문 ⌘↵ 뒤 「모델을 받으면 답합니다 · 받기 2.6GB」 한 줄.
- **H esc** — 아트보드 없음(D12).

## 3. 구현에 넘길 것 (코드는 이 문서 밖)

1. `QuickCaptureModel` 에 비서 상태 하나: `assistant: .idle | .asking(draft, question, choices) | .thinking | .answered(AssistantAnswer) | .applied(ProposedAction, receipt) | .needsModel | .whichMemo(question)`. 낱말 랭킹은 `search(_:)` 가 `MemoRanker` 를 쓰도록 — 상자·서랍·비서가 같은 차례를 낸다.
2. `commit()` 의 갈래: 고른 줄 + 시키는 말 → 그 줄에 `AssistantModel.command(text, selected:)`; 물음 → `ask`; 서술·적기 → 기존 `create`(단 `NoteReader` 로 장소까지). 되묻기 답은 `AssistantIntent.complete`.
3. `AssistantWindow`·메뉴 「메모에게 묻기…」·`AssistantView`(맥) 삭제. 폰은 별도 — 펜에 같은 규칙을 얹는 것은 후속.
4. 결과 줄·질문 줄·인용 줄은 `undoLine` 과 같은 부품(10pt micro·secondary·되돌리기 accentInk).

## 4. 부딪힌 자리와 판정

| 자리 | 애플 | lazymemo | 판정 |
|---|---|---|---|
| 되묻기 중 상자가 남는다 | Popovers "a popover disappears after people interact with it" | §8 지운 뒤 닫지 않음 | **lazymemo** — 이 popover 는 이미 「지우고 또 지우는」 비모달 도구다. 남되 질문 하나만 남긴다 |
| 되돌리기 줄 | Undo "Provide undo and redo buttons only when necessary… Edit menu, ⌘Z" | D6 8초·상자 안 되돌리기 줄 | **lazymemo** — 상자에는 Edit 메뉴가 없고(키 윈도가 아닐 수 있다) 이미 지우기가 이 줄을 쓴다. 다만 ⌘Z 도 같은 되돌리기를 부르게 한다(구현 메모) |
| 새 메모 확인 | Feedback "confirm that a significant action… has completed" | §8 종이/달력이 잠깐 나온다 | 충돌 없음 — 나온 물건이 확인이다 |
| 모드 없음 | Search fields scope bar "Use a scope bar to filter among clearly defined search categories." | §8 모드 전환 없음 | **lazymemo** — 범주가 넷(적기·찾기·묻기·시키기)이지만 사람이 고르면 「Do 칸에 질문」 같은 실패가 난다(오늘 화면). 앱이 가른다 |

## 5. 못 찾은 것

- HIG 에 「popover 안에서 한 가지를 되묻는」 패턴의 원문은 없다. Entering data 의 «필요한 데이터를 알려라·선택지를 주어라» 로 잇는다.
- macOS Search fields 페이지에 맥 고유 문장은 없다(플랫폼 절이 비어 있다).
