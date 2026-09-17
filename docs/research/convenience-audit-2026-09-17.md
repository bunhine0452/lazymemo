# 편의성 감사 2026-09-17 — 조작 경로를 다시 걸어 본 것, 그리고 애플 26 이 새로 연 문

> 2026-09-17 · 연구만. 코드는 건드리지 않았다.
> 방법: ① 맥·폰의 조작 경로를 코드로 따라 걸으며 **손이 몇 번 가는지** 셌다(`Sources/LazyMemoUI`·`ios/LazyMemo`·`Sources/LazyMemoReminders`) ② `site/media` 의 시연 영상을 프레임으로 떠서 화면을 봤다 ③ 애플 원문(HIG 데이터 엔드포인트·WWDC25 트랜스크립트·뉴스룸)과 같은 문제를 푸는 앱(Notes Quick Note·Drafts·Antinote·Things·Reminders)을 읽었다.
> 하지 않은 것: 앱을 띄우지 않았고 실기기 손검증도 없다. **클릭·끌기·레벨 전환은 사람 눈이 필요하다** — 그런 항목은 그렇게 적었다.
> 앞선 감사 두 번(`.oculpm/discussion/lazymemo-lazy-comfort`·`lazymemo-pro-lazy-ux`, 2026-08)과 어제의 로드맵(`.oculpm/planner/lazymemo-upgrades-2026-09.md`)이 이미 잡은 것은 되풀이하지 않고 **거기 없는 것만** 적었다.

## 0. 한 문장

**적는 길은 이미 최단이다(맥 2키, 폰 2탭). 걸리는 곳은 「적은 뒤」 — 시각이 되어 종이가 나오고 배너가 울리는 그 순간에 손이 하나도 없다.** 배너를 눌러 열고, 우클릭하고, 창을 띄우고, 칩을 누르고, 또 단추를 눌러야 「한 시간 뒤」가 된다. 알림·떠오름의 순간에 한 번의 손으로 미루고 내려놓게 하는 것이 이번 감사의 첫 순위이고, 그다음이 설정을 메뉴 속 메뉴에서 꺼내는 것, 첫 실행이 「로그인할 때 시작」을 주는 것이다. 애플 26 은 「앱을 열지 않는」 문을 셋 더 열었다 — Spotlight 액션, AlarmKit 의 출발 카운트다운, 아이폰 Live Activity 가 맥 메뉴바에 오르는 것.

## 1. 잘 되는 것 — 되풀이 확인만

| 약속 | 실제 (코드·영상) | 다른 앱과 견주면 |
|---|---|---|
| 적기는 최단 | 맥 `⌥⌘N` → 글 → `⌘↵` (2키). 폰은 켜면 펜에 포커스 → 글 → 「남기기」 (2탭) | Drafts 맥 캡처도 `⇧⌘2` → `⌘↩` 이고 "The capture window will persist the text you are working on until you explicitly save or clear the text" — 같은 결정. Notes Quick Note 는 Fn+Q 와 핫코너 |
| 형식을 안 배운다 | 날짜·자리·되풀이를 앱이 읽고 칩으로 보인다. 되묻기는 상자를 안 닫는다 | Reminders 도 제목의 날짜를 읽지만 lazymemo 의 「어디서 출발하시나요?」까지는 없다 |
| 되돌릴 수 있다 | 하드 삭제 없음, 8초 인라인 되돌리기(맥), 시스템 되돌리기+휴지통(폰) | — |
| 앱이 시간에 따라 스스로 한다 | `DayClock`·`DueClock`·`Tidy` — 8월 감사의 「타이머 0개」는 닫혔다 | — |
| 문이 넷 | 서비스 메뉴·`⌥⌘V`·`lazymemo://`·MCP·공유 시트·위젯 「적기」 | Drafts/Things 의 문 수와 같다. 없는 것은 §4 |

## 2. 걸리는 자리 — 조작 수로 잰 것

손이 가는 횟수를 셌다. 「지금」은 코드가 정한 경로이고, 「제안」은 그 경로를 줄인 뒤의 횟수다.

