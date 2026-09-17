# lazymemo 폰 — 펜 하나, 목록 하나, 달력 하나

> 상태: 설계 **2판** · 2026-09-13 · 캔버스: [2판](https://claude.ai/code/artifact/ee32f4e3-300a-4c76-b832-147a6c4646ea) · 근거: [애플 디자인 원칙 노트](research/apple-design-principles.md) · [설계문서 §14](DESIGN.md) · [시각 규칙](VISUAL_DESIGN.md) · 실행 계획: `.oculpm/planner/lazymemo-ios-icloud.md` 4단계
>
> 1판(2026-09-13 오전, [캔버스](https://claude.ai/code/artifact/3212a2d1-de8a-4c23-9717-8b86a4cd8988), 커밋 `455d237`·구현 `fb1da17`)을 애플의 원칙에 하나씩 비추어 다시 썼다. **바뀐 것과 그 근거는 §14 의 표에 모아 두었다.** 아래 「→ 노트 §n」은 근거 노트의 절이다.

## 0. 한 문장

**폰은 켜면 펜이다.** 앱을 열면 유리 위의 펜이 엄지 밑에 있고, 키보드가 올라와 있다. 적은 것은 목록 **맨 위**에 나타나고 화면이 그리로 간다. 날짜가 읽힌 것은 달력이 맡는다. 그 밖의 것은 없다.

## 1. 은유 — 폰에는 종이도 서랍도 없다 (1판 그대로)

맥의 종이는 **바탕화면이라는 면**이 있어서 성립한다. 종이와 서랍의 구분은 메모의 성질이 아니라 화면 자리의 구분이고, 그래서 `layout.json`(창 위치·`hidden`)은 정본이 아니며 동기화되지 않는다. 폰에는 그 면이 없다. 종이/서랍을 흉내 내면 목록이 둘이 되고 사용자는 어느 쪽에 있는지 외워야 한다. **버린다.**

남는 것은 파일에 적혀 동기화되는 것뿐이다.

| 파일의 것 | 폰에서 | 맥에서 |
|---|---|---|
| `due`·`at` | 목록에 시각 한 조각, 달력의 그 날 | 달력이 맡는다 (§7.2) |
| `folder:` | 목록 머리의 칩 — 거른다 | 서랍의 칸 |
| `tidied:` | 목록에서 빠진다. 「치워 둔 N장」으로만 남는다 | 같다 |
| `deleted:` | 휴지통 | 같다 |
| `pinned` | 목록 맨 위 구역, 바래지 않는다 | 앞에 둔다, 바래지 않는다 |

**폰에서 적은 메모는 맥 바탕화면에 새 종이로 선다.** 폰은 종이를 낼지 말지 정하지 않는다 — 맥의 `staysOnDesktop` 이 정한다.

그래서 폰의 구조는 셋이다 — **펜**(바닥, 유리 위, 적기와 찾기), **목록**(위에서 아래로, 고정 → 최근순), **달력**.

### 1.1 애플의 층과 우리의 재질

애플은 화면을 두 층으로 본다 — 조작·내비게이션의 **유리 층**과 그 아래 **콘텐츠 층**. "Don't use Liquid Glass in the content layer." 반대도 참이다: 조작을 콘텐츠처럼 칠하면 층이 무너진다 (→ 노트 §3).

우리 다섯 문장의 「재질은 종이 하나」는 **콘텐츠 층의 재질**이다. 메모 본문·목록·달력의 바탕은 종이다. 펜·탭바·툴바·시트는 조작이고, 조작은 유리다. 1판은 「적는 면은 종이여야 한다」며 펜을 종이로 칠했다 — 그것이 층을 무너뜨렸고, 그 위에 뒤집힌 목록까지 얹어 유리의 가독성 장치(scroll edge effect)를 꺼야만 화면이 보였다. 2판은 층을 돌려놓는다.

## 2. 정보 구조

```
TabView                             (tabBarMinimizeBehavior: .onScrollDown)
 ├─ 메모   NavigationStack
 │          큰 제목 「메모」 · 부제 = 저장 자리     ⋯ 툴바: 휴지통 · More
 │          [폴더 칩 띠]                              (있을 때만)
 │          목록 ─────────────────────▶ 편집 (push · 탭바·펜 숨김)
 └─ 달력   NavigationStack
            달 격자 + 그 날 ────────────▶ 편집
 tabViewBottomAccessory: 펜  (유리 · 두 탭에 걸쳐 남는다 · 탭바가 접히면 한 줄)
```

- **탭은 둘.** "each extra tab means one more decision" (→ 노트 §2, 359). 검색 탭은 두지 않는다 — 펜이 찾기를 겸하고, 검색 탭은 「찾기」만 하는 자리라 적기를 겸할 수 없다 ("tabs are for navigation, not for taking action").
- **펜은 탭바 액세서리다.** "Tab bars can also support persistent features using accessory views… that stay visible across your app" (→ 노트 §3, 356). 펜은 두 탭에 걸쳐 같은 것이고 화면 고유 동작이 아니다. 탭바가 접히면(`.inline`) 펜은 한 줄의 「적기…」 알약이 되고, 누르면 펼쳐지며 포커스를 받는다.
  - **확인 기준.** 액세서리 안의 글 칸에 포커스가 갔을 때 액세서리가 키보드 위로 올라야 한다. 애플 문서에서 이것을 확인하지 못했다 (→ 노트 §9). 실기기에서 안 오르면 `safeAreaInset(edge: .bottom)` 에 **같은 유리 펜**을 앉히는 것으로 물러난다 — 생김새·동작은 같고 접힘만 없다.
- **큰 제목 + 부제.** "Use a large title to help people stay oriented" (→ 노트 §5). 부제는 저장 자리 — Mail 의 「Updated Just Now」 자리다 (→ 노트 §4 Feedback).
- **편집은 push.** 시트로 띄우면 뒤로 가는 손짓이 둘이 된다. 편집에서는 **탭바와 펜이 숨는다** — 종이 아래 또 하나의 글 칸(펜)이 보이면 「어디에 적는 건가」가 흐려진다("Be clear about the data you need"). 애플도 사진을 열면 탭바를 감춘다(Photos). HIG 는 "Make sure the tab bar is visible when people navigate to different sections" 라 하지만 편집은 구역이 아니라 한 장의 내용이다 — 긴장은 §14 에 적었다.
- **시트는 둘뿐.** 날짜(달 격자)와 폴더. 둘 다 iOS 26 유리 시트 그대로 — `presentationBackground` 를 쓰지 않는다 (→ 노트 §3, 323).
- **설정 화면은 없다.** 1판과 같다.

## 3. 펜

### 엄지 동선

켠다 → 키보드가 올라와 있다 → 친다 → 엄지 밑의 「남기기」. 넷이고, 손이 위로 가지 않는다 ("easier and more comfortable to reach a control when it's located in the middle or bottom area" → 노트 §4).

### 생김새 — 유리 위의 글 칸

```
 ┌───────────────────────────────────────────────┐
 │ [ 9월 14일 (일) 15:00 · 달력으로 ] [ @강남역 ]   │  ← 칩 줄 (읽은 것이 있을 때만)
 │ ◎  ( 내일 3시 치과                    ⊗ )  [ 남기기 ] │  ← 펜 줄
 └───────────────────────────────────────────────┘
   ──────────── 탭바 (유리) ────────────
```

| 자리 | 무엇 | 규칙 |
|---|---|---|
| 왼쪽 끝 | **시스템 위치 단추** (`LocationButton`, 아이콘만) | 「지금 여기」. 시스템 생김새를 바꾸지 않는다 — "You cannot customize other visual attributes to help people recognize and trust location buttons" (→ 노트 §4 Privacy). 한 번 허용(Allow Once)과 같다 |
| 가운데 | 글 칸 — 유리 캡슐 (`glassEffect`, 표준 텍스트 필드) | 한 줄에서 다섯 줄까지. 안내 문구 `CapturePrompt`. 글이 있으면 오른쪽 끝에 **지우기(⊗)** — "Display a Clear button in the trailing end of a text field" (→ 노트 §5). ⏎ 는 다음 줄 |
| 오른쪽 끝 | 「남기기」 — **프로미넌트 단추** (유리에 accent 틴트, 글자 `Theme.onAccent`) | 이 화면의 유일한 틴트. "use a button that has a prominent visual style for the most likely action… one or two per view" / "To emphasize primary actions, apply color to the background rather than to symbols or text" (→ 노트 §5·§6). 날짜가 읽히면 「달력에 남기기」. 글자 단추인 이유: "Consider using text when a short label communicates more clearly than an icon" — 이름이 바뀌는 것이 뜻을 나른다 |
| 위 | 칩 줄 | 아래 |

글 칸은 `.title2` light 가 아니라 **`.body`** 다 — 액세서리 높이가 제한되고, 큰 글자는 Dynamic Type 이 정한다 (→ 노트 §6). 종이색 바탕·윗변 선은 없다 — 유리와 scroll edge effect 가 경계를 만든다 ("Instead of applying solid or semi-opaque backgrounds, use a scroll edge effect" → 노트 §4 Layout).

### 칩 — 읽은 것을 누르기 전에 보인다

`NoteReader.read` 가 돌려준 것을 그대로 적는다. **"Dynamically validate field values… provide feedback as soon as you detect a problem — you give them the opportunity to correct errors right away"** (→ 노트 §4 Entering data)가 칩의 근거이고, **누르면 끄는 것**이 「그 자리에서 고치는 길」이다. 폰에서 글자 하나를 골라 지우는 것은 조준이 필요하다.

| 읽은 것 | 칩 | 누르면 |
|---|---|---|
| 날짜·시각 | 「9월 14일 (일) 15:00 · 달력으로」 | 읽지 않는다 — 칩이 빈 테두리로, 단추가 「남기기」로. 글은 그대로 |
| 되풀이 | 「매주」 | 같다 (날짜와 함께 꺼진다) |
| 장소 | 「@강남역」 | 같다 |

칩은 **눌리게 생겨야 한다** ("Affordances" → 노트 §2): 켜진 칩은 `highlightWash` 바탕 + `highlightInk` 글, 꺼진 칩은 테두리만. 높이 32, 과녁 44. VoiceOver: 「9월 14일 일요일 15시, 달력으로 갑니다. 누르면 날짜로 읽지 않습니다」.

### 펜이 비서를 겸한다 (2026-09-15)

맥의 빠른 입력과 같은 규칙(`docs/research/quick-capture-assistant-2026-09-15.md` D1–D14)을 펜에 그대로 얹었다. 「메모에게 묻기」 시트와 툴바 ✦ 는 없앴다 — 같은 일을 하는 자리가 둘이면 한쪽에서만 되는 것이 생긴다. 사람은 모드를 고르지 않는다: 물음말(뭐·언제·어디·?)이면 「메모에게 묻기」, 동사(알려줘·미뤄·폴더로·지워)면 「시키기」, 날짜·자리가 든 서술이면 「달력에 남기기」, 나머지는 「메모 남기기」 — **단추의 라벨이 곧 동사다**. 약속인데 시각이 없으면 펜이 닫히지 않고 칩 줄 자리에 초안 요약·「약속 시간이 언제인가요?」·선택 칩(12시·점심·저녁 7시·시각 없이)이 서고 자리표는 「12시야」; 답이 오면 기존 길로 남긴다. ⊗ 는 「시각 없이」다. 답은 목록 위에 한 장(문장 + 원문 인용)으로 서고 목록은 「근거 N장」으로 줄어든다; 못 찾으면 「관련 메모」. 시키기 결과는 목록 위 한 줄 + 되돌리기(휴지통만 되묻는다). 대상이 흐리면 목록이 「어느 메모? 누르면 그 메모에게 합니다」 후보가 되고, 줄을 누르면 여는 대신 그 메모에게 같은 말을 한다. 열린 메모에게 시키는 길은 편집 화면의 ✦ 시트가 그대로 맡는다. 모델이 없으면 묻기만 「모델을 받으면 답합니다 · 받기」 한 줄이고 나머지는 모델 없이 된다. 글을 고치면 답은 물러나고 검색으로 돌아간다.

**2026-09-16 — 자리를 하나로.** 편집 화면의 ✦ 시트(옛 `AssistantView`)를 없앴다. ✦ 는 이제 화면을 물리고 펜에 그 메모를 넘긴다 — 펜 위에 「열린 메모 · 치과 예약 ×」 칩이 서고(맥의 D10 칩과 같다), 자리표는 「내일로 미뤄줘」, 묻는 말이 아닌 것은 동사가 없어도 전부 그 메모에게 시키는 말이다(단추 「시키기」 — 맥의 「「치과 예약」에 적용」은 폰의 좁은 단추에서 두 줄로 꺾여, 누구에게인지는 바로 위의 칩이 말한다). 답이나 결과가 오면 칩은 내려간다; × 로도 놓는다. 달력 탭에서 왔어도 메모 탭으로 온다 — 결과 줄이 서는 목록이 거기 있다. 편집 화면이 다 물러난 뒤(`onDisappear`)에 넘긴다 — 물러나는 중에는 펜이 포커스를 받지 못한다.

치는 동안의 목록도 맥과 같다: 묻는 말·시키는 말은 구(phrase)가 아니라 **낱말 랭킹**(`MemoRanker`)으로 줄 세운다 — 「치과 언제였지?」는 어느 메모의 문장도 아니다. 이 목록이 곧 근거·대상 후보다. 시키는 말에 걸리는 낱말이 없으면 목록을 비우지 않는다. 묻거나 시키는 말에는 날짜·자리 칩을 세우지 않는다 — 「금요일 10시에 다시 알려줘」의 날짜는 달력으로 가지 않는다. 빈 목록의 한 줄도 갈린다: 적는 말이면 「남기면 새 메모예요」, 묻는 말이면 「물으면 메모를 읽고 답합니다」, 시키는 말이면 「시키면 어느 메모인지 묻습니다」.

단추를 누르면 펜은 비지만 목록은 **읽는 동안 그대로** 선다 — 머리글 「「치과 언제였지?」 · 이 중에서 읽는 중」(맥 E-1 「목록 그대로」). 비었다가 근거로 줄어드는 두 번의 뜀이 기다리는 사람을 흔들기 때문이다. 답 카드는 무엇을 물었는지를 첫 줄에 든다 — 맥은 상자 안에 답이 서지만 폰의 답은 목록 위에 혼자 선다. 비서가 「어느 메모?」에 후보를 못 붙였으면(「금요일 10시에 다시 알려줘」는 어느 메모의 낱말도 아니다) 지금 목록이 곧 후보다. 답·결과·되물음은 「지금」 띠보다 위에 선다.

첫 실행 안내의 첫 장에 한 줄을 더했다: 「물으면 메모가 답하고, 시키면 합니다 — 전부 이 폰 안에서요」. 맥의 빈 상자 힌트 「적으면 메모, 찾으면 검색, 물으면 답」(D3)의 자리다 — 폰의 펜에는 힌트 줄이 없다.

시뮬레이터에서 본 것 둘: ① `HomeView.init` 에서 `pen.assistant` 를 잇던 것을 `onAppear` 로 옮겼다 — SwiftUI 가 뷰를 다시 만들면 그때의 펜은 화면이 쥔 펜이 아니라, 비서의 「끝났다」 신호가 버려진 펜으로 가서 답이 목록에 서지 않았다. ② 편집 화면에 다녀오면 `@FocusState` 는 켜진 채인데 키보드는 내려가 있어, 같은 값을 다시 넣어서는 안 올라온다 — 껐다가 다음 턴에 켠다.

### 치면 걸러진다

한 글자부터 목록이 **찾은 것**으로 바뀐다 (`MemoFilter.read` → 첫소리면 메모리, 아니면 인덱스 — `QuickCaptureModel.find` 와 같은 두 걸음). "Aim to make your app's content searchable through a single location" (→ 노트 §4 Searching) — 그 한 곳이 펜이다.

- **범위를 적는다.** "Clearly display the current scope of a search": 목록 머리에 「41장 중 3장」 한 줄. 못 찾으면 「41장 중 없다」 — 그래도 「남기기」는 산다. 찾으려고 친 낱말이 곧 새 메모의 첫 줄이다.
- 찾은 것은 위에서 아래로 **가장 맞는 것부터**. 「… 외 N장 더」 같은 상한은 없다 — 스크롤한다 (맥 팝오버의 제약이었지 원칙이 아니다).
- 찾은 줄을 누르면 연다. 치워 둔 것이었으면 여는 순간 도로 나온다 (`untidy`).

### 상태

| | 목록 | 펜 |
|---|---|---|
| 처음, 한 장도 없음 | 「적은 것이 여기 쌓입니다」 한 줄 | 안내 문구 |
| 빈 펜 | 고정 → 최근순 | 안내 문구 |
| 치는 중 | 걸러진 것 + 「N장 중 M장」 | 글 + 칩 + ⊗ |
| 탭바 접힘 (스크롤 중) | — | 「적기…」 한 줄 알약 (`.inline`) |
| 로컬뿐 | 부제 「이 기기에만 · iCloud 꺼짐」 (§4) | 그대로 |

### 손짓

| 손짓 | 결과 |
|---|---|
| 「남기기」 | `store.create` → 새 줄이 **목록 맨 위**에 나타나고 목록이 그리로 스크롤되며 줄이 잠깐 밝아진다(시스템 선택색으로 한 번). "Show the results… you might scroll the document to show the restored paragraph" (→ 노트 §4 Undo)의 논리를 남기기에도 쓴다. 글 칸은 비고 키보드는 남는다 |
| 「달력에 남기기」 | 같다. 줄에 시각 조각이 달린다. 탭 배지는 찍지 않는다 — "Reserve badges for critical information" (→ 노트 §5) |
| ⏎ | 다음 줄 |
| ⊗ | 글 칸을 비운다 (칩도 사라진다) |
| 글 칸 밖·목록 스크롤 | 키보드가 내려간다. **적던 글은 남는다** (`CaptureDraftStore`) |
| 위치 단추 | 시스템 위치 단추가 한 번 허용을 받는다. 재고 끊는다. 「@주소」 칩이 물리고 `geo` 가 붙는다. 못 재면 칩 자리에 「위치를 못 잡았습니다」 한 번 |

## 4. 목록

### 왜 위에서 아래인가 — 1판을 뒤집은 결정

1판은 「펜 위로 쌓기」였다. 엄지가 안 움직이고 새 줄이 펜 옆에 앉는다는 값이 있었다. 애플 원칙은 세 방향에서 반대한다.

1. **"Order content by relative importance. Place the most important items near the top and leading side."** (→ 노트 §4 Layout) 고정·최근이 가장 중요하고, 그것은 위에 있어야 한다.
2. **Consistency · Mental model.** 사람의 「메모 목록」 모델은 Notes 다 — 위가 새것, 아래가 옛것. 애플의 목록 앱은 하나도 목록을 뒤집지 않는다. 뒤집는 것은 대화(Messages)뿐이고, 대화는 「가장 새것 = 지금」이며 말풍선에 손을 대지 않는다. 메모는 고치고 옮기고 지우는 것이다 (→ 노트 §7).
3. **구현이 원칙 위반을 증언했다.** 뒤집힌 목록은 유리 바의 scroll edge effect 를 **꺼야만** 보였다 (`scrollEdgeEffectHidden`). "Scroll edge effects work in concert with Liquid Glass to maintain that crucial separation between the UI and content layers and ensure legibility" (→ 노트 §3, 219). 층의 가독성 장치를 끄는 화면은 애플의 화면이 아니다.

「엄지가 안 움직인다」의 값은 다른 길로 지킨다 — 조작(펜·남기기·밀기)은 전부 바닥과 줄 안에 있고, 내용만 위에서 아래다. 새 줄이 멀리 생기는 문제는 **화면이 그리로 가는 것**으로 답한다(§3 손짓).

### 차례

**고정한 것** 구역이 먼저, 그 아래 **최근순**. 「시간이 유일한 구조」(§14.2) — 옛것은 아래로 가라앉는다. 구역 제목은 붙이지 않는다 — 고정 줄은 핀 그림이 말한다.

### 「지금」 — 목록 위의 최대 세 장

폴더 띠 아래, 목록 위에 최대 세 장 (`Recall.nowCards`, `NowBand`) — 오늘 다시 볼 것·오늘 일정·고정 중에서 **다가오는 시각이 먼저**, 그다음 방금 지난 것, 그다음 시각이 없는 것(날짜만 있는 오늘 일정 → 고정). 이유별로 줄을 세우면 아침에 지나간 셋이 오후에 곧 올 하나를 밀어낸다 — 그건 「지금」이 아니라 「오늘 아침」이다. 카드마다 **이유와 시각**이 먼저다 — 「다시 보기 · 15:00」·「오늘 일정 · 15:00 지남」·「오늘 일정」·「고정」 — 이유가 보이지 않는 카드는 앱이 골라 준 것이고, 보이는 카드는 내가 정해 둔 것이다. **띠에 오른 것은 아래 목록에서 빠지고** 아래는 「나머지 N장」이라는 머리를 단다 — 같은 줄이 두 번 서면 화면이 무겁다. 대신 카드도 줄이 하는 일(고정·지우기 쓸어 넘기기, 길게 눌러 메뉴)을 전부 한다. 카드의 **「봤어요」**가 카드를 내려놓는다 — 지난 시각의 카드는 놓친 사람을 위해 남지만 본 사람에게는 치울 거리라서. 내려놓은 것은 이 기기만 기억하고(`NowSeen`, 파일에 적지 않는다 — 폰에서 봤다고 맥의 종이가 물러날 이유는 없다), 그 등장의 이름표(`Card.stamp` — 시각, 없으면 오늘)가 같은 동안만 빠진다: 시각을 미루거나 날이 바뀌면 다시 오른다. **찾는 중이거나 폴더를 골랐으면 없다** — 범위가 좁혀진 화면 위에 범위 밖의 카드가 서면 그 화면이 무엇인지 흐려진다 ("Clearly display the current scope"). 분이 바뀌면 다시 재고 자정을 넘기면 「오늘」이 바뀐다. 카드는 종이(`Paper.card`)에 포레스트 테두리, 이유는 `accentInk`, 큰 글자에서는 제목이 세 줄까지, VoiceOver 는 「고정, 읽을 것: 설계 문서」로 읽는다.

그 아래에 **조용히 지나가면 안 되는 실패** 한 줄(`NoticeRow`) — 저장소의 `trouble` 과 알림의 `trouble`. 맥은 메뉴 첫머리가 읽고 폰은 목록의 머리가 읽는다. 저장 버튼이 없는 앱에서 저장 실패가 안 보이면 사용자는 영영 모른다.

### 줄

맥 메뉴 목록과 **같은 낱말**이다 (§14.10): 점 · 제목 · 시각 한 조각.

```
● 장보기                                내일 15:00
  우유, 계란, 두부
```

| 조각 | 규칙 | 글·색 |
|---|---|---|
| 점 | 종이 색. 8pt. 치워 둔 것(찾았을 때만)은 빈 점 | `MemoColor.ink` |
| 제목 | `Memo.title` 한 줄, 큰 글자에서 두 줄 | `.body` semibold, `Paper.ink` |
| 둘째 줄 | 제목 다음의 **글** 한 줄 (`Memo.previewLine`). 사진 참조는 글이 아니라 건너뛴다. 없으면 없다 | `.subheadline`, **`.secondary`** |
| 시각 | `MemoTimeLabel.text` | `.caption` monospacedDigit. 날짜 있는 것 `Theme.highlightInk`, 없는 것 `.secondary` |
| 고정 | 제목 앞 작은 핀 | `Theme.accentInk` |
| 장소 | 시각 아래 「@강남역」 | `.caption2`, `.secondary` |
| 사진 | 붙인 사진은 경로가 아니라 「사진 1장」 (`Memo.photoCount`). 사진만 붙인 메모는 제목도 「사진 1장」 | `.caption`, `.secondary`, `photo` |

줄 높이 56 이상, 좌우 여백 20, 구분선 없음, › 없음(Notes 와 같다 — 열면 편집이지 계층이 아니다 → 노트 §5 Lists). **큰 글자(accessibility 크기)에서는 시각 조각이 제목 아래로 내려간다** — "consider using a stacked layout where text appears above secondary items" (→ 노트 §6).

**바램은 대비를 지키며.** 1판의 `Paper.fadedInk`(잉크 52%)는 미색 위에서 약 3.3:1 로 캡션에 못 쓴다 (→ 노트 §6, 4.5:1). 그래서:
- 둘째 줄·시각·장소는 시스템 `.secondary` (AA 를 맞춘 시맨틱 색).
- `MemoAge` 는 **제목의 색**으로 말한다 — fresh·recent 는 `Paper.ink`, settled·faded 는 `.secondary`. 불투명도로 줄 전체를 바래게 하지 않는다.
- Increase Contrast 가 켜져 있으면 바래지 않는다 ("ensure it at least provides a higher contrast color scheme when… Increase Contrast is turned on").
- 고정한 것과 다가오는 일정은 바래지 않는다 (1판과 같다).

### 폴더 칩

큰 제목 밑, 가로로 스크롤되는 한 줄: 「전부 · 장보기 · 읽을 것 · 집 · ＋」. 콘텐츠 층이므로 유리가 아니라 **표준 `bordered` 캡슐 단추**(고른 것은 `borderedProminent`). `MemoFolders.names(listed:memos:)`.

- 칩을 고르면 목록이 좁혀지고, **그 상태에서 적은 메모는 그 폴더에 들어간다**.
- 「＋」는 이름 한 줄 alert. 칩을 길게 누르면 이름 바꾸기·폴더 지우기 (지워도 메모는 남는다). 같은 것이 More 메뉴에도 있다 — "Always make context menu items available in the main interface, too" (→ 노트 §5).
- 폴더가 하나도 없으면 띠 자체가 없다.

### 손짓

| 손짓 | 결과 |
|---|---|
| 누름 | 편집으로 push |
| 왼쪽으로 밂 | 「지우기」 (`destructive`). 끝까지 밀면 바로 |
| 오른쪽으로 밂 | 「고정」/「고정 해제」 (Notes 와 같은 방향 → 노트 §7) |
| 길게 누름 | 컨텍스트 메뉴 — 고정 · 폴더에 넣기 ▸ · 달력에 놓기 · **지우기(맨 끝, destructive)**. 미리보기는 종이 |
| 「달력에 놓기」 | 날짜 시트(§5)가 뜬다 — 달력 탭으로 넘어가 모드에 들어가지 않는다. 시트가 곧 「달력 위에서 가리키기」다 |

밀기 동작은 전부 VoiceOver 「동작」에도 있다 — "Give people more than one way to interact" (→ 노트 §5 Gestures).

### 되돌리기 — 시스템이 한다

1판의 「펜 위 8초 띠」를 **뺀다.** "Provide undo and redo buttons only when necessary. People generally expect to initiate undo and redo in system-supported ways, such as… shaking their iPhone" (→ 노트 §4 Undo). 애플의 메모·사진·파일 어디에도 토스트는 없다 — 흔들기·세 손가락 쓸기와 **Recently Deleted** 가 되돌리는 길이다. 우리에게는 휴지통(30일, D6)이 있다.

- 지우기·옮기기·날짜 떼기는 **`UndoManager` 에 이름을 달아** 등록한다: 「지우기」·「9월 16일로 옮기기」·「날짜 떼기」. 흔들면 시스템 알림이 「지우기 실행 취소」라고 묻는다 ("Briefly and precisely describe the operation to be undone").
- **되돌린 결과를 보인다** — 돌아온 줄로 스크롤하고 한 번 밝힌다 ("Show the results of an undo or redo").
- 휴지통은 **툴바 단추**로 한 번에 닿는다 (§4 툴바). 되돌리기가 흔들기보다 덜 보이는 것은 사실이라 §15 에 적었다.

### 큰 제목과 부제

「메모」 큰 제목. 부제(`navigationSubtitle`)에 저장 자리:
- 잘 될 때 — 「iCloud · 41장」
- 로컬뿐 — 「이 기기에만 · iCloud 꺼짐」

"Consider integrating status feedback into your interface… making the information unobtrusive but easy for people to check" (→ 노트 §4 Feedback). 1판의 「펜 위에 계속 있는 띠」는 뺀다 — 불투명 띠는 층을 깨고, 상태는 제목 밑이 자리다. 로컬일 때 **왜인지와 어떻게 켜는지**는 More 메뉴의 「iCloud 설정 열기」가 답한다 ("Show people when a command can't be carried out and help them understand why").

### 툴바 (오른쪽 위)

"Try to include all actions in the toolbar if possible, and only add [More] if you really need it" (→ 노트 §5 Toolbars).

- **휴지통** 단추 (`trash` 심볼) — 자주는 아니어도 「어디 갔지」의 답이라 보여야 한다.
- **More** (`ellipsis.circle`) — 있을 때만 나오는 것들: 「치워 둔 N장 도로 꺼내기」, 「iCloud 설정 열기」(로컬일 때), 「새 폴더」. 그리고 늘 있는 **「알림」** — 「이 기기에서 알림 받기」 시트(`ReminderSettingsView`). 켜기 전에 잠금 화면에 제목이 보인다는 것과 기기별이라는 것을 읽고, 켜는 순간에만 시스템이 묻는다. 걸어 둔 수·한도 초과·걸지 못한 것과 「다시 시도」가 같은 시트에 있다. **켜고 나면 설명은 접힌다** — 켜짐과 걸어 둔 수만 남고, 잠금 화면·기기별·집중 모드 안내는 「기기별 알림 안내」를 펼쳐야 보인다. 이미 켠 사람에게 같은 문단이 매번 서 있으면 다시 보기 시트에서 시각을 고르는 손이 그것을 밀어내야 한다.

툴바 색은 모노크롬 — "Avoid applying a similar color to toolbar item labels and content layer backgrounds… prefer using the default monochromatic appearance" (→ 노트 §5).

## 5. 편집

### 엄지 동선

줄을 누르면 종이가 밀려 들어온다. **키보드는 올라오지 않는다** — Notes 도 기존 메모를 열 때 키보드를 올리지 않는다 (→ 노트 §7). 글 어디든 누르면 거기에 커서. 저장 버튼은 없다. 뒤로 가면 끝.

### 레이아웃

화면 전체가 종이 (`Paper.surface`, 콘텐츠 층). 큰 제목은 두지 않는다 — 첫 줄이 제목이다. 내비게이션 바는 유리, 뒤로 가기만. 탭바와 펜은 숨는다 (§2).

```
‹ 메모
┌──────────────────────────────────────┐
│ 장보기                                │ ← 본문. 좌우 20, 위 24
│ 우유, 계란, 두부                      │
│ - [ ] 세제                            │ ← 줄머리는 여백에 그린다 (§8.1)
│                                      │
├──────────────────────────────────────┤
│ ( 📅 내일 15:00 ) ( @강남역 ) ( 장보기 ) │ ( ● ) ( 📌 ) │ ( 🗑 ) │ ← 바닥 툴바 (유리)
└──────────────────────────────────────┘
```

### 꼬리 — 표준 툴바다

1판의 꼬리는 종이색 커스텀 줄이었다. 2판에서는 **표준 바닥 툴바**(`ToolbarItem(placement: .bottomBar)`)이고, 키보드가 오르면 시스템이 키보드 위로 옮긴다. "Custom Controls Above the Keyboard… Use standard toolbar — Automatically adopts Liquid Glass" (→ 노트 §5 Virtual keyboards). 항목은 `ToolbarSpacer(.fixed)` 로 세 묶음 — "Group bar items by function and frequency" (→ 노트 §3, 356):

| 묶음 | 조각 | 없을 때 | 있을 때 | 누르면 |
|---|---|---|---|---|
| 무엇 | 날짜 | 달력 심볼 | 「내일 15:00」 `highlightInk` | 날짜 시트 |
| | 장소 | (없음) | 「@강남역」 | 메뉴: 지도 열기 · 장소 떼기 |
| | 폴더 | 폴더 심볼 | 「장보기」 | 폴더 시트 |
| 생김새 | 색 | 점 하나 | 같다 | 메뉴: 여섯 색 (이름 + 점) |
| | 고정 | 핀 | 채운 핀 | 뒤집는다 |
| 끝 | 지우기 | 휴지통 | | 휴지통으로 → 뒤로 간다. `UndoManager` 에 「지우기」 |

색은 「그 자리에서 여섯 점이 펼쳐지는」 커스텀 대신 **메뉴**다 — "Prefer using standard components in a toolbar" (→ 노트 §5). 지우기는 맨 끝에 따로, destructive.

**다시 보기는 위 오른쪽의 종이다** (`recall-button`). 바닥 꼬리는 「무엇·생김새·끝」으로 이미 차 있고, 다시 보기는 메모의 속성이 아니라 「나에게 언제 돌아오나」라 위에 둔다. 정해 두었으면 종에 점이 붙고(`bell.badge.fill`) VoiceOver 가 시각까지 읽는다. 누르면 `RecallEditor` 시트 — 지금 정해 둔 시각·일정 시각·날짜 시각 고르기·「한 시간 뒤」·「내일 아침 9시」·해제, 그리고 아래에 기기 알림 켜기. 해제해도 일정 시각에는 알린다고 적는다. 알림을 눌러 앱이 열리면 어느 탭에 있든 그 메모가 **시트**로 뜬다 (`HomeView`).

### 날짜 시트 — 달력 위에서 가리킨다

날짜를 묻는 상자를 띄우지 않는다. 시트 안은 **같은 달 격자**(`MonthGridView`) — 칸을 누르면 그 날 (`Schedule.moved(to:)`, 시:분은 지킨다). 격자 아래 시각 한 줄: 「없음 · 09:00 · 14:00 · 직접…」.

- **비모달 성격**: 누르는 즉시 반영된다. 그래서 「취소」는 없고 「완료」만 오른쪽 위 — "Use a nonmodal view when you want to present supplementary items that affect the main task in the parent view" (→ 노트 §4 Sheets). 아래로 쓸어 닫는다.
- **medium·large detent + 그래버** ("Support the medium detent for progressive disclosure" / "Include a grabber in resizable sheets"). medium 에 격자가, large 에 시각 휠까지.
- 「날짜 떼기」는 툴바의 Cancel 자리가 아니라 **격자 아래 destructive 글자 단추**다 — Cancel 자리는 「바꾼 것을 버린다」는 뜻이다.
- 유리 시트 그대로. 종이색 바탕을 칠하지 않는다.

### 자리 카드 — 지도는 여기서 그린다, 길은 지도 앱이 찾는다

맥의 설계는 「이 앱은 지도를 그리지 않는다」였다 (`MapLink`, DESIGN §14.5). 폰에서는 뒤집는다 — 2026-09-14 결정. 같은 날 저녁 맥도 따라갔다 (`Sources/LazyMemoUI/Views/PlaceCards.swift`, 리졸버는 `LazyMemoPlaces` 로 공유): 종이 머리의 같은 카드, 다만 지도 앱은 애플 하나(카카오맵은 우클릭의 웹 주소)이고, 기본 종이(200pt)에는 카드가 설 자리가 없어 카드가 처음 설 때 종이가 320pt 로 한 번 자란다 (`NoteWindowController.paperWithMap`). 종이 **머리**에 자리 카드가 앉는다: 만질 수 없는 작은 지도 한 장(`Map`, 핀 하나, `interactionModes: []`), 이름, 그리고 가는 길을 열 지도 앱 단추. 자리가 여럿(`place:` 하나 + 본문의 `@낱말`들, `MemoPlaces`)이면 카드가 여럿이고 옆으로 **쓸어 넘긴다** — 한 장씩 멈추는 페이지 스크롤(`scrollTargetBehavior(.paging)`), 아래 점이 몇째 장인지 말한다. 키보드가 올라와 있는 동안은 접는다.

```
‹
┌──────────────────────────────────────┐
│ ┌──────────────────────────────────┐ │
│ │        (지도 · 핀 「강남역」)        │ │ ← 132pt, 만질 수 없다
│ │ 📍 강남역        (카카오맵)(네이버 지도)(애플 지도) │ │ ← 깔린 앱만
│ └──────────────────────────────────┘ │
│              ● ○                     │ ← 자리가 여럿일 때만
│ 치과 예약 — 강남역 3번 출구            │ ← 본문
```

- **길은 재지 않는다.** 처음 안은 「지금 자리에서 걸리는 시간과 나설 시각을 카드에 적는다」였는데, 그러려면 메모를 열 때마다 위치를 읽고 길을 재야 한다. 사용자가 이미 쓰는 지도 앱이 그것을 더 잘 하고, 우리는 좌표와 이름만 건네면 된다 — 카카오맵 `kakaomap://route?ep=…&by=PUBLICTRANSIT`, 네이버 `nmap://route/public?dlat=…`, 애플 `MKMapItem.openInMaps(transit)`. 출발지는 비워 세 앱 다 **지금 위치**에서 찾는다. 깔린 앱만 단추로 선다 (`LSApplicationQueriesSchemes`).
- **이름은 좌표로 바꿔야 지도가 선다.** 「강남역」이 어디인지는 애플 지도에 물어야 한다 (`MKLocalSearch`) — 메모를 열 때 그 이름 하나가 나간다. 파일에 `geo:` 가 있으면 묻지 않고, 첫 자리의 답은 `geo:` 에 적어 둔다 — 다음엔 폰도 맥도 안 묻고, 「가면 떠오르기」도 그 자리를 안다. 본문의 자리는 파일에 칸이 없어 실행 안에서만 기억한다. 못 찾으면 카드는 이름만 들고 「지도에서 못 찾은 자리」라고 적는다.
- `LazyHStack` 이 아니라 `HStack` 이다 — 게으른 가로 스택은 세로로 주어진 자리를 다 채워, 머리에 앉힌 카드가 화면을 통째로 먹고 글이 뒤로 숨었다 (실제로 났던 일).

### 바깥에서 바뀌면 화면이 따라온다

`MemoTextSync` 의 세 규칙 그대로 (1판과 같다): 조합 중이면 되밀지 않는다 · 내용이 같으면 대입하지 않는다 · 반영할 때 커서를 되돌린다. 600ms 디바운스, 뒤로 갈 때·앱이 물러날 때는 즉시.

### 사진 — 맥이 붙인 것을 본다, 폰에서 붙이지는 않는다

맥의 종이는 사진을 글 아래에 붙이지만(`PhotoStrip`) 폰의 종이는 화면 전체가 글 칸이라 아래가 없다. 그래서 자리 카드처럼 **머리에 앉는다** (`PhotoCardsView`, `safeAreaInset(.top)`, 자리 카드 다음). 한 장이면 전폭, 여럿이면 옆으로 쓸어 넘기는 띠. 높이는 180pt 뚜껑 — 뚜껑에 걸리면 채워서 자르고, 누르면 전체 화면으로 펼친다(`PhotoViewer`, 검은 바탕, 닫기). 키보드가 올라와 있는 동안은 접는다 (자리 카드와 같다). 본문의 `![](attachments/…)` 줄은 **감춘다** (`MachineLines`, `PaperTextView`) — 2026-09-17 까지는 「지우면 사진이 떨어진다는 뜻이라 감추지 않는다」였는데, 사용자가 본 것은 사진 카드 아래 경로 글자였다. 글자는 파일에 그대로고(글꼴을 0.01pt 로 줄일 뿐, 맥의 `MarkdownStyler` 와 같은 수), 커서가 그 안에 들어가면 뒤로 내보낸다 — 참조 사이에 글자가 끼면 참조가 깨진다. 떼는 길은 카드다: 길게 누르면 「사진 떼기」. 「## 가는 길」 절도 같은 규칙으로 감추고(카드가 대신 선다), 그 안에 든 커서는 절 **앞** 빈 줄로 나온다 — 글 끝을 눌러 이어 적으면 절 위에 적힌다.

**iCloud 가 자리만 잡아 둔 사진.** 메모 파일은 `MemoVault` 가 내려받기를 청하지만 사진은 메모가 아니라 거기 끼지 않았다 — 맥이 붙인 사진이 폰에서는 숨은 `.이름.png.icloud` 로만 있었다. 메모를 열 때 `AttachmentStore.availability(of:)` 가 청하고, 카드는 「내려받는 중」을 보이다가 파일이 오면 그림으로 바뀐다. 파일도 자리도 없으면 「아직 없는 사진」이라고 적는다 — 빈 칸을 두면 붙인 사람은 잃은 줄 안다.

화면에 드는 것은 900px 로 줄인 그림이다(ImageIO 다운샘플). 원본은 펼칠 때만 읽는다 — 맥의 메모리 규칙(§11)과 같다. 폰에서 사진을 **붙이는** 것은 여전히 다음 판이다.

## 6. 달력

### 엄지 동선

달력 탭 → 칸을 누른다 → 그 날이 아래에 선다 → 줄을 오른쪽으로 밀면 하루 미룬다.

### 레이아웃

위에 달, 아래에 그 날 (맥 세로 창과 같다, §10.8). 여섯 주 높이 예약.

```
9월  2026                    ‹  ›  오늘        ← 큰 제목 자리
일  월  화  수  목  금  토
    1   2   3   4   5   6
 …
14 (15) 16 …                                  ← 오늘: accent 원. 고른 날: 밑줄
─────────────────────────────────────
15일 (월)                          ✎ 이 날에 적기
15:00  ● 치과 예약
       ● 회의 자료 보내기
```

| 조각 | 규칙 |
|---|---|
| 달 이름 | 크다. `‹ ›` 와 「오늘」이 늘 보인다 |
| 요일 | 일요일 `sundayInk`, 토요일 `saturdayInk` |
| 칸 | 44×44 이상. 일정 수만큼 **번진 잉크** 세기가 오른다 (최대 0.4). 숫자를 세지 않는다 (§10.4) |
| 오늘 | accent 원, 크림 숫자 — 시스템 Calendar 의 채운 원과 같은 문법, 색만 우리 것 |
| 고른 날 | 밑줄 한 획 |
| 앞뒤 달 | 40%, 누르면 그 달 |
| 그 날 | `DayAgenda.rows`. 시각은 등폭 숫자 |

### 손짓

| 손짓 | 결과 |
|---|---|
| 칸 누름 | 그 날이 아래에 선다 |
| 좌우로 쓸기 (격자) | 달을 넘긴다 — 판이 손가락을 따라오고, 놓으면 흘러갈 자리가 반을 넘겼는지로 넘길지 돌아올지 정한다 (`predictedEndTranslation`). 화살표·「오늘」도 같은 미끄러짐. "Touch and content should stay together and move as one thing" (→ 노트 §2, 803). Reduce Motion 이면 밀지 않고 바꿔 끼운다 |
| 줄 오른쪽으로 밂 | 「미루기」 — `postponed(notBefore:)`. 앞으로 미는 방향 (Mapping → 노트 §2) |
| 줄 왼쪽으로 밂 | 「날짜 떼기」 · 「지우기」(맨 끝) |
| 줄 누름 | 편집 |
| **줄을 길게 눌러 끌어 칸에 놓기** | 그 날로 옮긴다 (`moved(to:)`). 시스템 끌기(`draggable`/`dropDestination`) — 들리고, 따라오고, 놓으면 간다. "Touch and content should stay together and move as one thing" (→ 노트 §2, 803). 1판의 「들고 기다리기」 모드는 뺀다 — 우리만의 손짓이고 모드다 ("avoid creating a unique gesture to perform a standard action" → 노트 §5) |
| 컨텍스트 메뉴 | 미루기 · 다른 날로(→ 날짜 시트) · 날짜 떼기 · 지우기 — 끌기 못 쓰는 사람의 길 |
| ✎ 「이 날에 적기」 | 펜이 올라오고 「9월 15일 · 달력으로」 칩이 물려 있다. 적은 글에 날짜가 있으면 그쪽이 이긴다 (`QuickSchedule.make`) |

세 동사 모두 `UndoManager` 에 이름이 달린다 — 「미루기」·「9월 16일로 옮기기」·「날짜 떼기」.

### 남의 일정

1차에서는 묻지 않는다 (1판과 같다).

## 7. 휴지통

툴바의 휴지통 단추 → push. 「휴지통」 제목.

```
‹ 메모                                  휴지통
● 옛 장보기                     3일 전 지움  되돌리기
● 회의 메모                     어제 지움    되돌리기
                        30일이 지나면 스스로 비웁니다
```

- 줄은 목록의 줄과 같되 제목이 `.secondary` (불투명도 55% 가 아니라 — 대비). 시각 자리에 「N일 전 지움」(`MemoTimeLabel.elapsed`).
- 「되돌리기」는 낱말 단추, 44pt. 오른쪽으로 밀어도 된다.
- **비우기 단추는 없다** (D6).
- 비어 있으면 「비었습니다」 한 줄.

## 8. 공유 시트 — 「lazymemo 에 적기」

```
┌──────────────────────────────────────┐
│ 그만두기        lazymemo 에 적기   남기기 │  ← 유리 바. Cancel 왼쪽, 확정 오른쪽
│ ┌──────────────────────────────────┐ │
│ │ 다음 주 화요일 회의 자료 링크      │ │  ← 공유된 글, 고칠 수 있다
│ │ https://…                        │ │
│ └──────────────────────────────────┘ │
│ [ 9월 15일 (화) · 달력으로 ]          │  ← 읽은 것이 있으면 칩 (§3 과 같다)
└──────────────────────────────────────┘
```

- "Cancel button: leading edge… Done button: trailing edge" (→ 노트 §4 Sheets). 「남기기」는 프로미넌트.
- 펜과 같은 규칙으로 읽는다 (`InboundNote` → `NoteReader`). 폴더·위치·색은 없다 — 문은 좁을수록 안전하다.
- 「남기기」 → 파일 하나가 떨어지고 시트가 닫힌다. 확인 알림은 없다 — 닫히는 것이 확인이다 ("reserve this type of confirmation for activities that are sufficiently important").
- 로컬 폴백은 App Group (구현됨, 커밋 `455d237`).

## 9. 지금 여기

펜 왼쪽 끝의 **시스템 위치 단추**. "Consider using the location button to give people a lightweight way to share their location for specific app features… Attach their location to a message or post" (→ 노트 §4 Privacy).

- 첫 실행에 아무것도 묻지 않는다. 단추를 누를 때 시스템이 「한 번 허용」과 같은 권한을 준다 — 우리가 권한 알림을 띄우지 않는다.
- 「항상」 권한은 요구하지 않는다 (1판과 같다).
- 좌표는 메모 파일의 `geo:` 에만 적힌다.
- `Info.plist` 의 위치 용도 문장은 능동태 한 문장 — 「이 자리의 주소를 메모에 붙입니다.」 ("Write copy that clearly describes how your app uses…").

## 10. 색과 글자 — 시스템과 나누는 자리

| 자리 | 색 | 근거 |
|---|---|---|
| 종이 바탕·본문 잉크 | `Paper.surface`·`Paper.ink` — 커스텀, **라이트·다크·Increase Contrast 세 벌** | "If you define a custom color, make sure to supply light and dark variants, and an increased contrast option" (→ 노트 §6) |
| 둘째 줄·시각·장소·안내 | 시스템 `.secondary`/`.tertiary` (계층 스타일) | 대비를 시스템이 지킨다 |
| 탭바·툴바·펜의 심볼과 글 | 모노크롬 (틴트 없음) | "prefer using the default monochromatic appearance of toolbars" |
| 「남기기」 | accent 틴트 바탕 + `onAccent` 글 | "apply color to the background rather than to symbols or text" |
| 오늘 원·고정 핀·켜진 상태 | `Theme.accent` / `accentInk` | "reserve it for elements that truly benefit from emphasis, such as status indicators or primary actions" |
| 날짜 조각 | `highlightInk` (5.2:1) | 1판 그대로 |
| 종이 색 점 | `MemoColor.ink` | 1판 그대로 |

크림 종이는 "primarily monochromatic content" 라, 포레스트를 앱 accent 로 두는 것은 애플이 권하는 경우 그 자체다 (→ 노트 §6). 글자는 전부 **텍스트 스타일**(`.largeTitle`·`.body`·`.subheadline`·`.caption`) — 고정 pt 는 없다.

## 11. 접근성

- 과녁 44×44 — 펜의 칩·위치 단추·툴바 항목·격자 칸 전부.
- Dynamic Type: 200% 까지. 큰 글자에서 줄은 **쌓인다**(시각이 제목 아래로). 펜은 다섯 줄까지 자라고 그 뒤는 안에서 스크롤.
- VoiceOver: 줄 「장보기, 내일 15시, 노랑, 고정됨」 + 동작 로터에 지우기·고정·폴더·달력에 놓기. 펜 「적기」, 단추 「메모 남기기 / 달력에 남기기」, 칩은 힌트까지. 격자 칸 「15일 월요일, 일정 2」.
- Reduce Motion: 새 줄 밝힘·스크롤은 페이드로. 끌기 미리보기는 시스템이 알아서 줄인다.
- Reduce Transparency·Increase Contrast: 유리는 시스템이 처리한다. 종이 색은 세 벌 중 고른다. 바램은 꺼진다.
- 색만으로 말하지 않는다: 고정은 핀, 날짜는 낱말, 켜진 칩은 바탕 **과** 테두리.

## 12. 다크

`Paper.surface` 는 따뜻한 숯색, `Paper.ink` 는 미색. `accentInk` 는 밝은 세이지. 유리는 시스템이 어둡게 한다 — 우리 것은 종이뿐이다.

## 13. 구현 순서

1. **층 돌려놓기** — 뒤집힌 목록 풀기, 펜을 액세서리(유리)로, 부제, 툴바. 스모크 화면이 이 모양이 된다.
2. **되돌리기를 시스템으로** — `UndoManager` 등록, 띠 제거, 결과 보이기(스크롤·밝힘).
3. **편집 꼬리를 툴바로** — `.bottomBar` 항목 + `ToolbarSpacer`, 색은 메뉴, 날짜 시트 detent·그래버·「완료」.
4. **달력 끌기** — `draggable`/`dropDestination`, 「들고 기다리기」 제거.
5. **색·대비** — `.secondary` 로, `fadedInk` 제거, Increase Contrast 판, `MemoAge` 는 제목 색으로.
6. **위치 단추** — `LocationButton`.
7. VoiceOver 동작·Dynamic Type 쌓기·다크 렌더 확인.

각 단계는 XCUITest 한 벌로 손을 대신한다 (`SmokeTests`).

## 14. 바뀐 결정 — 1판 대비

| 항목 | 1판 | 2판 | 근거 (노트) |
|---|---|---|---|
| 목록 차례 | 펜 위로 쌓기 (뒤집힌 목록) | 위에서 아래, 고정 → 최근순. 새 줄은 위에 생기고 화면이 그리로 간다 | §4 Layout "most important… near the top" · §7 애플 목록 앱은 뒤집지 않는다 · §3 219 scroll edge 를 꺼야 했던 구현 |
| 펜의 자리·재질 | `safeAreaInset` 의 종이색 줄 | `tabViewBottomAccessory` 의 **유리** 펜 (접히면 한 줄) — 실기기 확인 뒤 안 되면 `safeAreaInset` + 같은 유리 | §3 Materials 층 원칙 · 356 액세서리는 persistent feature |
| 펜 글자 | `.title2` light | `.body` | §6 텍스트 스타일 · 액세서리 높이 |
| 글 칸의 지우기 | 없음 | ⊗ | §5 Text fields "Display a Clear button" |
| 칩을 눌러 읽지 않기 | 있음 | **유지** — 켜짐/꺼짐이 눌리게 생김 | §4 Entering data "correct errors right away" |
| 되돌리기 | 펜 위 8초 띠 | **시스템** (흔들기·세 손가락) + 이름 달린 `UndoManager` + 결과 보이기 + 휴지통 단추 | §4 Undo "buttons only when necessary" |
| 저장 자리 표시 | 펜 위 상시 띠 + ⋯ 메뉴 첫 줄 | 큰 제목의 **부제** + More 의 「iCloud 설정 열기」 | §4 Feedback Mail 의 「Updated Just Now」 · §4 Layout 불투명 띠 금지 |
| 툴바 | ⋯ 하나 | 휴지통 단추 + More(있을 때만) | §5 Toolbars "include all actions… only add More if you really need it" |
| 제목 | inline | 큰 제목 「메모」 | §5 Toolbars iOS "Use a large title" |
| 편집 꼬리 | 종이색 커스텀 줄, 색은 점 펼침 | **표준 바닥 툴바**(키보드 위로 따라감), `ToolbarSpacer` 세 묶음, 색은 메뉴 | §5 Virtual keyboards "Use standard toolbar" · 356 grouping |
| 편집 열 때 키보드 | 안 올림 | **유지** | §7 Notes 관찰 |
| 날짜 시트 | large, 「닫기」+ Cancel 자리에 「날짜 떼기」 | medium·large + 그래버, 「완료」, 「날짜 떼기」는 내용 안 destructive 단추, 유리 시트 | §4 Sheets detent·grabber·Cancel 의 뜻 |
| 달력 옮기기 | 「들고 기다리기」 모드 | **시스템 끌기** + 컨텍스트 메뉴/날짜 시트 | §2 803 "touch and content… move as one" · §5 Gestures 우리만의 손짓 금지 |
| 「달력에 놓기」(목록) | 달력 탭으로 넘어가 모드 | 날짜 시트 | 같다 |
| 찾은 것 상한 | 8장 + 「… 외 N장 더」 | 없음, 「N장 중 M장」 범위 표시 | §4 Searching "display the current scope" |
| 둘째 줄·시각 색 | `fadedInk` 52% | 시스템 `.secondary` | §6 대비 4.5:1 (52% 는 ≈3.3:1) |
| 바램 | 줄 불투명도 55~100% | 제목 색만 `ink`→`.secondary`, Increase Contrast 면 끔 | §6 · §8 충돌 표 |
| 지금 여기 | 커스텀 핀 + 권한 알림 | **시스템 `LocationButton`** | §4 Privacy |
| 탭 배지 | 「달력에 남기기」 뒤 잠깐 점 | 없음 | §5 Tab bars "Reserve badges for critical information" |
| 편집에서 탭바 | 숨김 | 숨김 **유지** (펜도 함께) — HIG 와의 긴장은 §15 | §5 Tab bars · Photos 관찰 |
| 은유·탭 둘·폴더 칩·휴지통·공유 시트 | — | 유지 | §2 359 · §4 Onboarding |

## 15. 확신이 없는 자리

1. **액세서리와 키보드.** `tabViewBottomAccessory` 안의 글 칸이 키보드 위로 오르는지 애플 문서에 없다. 안 오르면 `safeAreaInset` 유리 펜으로 물러난다 — 생김새는 같다. **확인 결과(2026-09-13, iOS 26.5 시뮬레이터): 오르지 않는다** — 키보드가 탭바와 함께 펜을 덮었다. 구현은 `safeAreaInset` 이다 (`HomeView`). 접힘(`.inline` 알약)은 코드에 남겨 두되 지금은 닿지 않는다.
2. **되돌리기의 발견성.** 흔들기는 애플의 관용구지만 「조작 불편은 곧 실패」 앞에서 8초 띠보다 덜 보인다. 휴지통 단추를 툴바에 두어 메우지만, 실기기 손검증에서 「지운 걸 못 찾겠다」가 나오면 iOS 26 의 Undo 툴바 항목(시스템 심볼, 툴바 안 — HIG 가 허용하는 유일한 단추)을 편집 화면에 더한다.
3. **편집에서 탭바 숨김.** HIG 는 구역 이동 시 탭바를 보이라 하고, Photos 는 내용을 열면 감춘다. 우리는 「펜이 종이 밑에 보이면 안 된다」로 감춘다. 사용자가 편집 중 탭을 바꾸고 싶어 하면 다시 본다.

## 16. 빼기로 한 것

| 뺀 것 | 이유 |
|---|---|
| 서랍·종이 | §1 |
| 검색 탭 | 펜이 겸한다. 탭은 동작이 아니다 |
| 설정 화면 | 남는 설정이 하나뿐이다 |
| 되돌리기 띠 | 시스템 되돌리기 + 휴지통 |
| 「들고 기다리기」 | 시스템 끌기 |
| 사진 붙이기·공유 | 다음 판 — 맥이 붙인 사진을 **보는** 것은 된다 (§5 사진) |
| 시스템 캘린더 읽기 | 다음 판 |
| 가면 떠오르기 | 종이가 없고 알림 권한이 필요하다 |
| 위젯·잠금 화면 | 이 계획 밖. 다만 「앱을 열지 않고 적는」 길은 결국 이것이다 — `docs/RECALL_PLAN.md` 의 다음 실험 |