### 2.1 알림·떠오름의 순간에 손이 없다 — **첫 순위**

이 앱이 「적었는데 그냥 지나갔다」를 막으려고 만든 것이 종이가 나오는 것과 배너다(`DueClock`, `ReminderCenter`). 그런데 나온 순간에 할 수 있는 것이 **열기뿐**이다.

| 장면 | 지금 | 걸림 | 제안 | 뒤 |
|---|---|---|---|---|
| **배너가 울렸다 → 한 시간 뒤에 다시** (맥·폰) | 배너 누르기 → 메모 열림 → 우클릭 → 「다시 보기…」(맥) / 종 단추(폰) → 「한 시간 뒤」 → 「이때 다시 보기」 = **4~5** | `SystemReminderQueue.add` 가 `categoryIdentifier` 를 안 준다 — 알림에 동작이 하나도 없다. Reminders·Calendar 의 배너에는 「Snooze」「Mark Complete」가 있다 | `UNNotificationCategory` 둘 — 다시 보기(「한 시간 뒤」「내일 아침」「봤어요」), 출발(「지도 열기」「10분 뒤」). 배너를 길게 누르면 그 자리에서 끝난다 | **1** |
| **종이가 나왔다(맥) → 나중에** | 나온 종이는 하루가 끝날 때까지 그대로다(`DueClock` 머리말 — 옳은 결정). 미루려면 우클릭 → 「다시 보기…」 → 창 → 칩 → 단추 = **4** | 폰의 「지금」 띠는 **왜 나왔는지**(「오늘 일정」「고정」)와 「봤어요」를 카드에 적는데, 맥의 나온 종이에는 둘 다 없다. 같은 사건에 두 기기의 대답이 다르다 | 나온 종이의 머리 한 줄(`PaperGrip` 아래) — 「⏰ 15:00 치과 · 한 시간 뒤 · 내일 아침 · 봤어요」. 하루가 끝나면 줄도 사라진다. 캡슐(§7.1 의 다섯→셋 다이어트)은 건드리지 않는다 — 이 줄은 **나온 종이에만, 그날만** 선다 | **1** |
| **「다시 보기」 창의 「한 시간 뒤」** (맥·폰 `RecallViews.swift:162-166`) | 칩을 누르면 **날짜 피커가 바뀔 뿐**, 「이때 다시 보기」를 또 눌러야 저장 = 2 | 폰의 날짜 시트(`DateSheet`)는 칩을 누르는 순간 `onChange` 로 적용된다. 같은 앱의 두 시트가 다르게 군다 — WWDC17 802 Consistency "representing similar design features in similar ways" | 칩은 **누르는 순간 저장하고 닫힌다.** 피커는 「다른 시각…」 아래로 | 1 |
| **폰 「지금」 띠의 오늘 일정 → 내일로** | 카드 길게 → 메뉴에 봤어요·고정·지우기뿐(`NowBand.swift:61-67`). 미루려면 카드 → 편집 → 달력 단추 → 시트 → 「내일」 = **3~4** | 달력 탭의 같은 메모는 오른쪽 밀기 한 번이 「미루기」(`CalendarView.swift:102`) — **같은 메모, 탭마다 다른 손짓** | 「지금」 카드와 목록 줄(`StackView.swift:138`)의 leading 밀기·컨텍스트 메뉴에 「하루 미루기」(일정이 있을 때만). 달력 탭과 같은 낱말·같은 방향 | 1 |

이 넷은 같은 뿌리다 — **떠오르는 순간이 곧 결정의 순간**인데 결정 도구가 편집 화면 뒤에 있다. HIG Notifications: "Prefer actions that let people perform common, time-saving tasks that eliminate the need to open your app." / "Avoid providing an action that merely opens your app."

### 2.2 설정이 메뉴 속 메뉴다

`MenuBarController.settingsItem()` 의 머리말은 「항목이 몇 개뿐이라 창을 따로 짓지 않는다」인데, 지금 그 하위 메뉴는 **열다섯 줄**이다(알림·단축키·로그인·투명도·폴더·iCloud·Claude 둘·가면 떠오르기·지금 여기·시스템 캘린더·Spotlight·새 판·링크 카드·가는 길) — 대부분 부제까지 달려 있다. 토글 하나를 켜면 메뉴가 닫히므로 둘을 바꾸려면 우클릭 → 설정 → 항목을 **두 번** 한다. 「지금 무엇이 켜져 있나」를 한눈에 볼 자리가 없다.

- HIG Settings: "Minimize the number of settings you offer… too many settings can make the experience feel less approachable, while also making it hard to find a particular setting." / "Put general, infrequently changed settings in your custom settings area." / macOS "It's quick to open a custom settings window using the standard Command–Comma (,) keyboard command".
- 제안: **설정 창 하나**(`⌘,` 는 빠른 입력 상자가 열려 있을 때). 묶음은 README 의 프라이버시 표를 그대로 옮긴다 — 「이 맥」(알림·단축키·로그인·투명도) · 「메모 폴더」 · 「밖으로 나가는 것」(링크 카드·새 판·가는 길·Claude) · 「이 맥이 함께 보는 것」(시스템 캘린더·Spotlight·가면 떠오르기). 그러면 설정 창이 곧 「무엇이 나가나」의 답이 되고, 프라이버시 표와 설정이 한 몸이 된다. 메뉴에는 「설정…」 한 줄만.
- 창 없이 가려면: 하위 메뉴를 그 네 묶음으로 가르는 것만으로도 찾기는 준다. 다만 「토글마다 메뉴가 닫힌다」는 남는다.

### 2.3 첫 실행이 「로그인할 때 시작」을 주지 않는다

`LoginItem.swift` 머리말이 스스로 적었다 — 「이 앱은 켜져 있지 않으면 아무것도 아니다… 재부팅 뒤에 앱을 다시 켜는 것은 게으른 사람이 가장 안 하는 일이다 — 그래서 이 앱의 다른 모든 편안함보다 이 스위치 하나가 먼저다.」 그런데 기본은 꺼짐이고, 켜는 자리는 우클릭 → 설정 → 아홉 번째 줄이며, 첫 실행 창의 04 「준비 완료」는 단축키 셋을 적고 끝난다(`WelcomeWindow.swift:160-164`). 안내 종이의 문장 한 줄(`WelcomeNote`)이 유일한 길이다.

- HIG Menu bar extras 가 메뉴바 아이콘에 대해 하는 말이 그대로 적용된다: "To ensure discoverability, however, consider giving people the option of doing so during setup."
- 제안: 04 단계에 체크박스 하나 — 「☑ 로그인할 때 시작 (껐다 켜도 종이가 그대로 있습니다)」. `SMAppService` 는 권한을 묻지 않으므로 「첫 실행에 아무것도 묻지 않는다」와 부딪히지 않는다. **기본값은 여전히 사용자가 정한다** — 체크박스가 켜진 채로 나오되 누르는 것은 사람이다. 비용: 한 줄.

### 2.4 안내 문구에 「시키기」 예가 없다

`CapturePrompt.all` 스물한 줄 중 묻기 예는 하나(「치과 언제였지? — 물으면 답합니다」), **시키기 예는 없다.** 「장보기 내일 아침에 다시 알려줘」「치과 목요일로 미뤄」는 README 를 읽은 사람만 안다 — 게으른 사람은 README 를 읽지 않는다. WWDC17 802 Visibility: "The usability of a design is greatly improved when controls and information are clearly visible." 제안: 시키기 예 둘을 섞는다(맥·폰이 같은 배열을 쓰므로 한 곳). 비용: 두 줄.

### 2.5 메뉴바 아이콘이 아무것도 받지 않는다

끌어 놓기는 편집기(`MemoNSTextView.performDragOperation`)와 서랍 줄에만 있다. 사파리에서 링크·글·사진을 **메뉴바 아이콘에 떨어뜨리면 새 종이**가 되는 길이 없다 — 지금 그것을 하려면 글자를 고르고 우클릭 → 서비스 → 「lazymemo 에 적기」(3) 이거나 복사 → `⌥⌘V`(2). 끌어 놓기는 **1** 이고 권한이 없다(`NSStatusBarButton` 에 `registerForDraggedTypes` — Yoink·Dropzone 류가 쓰는 길). 받은 것은 `Inbound` 파서를 지나므로 지도 앱의 공유 텍스트도 그대로 자리가 된다. 비용: 낮음. 사람 눈 확인 필요 — 아이콘 위에서 커서가 바뀌는지.

### 2.6 키보드로 달력·서랍에 못 간다

메뉴 항목에 키가 있는 것은 「종료 ⌘Q」뿐이다. 전역 단축키를 더 늘리는 것은 충돌을 늘리는 일이라(§13 「⌥⌘N 이 다른 앱과 충돌하지 않는가」) 맞지 않다. 대신 **이미 있는 한 상자**에 앱 명령을 후보로 세운다 — 「달력」「서랍」「설정」「오늘」을 치면 목록 첫 줄에 「달력 열기 ⌘↵」. `AssistantIntent` 가 이미 낱말로 갈래를 정하니 갈래 하나가 는다(D2 의 「사람은 모드를 고르지 않는다」 그대로). 비용: 낮음. 우선순위: 낮음 — 손이 키보드에 있는 사람만 얻는다.

### 2.7 사람 눈이 필요한 것 (이 문서가 못 잰 것)

- `docs/DESIGN.md` §13 의 `{#env-wallpaper-click}` — **「월페이퍼 클릭 시 데스크탑 표시」에 종이가 살아남는가**는 이 앱의 「상주」가 편의인지 아닌지를 가르는 단 하나의 질문이다. 하루의 대부분 바탕화면은 브라우저 뒤에 있고, 게으른 사람의 「종이 보기」는 그 클릭 한 번이다. 살아남는다면 「peek」 단축키 같은 것은 필요 없고, 쓸려 나간다면 레벨부터 다시 봐야 한다. 코드로는 알 수 없다.
- 2.5 의 커서 반응, 2.1 의 머리 줄이 `PaperGrip` 끌기와 겹치지 않는지.

## 3. 애플 26 이 새로 연 문 — 앱을 열지 않는 길

어제 로드맵의 `{#app-intents}`·`{#lock-widget}` 을 전제로, 거기 없는 것 셋.

### 3.1 Spotlight 액션 (macOS 26) — `⌥⌘N` 을 모르는 사람의 문

뉴스룸: "Users can now take hundreds of actions directly from Spotlight — like sending an email, creating a note, or playing a podcast — without jumping between apps." / "Spotlight introduces quick keys, which are short strings of characters that get users right to the action they're looking for." WWDC25 260 이 조건을 적는다 — "the parameter summary, which is what people will see in Spotlight UI, must contain all required parameters that don't have a default value." · 배경/전경을 가른다: "we could have a 'create event' intent be a background intent, so that people can create calendar events in the background without opening the app… the Create Event Intent can return an Open Event Intent as an Opens Intent."

- lazymemo 에 뜻하는 바: 「적기」 인텐트는 **배경**(상자를 띄우지 않고 파일에 쓴다 — `Inbound` 파서 그대로), 결과로 「메모 열기」를 `OpensIntent` 로 돌려준다. quick key 「lm」. Spotlight 를 이미 쓰는 사람에게는 `⌥⌘N` 을 배울 필요가 없어진다.
- **제약(확인 필요):** App Intents 의 메타데이터(`Metadata.appintents`)는 Xcode 빌드가 뽑는다. `swift build` 로 조립하는 GitHub 판에는 실리지 않을 가능성이 크다 — 위젯과 같은 「스토어 판만」이 될 수 있다. 첫 spike 에서 GitHub 판 번들에 메타데이터가 생기는지부터 본다.

### 3.2 AlarmKit (iOS 26) — 「출발 10분 전」을 알람으로

지금 출발 알림은 배너 하나다(켠 기기에서만). WWDC25 230: "An alarm is a prominent alert for things that occur at a fixed, pre-determined time… When it fires, the alert breaks through the silent mode and the current focus." / "Alarms support a custom countdown interface using Live Activities that your app provides. This can be viewed on the Lock Screen as well as in the dynamic island and in StandBy." / "People have the option of stopping the alert or snoozing it with an optional snooze button." / "Alarms are also supported… right on Apple Watch, if it's paired to iPhone when the alarm fires."

- lazymemo 에 뜻하는 바: 길을 고른 순간 「18:12 출발」 알람을 건다 → 잠금 화면·다이내믹 아일랜드에 **출발까지 카운트다운**이 서고, 시각이 되면 무음·집중 모드를 뚫고 울리며, 「10분 뒤」가 시스템 단추다. 앱을 열 일이 없다. §2.1 의 출발 배너 동작을 시스템이 대신한다.
- **대가:** 권한이 하나 는다 — "Before your app can schedule alarms, people will need to consent by providing authorization… it will be requested automatically when you create your first alarm." (`NSAlarmKitUsageDescription`). 이 앱의 규칙대로 **쓸 때만** 묻는다 — 길을 고른 뒤 「출발 알람 켜기」를 누를 때. 배너 알림(「이 기기에서 알림 받기」)과는 별개의 스위치이고, 프라이버시 표에 「아무것도 안 나간다」 한 줄이 는다. 맥은 언급이 없다 — 폰 전용.

### 3.3 Live Activity 가 맥 메뉴바에 오른다 (macOS 26)

HIG Live Activities: "Active Live Activities automatically appear in the Menu bar of a paired Mac using the compact, minimal, and expanded presentations." / "Offer Live Activities for tasks and events that have a defined beginning and end. Live Activities work best for tracking short to medium duration activities that don't exceed eight hours." 뉴스룸: "Live Activities from a user's nearby iPhone will now appear in the menu bar on their Mac".

- 3.2 의 카운트다운이 Live Activity 이므로 **폰이 옆에 있으면 맥 메뉴바에도 「18:12 출발 · 12분」이 선다** — 맥 쪽 코드 없이. GitHub 판 맥에도 온다(폰이 그리는 것이라). 이것이 맥의 「오늘 한눈에」가 없다는 빈자리(위젯은 스토어 판만)를 가장 싸게 메운다. 확인 필요: AlarmKit 이 그리는 카운트다운도 메뉴바에 오르는지(원문은 일반 Live Activity 만 말한다).
- 알람 없이 앱이 직접 `Activity.request` 하는 길도 있으나 **앞에 있을 때만 시작할 수 있고** 8시간 상한이라, 약속을 적는 순간(전경)에 출발이 8시간 안이면 그때, 아니면 알람이 맞다.

### 3.4 위젯이 손을 받는다 — 「지금」 위젯의 「봤어요」와 체크

스토어 판 위젯은 지금 **읽기만** 한다(`ios/LazyMemoWidgets` 에 `AppIntent` 없음). 체크리스트 한 칸을 끄려고 앱을 열어 종이를 찾는다(3). 위젯의 체크상자와 「봤어요」를 `Button(intent:)` 로 두면 **1** 이고 앱은 안 열린다. 위젯 확장은 Xcode 타깃이라 3.1 의 제약이 없다. 파일 쓰기는 `MemoService` 를 확장에서도 부르므로 「파일에 먼저 쓰고 인덱스에 통지」 규칙이 그대로다 — 다만 앱과 확장이 같은 파일을 동시에 쓰는 자리라 `{#file-coordinator}` 가 먼저다.

## 4. 다른 앱은 어떻게 푸나 — 받을 것과 안 받을 것

| 앱 | 하는 것 | 판정 |
|---|---|---|
| **Notes Quick Note** (맥) | Fn+Q 어디서든, 핫코너, 「Always resume to last Quick Note」 설정 — 새 종이냐 지난 종이냐를 사용자가 정한다 | lazymemo 의 「적던 글을 상자가 기억한다」가 같은 답. 핫코너는 시스템 예약이라 못 받는다. **안 받음** |
| **Drafts** (맥) | 전역 단축키 → 떠 있는 캡처 창, `⌘↩` 저장, 글 보존 | 이미 같다. **확인만** |
| **Antinote** (맥) | `= 127.5 * 0.83`, `timer 45`, `25 EUR in USD` — 줄 하나가 계산기·타이머·환율 | 「치는 대로 앱이 읽는다」(날짜·자리)의 연장으로 **숫자 합**은 싸다 — 장보기 줄의 「우유 3200 / 계란 6900」 꼬리에 「10,100」. 타이머·환율은 범위 밖. **선택** |
| **Things Quick Entry with Autofill** (맥) | 단축키 하나가 앞 앱의 선택 글·링크를 **알아서** 새 항목에 붙인다 | 샌드박스 밖 Helper 와 접근성 권한이 필요하다("Sandboxing in macOS prevents Things from talking to other apps directly, so… Things uses the helper app… as an intermediary"). 「첫 실행에 아무것도 묻지 않는다」와 정면 충돌. **안 받음** — 서비스 메뉴·`⌥⌘V`·§2.5 끌어 놓기가 권한 없는 같은 답이다 |
| **Reminders** (폰) | 배너의 Snooze, 목록 줄의 밀기, 키보드 위 quick toolbar | §2.1 이 이것이다 |
| **Stickies** (맥) | 제목 줄 더블클릭으로 접기 | 서랍이 같은 자리. **안 받음** |

## 5. 우선순위 — 비용 대 손 줄임

> 2026-09-17 같은 날 1~4 를 구현했다 — 배너 단추(`ReminderAction`·`ReminderCategory`, 맥·폰), 「다시 보기」 칩 즉시 저장, 첫 실행 04 의 「로그인할 때 시작」, 폰 「지금」·목록의 「미루기」. 일지: `.oculpm/journal/20260917/Features_to_add/`.

| 순위 | 항목 | 손 | 비용 | 권한 | 판 |
|---|---|---|---|---|---|
| 1 | 알림 동작(§2.1 첫 줄) — 다시 보기·출발 카테고리 | 4~5 → 1 | 낮음 (`UNNotificationCategory` + 델리게이트 갈래) | 없음(이미 켠 알림) | 맥·폰 |
| 2 | 「다시 보기」 칩 즉시 저장(§2.1 셋째 줄) | 2 → 1 | 아주 낮음 | 없음 | 맥·폰 |
| 3 | 첫 실행 04 에 「로그인할 때 시작」(§2.3) | 발견 0 → 1 | 아주 낮음 | 없음 | 맥 |
| 4 | 폰 「지금」·목록의 「하루 미루기」(§2.1 넷째 줄) | 3~4 → 1 | 낮음 | 없음 | 폰 |
| 5 | 나온 종이의 머리 줄(§2.1 둘째 줄) | 4 → 1 | 중간 (뷰 + 그날만 사는 상태) | 없음 | 맥 · **눈 확인** |
| 6 | 설정 창(§2.2) | 2n → 1 | 중간 | 없음 | 맥 |
| 7 | 메뉴바 아이콘 끌어 놓기(§2.5) | 2~3 → 1 | 낮음 | 없음 | 맥 · **눈 확인** |
| 8 | AlarmKit 출발 알람 + 카운트다운(§3.2·3.3) | 배너 → 잠금 화면·맥 메뉴바·워치 | 중간~높음 | **알람 1개, 쓸 때만** | 폰(맥은 덤) |
| 9 | 대화형 위젯(§3.4) | 3 → 1 | 중간 (`{#file-coordinator}` 뒤) | 없음 | 스토어 판 |
| 10 | Spotlight 액션(§3.1) | 단축키를 안 배워도 됨 | 중간 · spike 먼저 | 없음 | 스토어 판(확인 필요) |
| 11 | 안내 문구 시키기 예(§2.4) · 상자의 앱 명령(§2.6) · 숫자 합(§4) | — | 낮음 | 없음 | 맥·폰 |

1~4 는 하루 안에 넷 다 끝나는 크기이고 넷이 같은 문장(「떠오른 순간에 손 하나」)을 완성한다. 8~10 은 어제 로드맵의 `{#phone-no-open}` 묶음에 얹는 것이 맞다.

## 6. 부딪히는 자리와 판정

| 자리 | 애플 | lazymemo | 판정 |
|---|---|---|---|
| 나온 종이의 머리 줄(§2.1) | Designing for iOS "limiting the number of onscreen controls" — 종이 위 조작은 늘리지 말라는 쪽 | §7.1 캡슐 다이어트(다섯→셋), §14.4 「조작은 포인터가 올 때만」 | **lazymemo 규칙 안에서** — 늘 있는 단추가 아니라 **그날 나온 종이에만** 서는 줄이고, 폰의 「지금」 카드가 이미 같은 것을 한다. 하루가 끝나면 사라진다 |
| AlarmKit 권한(§3.2) | 230 "it will be requested automatically when you create your first alarm" | 「권한은 쓸 때만, 첫 실행엔 없음」 | 충돌 없음 — 길을 고른 뒤 스위치를 켤 때만. 다만 프라이버시 표의 「권한을 묻는 자리는 다섯」이 여섯이 된다 |
| 설정 창(§2.2) | HIG Settings ⌘, · 설정 창 | 「창을 여는 것 자체가 조작 한 번」(`settingsItem` 머리말) | **애플** — 그 머리말은 항목이 넷일 때 맞았다. 열다섯이면 창이 더 적은 손이다 |
| Things 식 자동 채우기(§4) | — | 「첫 실행에 아무것도 묻지 않는다」 | **lazymemo** — 접근성 권한은 이 앱이 요구하는 어떤 권한보다 무겁다 |
| 전역 단축키 추가(§2.6) | HIG Keyboards(맥) 는 표준 조합을 존중하라고만 | §13 「충돌하지 않는가」 | 추가하지 않는다 — 상자 안 명령으로 |

## 7. 못 찾은 것 · 확인이 필요한 것

- `swift build` 번들에 App Intents 메타데이터가 실리는지 — 문서에서 확인하지 못했다. spike 로 본다.
- AlarmKit 의 카운트다운(Live Activity)이 macOS 26 메뉴바에도 오르는지 — HIG 는 일반 Live Activity 만 말한다.
- `NSStatusBarButton` 의 드롭 수신이 macOS 26 에서도 되는지 — 관행이지 문서는 못 찾았다.
- 「월페이퍼 클릭 시 데스크탑 표시」와 종이(§2.7) — 사람 눈.
- 메모 중 한 줄짜리의 비율 — `⏎`=줄바꿈·`⌘↵`=남기기가 옳은지는 이 숫자가 답한다. 사용자 폴더는 읽지 않았다(개인 데이터). 알고 싶으면 `find ~/Documents/lazymemo/notes -name '*.md' | xargs -I{} sh -c 'sed 1,/^---$/d {} | grep -c .'` 로 줄 수 분포만 센다.

## 8. 출처

- HIG Notifications · Settings · The menu bar · Live Activities — `developer.apple.com/tutorials/data/design/human-interface-guidelines/{notifications,settings,the-menu-bar,live-activities}.json` (2026-09-17 읽음)
- WWDC25 260 「Develop for Shortcuts and Spotlight with App Intents」 · 230 「Wake up to the AlarmKit API」 — 세션 페이지 트랜스크립트
- Apple Newsroom 2025-06 「macOS Tahoe 26 makes the Mac more capable, productive, and intelligent than ever」
- Apple Support 「Create a Quick Note on Mac」 · Drafts User Guide 「Mac Share and Capture」 · antinote.io/features · Cultured Code 「Things Helper」
- 앞선 감사: `.oculpm/discussion/lazymemo-lazy-comfort/discussion.md`(2026-08-28) · `lazymemo-pro-lazy-ux`(2026-08-29) · `.oculpm/planner/lazymemo-upgrades-2026-09.md`(2026-09-16) · `docs/research/apple-design-principles.md`
