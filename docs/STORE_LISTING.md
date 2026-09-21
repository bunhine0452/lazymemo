# App Store 등록 정보 — 그대로 옮겨 적는 원고

App Store Connect 에 붙여 넣을 글의 정본. 여기와 스토어가 다르면 여기를 고치고 스토어를 따라 맞춘다.
숫자 제한은 애플 것이다 — 이름 30자, 부제 30자, 홍보 문구 170자, 키워드 100자(쉼표 포함), 설명 4000자.

## 앱 레코드 (플랫폼 공통)

| 항목 | 값 |
|---|---|
| 이름 | `lazymemo` |
| 부제 (앱 공통 — ASC 의 부제는 플랫폼별이 아니라 앱 정보의 한 칸이다) | `한 줄이면 메모, 날짜는 앱이 읽는다` |
| 기본 언어 | 한국어 |
| 번들 ID | `io.github.bunhine0452.lazymemo` (iOS·macOS 같은 id — 한 앱의 두 플랫폼) |
| SKU | `lazymemo` |
| 사용자 접근 | 전체 접근 |
| 카테고리 | 1차 **생산성** · 2차 없음 |
| 가격 | 무료 · 모든 국가 |
| 연령 등급 | 4+ (설문 전부 「없음」, 무제한 웹 접근 없음, 도박 없음) |
| 저작권 | `2026 Kim Hyunbin` |
| 지원 URL | https://github.com/bunhine0452/lazymemo/issues |
| 마케팅 URL | https://bunhine0452.github.io/lazymemo/ko/ (en: https://bunhine0452.github.io/lazymemo/) |
| 개인정보 처리방침 URL | https://bunhine0452.github.io/lazymemo/privacy/ |
| 라이선스 계약 | 애플 표준 EULA |

## 앱 개인정보 (App Privacy)

`docs/PRIVACY.md` 끝의 초안과 같다.

- **데이터 수집 안 함** (Data Not Collected). 개발자에게 오는 것이 없다 — 분석·크래시 리포트·광고 식별자 없음.
- 추적 안 함. 서드파티 SDK 없음.
- 위치는 기기 안에서 쓰이고 애플 지오코딩에만 좌표가 간다. 메모는 사용자 본인의 iCloud 로만 간다 — 애플 정의의 「수집」(개발자 서버로 전송)이 아니다.

## 심사 메모 (양쪽 공통, 영어)

> lazymemo is a notes app that stores every note as a Markdown file in the user's own iCloud Drive container ("LazyMemo" folder). There is no account, no sign-in, and no server of ours — the app works fully offline and nothing is sent to the developer.
>
> Location is requested only when the user taps the pin ("here") in the composer; it reads one fix, attaches the address to that note, and stops. It is never requested at launch and never in the background.
>
> Notification permission is requested only when the user turns on "Notifications on this device" (iPhone: More › Reminders; Mac: Settings › Notifications…). It is off by default and never asked at launch. Reminders are local notifications built on the device — nothing is sent anywhere.
>
> **On-device assistant (both platforms, TestFlight preview):** "Ask my memos" answers questions from the user's own notes and can change a note (reminder time, date, folder) only after showing the change and getting a tap. It runs a small open model (Gemma 4 E2B, about 2.6 GB) entirely on the device. The model file is downloaded from Hugging Face only when the user presses "Download"; no note content is ever sent anywhere. The model can be deleted in the same screen.
>
> No demo account is needed. To try it: type a line such as "내일 오후 3시 치과" (or "tomorrow 3pm dentist") and the app reads the date into the calendar.
>
> **macOS:** the app lives in the menu bar and on the desktop — notes are small windows that stay behind other apps' windows. There is no Dock icon and no main window; press ⌥⌘N anywhere to open the composer, or use the menu bar icon (Settings › Show welcome guide shows the tour again). Calendar access is requested only when the calendar window is first opened. The app is sandboxed; the default notes folder is the iCloud container (or the app container when iCloud is off), and "Move notes folder…" uses a standard open panel with a security-scoped bookmark.

## 아이폰

### 부제

앱 공통 (위 표).

### 홍보 문구 (170자 — 심사 없이 언제든 바꿀 수 있는 자리)

`가입도 계정도 없습니다. 메모는 내 iCloud Drive 의 파일이고, 지워도 남습니다.`

### 키워드 (100자)

`메모,노트,할일,체크리스트,캘린더,일정,마크다운,iCloud,오프라인,빠른메모,공유,장소,메모장,간단`

### 설명

```
lazymemo 는 「사용자는 게으르다」를 전제로 만든 메모입니다.

켜면 바로 키보드입니다. 한 줄을 적고 「남기기」를 누르면 끝 — 저장 버튼도, 제목도, 폴더 고르기도 없습니다.

「내일 오후 3시 치과」라고 적으면 날짜는 앱이 읽어 달력에 놓습니다. 다시 적을 필요가 없습니다.

• 펜 — 적기와 찾기가 한 자리. 첫소리(ㅈㅂㄱ → 장보기)로도 찾습니다.
• 무더기 — 최근순 한 목록. 밀어서 지우고, 바로 되돌립니다.
• 달력 — 달 격자와 그 날의 일정. 미루기·종이로·지우기.
• 편집 — 글자가 바뀌면 그대로 파일로. 저장 버튼이 없습니다.
• 공유 시트 「lazymemo 에 적기」 — 사파리·지도·다른 앱에서 고른 글이 메모 한 장이 됩니다. 네이버 지도·카카오맵·구글 지도·애플 지도의 공유는 장소로 읽습니다.
• 핀 — 누를 때만 지금 자리를 한 번 재어 붙입니다. 첫 실행에 위치를 묻지 않습니다.
• 다시 보기 — 종을 눌러 다시 볼 시각만 정합니다. 일정은 그대로. 목록 위 「지금」에 오늘 볼 것 세 장이 서고, 원하면 이 기기에서만 알림을 받습니다 (기본 꺼짐).
• 휴지통 — 지운 메모는 30일 동안 되돌릴 수 있습니다.
• Siri·단축어·액션 버튼 — 「lazymemo 에 적기」라고 말하면 앱을 열지 않고 메모가 됩니다. 「오늘 뭐 있어」는 「지금」을 읽어 줍니다.
• 위젯 — 홈 화면·잠금 화면의 「지금」·「다음 약속」·「달력」·「적기」. 「봤어요」와 체크리스트의 칸은 위젯에서 바로 눌립니다.

메모는 내 iCloud Drive 의 「LazyMemo」 폴더에 마크다운 파일로 남습니다. 파일 앱에서 그대로 열립니다. 계정도 서버도 없고, 개발자에게 오는 데이터도 없습니다. 앱을 지워도 메모는 남습니다.

Mac 판(lazymemo for Mac)이 있으면 같은 폴더를 봅니다 — 폰에서 적은 것이 Mac 바탕화면에 종이로 서고, Mac 에서 고친 것이 폰에 그대로 옵니다. iCloud 가 꺼져 있으면 폰 안에만 적고, 화면 바닥에 그렇게 적어 둡니다.

iOS 26 이상. 한국어·영어.
```

### 스크린샷 — 6.9″ 5장 (`dist/store/ios/`, 1320×2868)

| 순서 | 파일 | 자막(넣는다면) |
|---|---|---|
| 1 | pen.png | 켜면 바로 키보드 |
| 2 | datesheet.png | 날짜는 앱이 읽는다 |
| 3 | list.png | 최근순 한 목록 |
| 4 | calendar.png | 그 날의 일정 |
| 5 | editor.png | 저장 버튼이 없다 |

이번 판(`ios` 0.1.0)의 새로운 기능: `첫 판.`

> 2026-09-15: 설명에 「다시 보기」 한 줄과 심사 메모의 알림 문단을 더했다 — ASC 의 두 버전 페이지에도 같은 글을 옮겨 적어야 한다 (설명·심사 메모는 심사 전에 고칠 수 있다).

## 맥

### 부제

앱 공통 부제 하나뿐이라 따로 없다 (위 표). 맥만의 한 줄이 필요해지면 `바탕화면에 붙어 있는 메모와 달력`.

### 홍보 문구 (170자)

`앱을 「열어서」 쓰지 않습니다. 메모는 늘 바탕화면에 떠 있고, 단축키 한 번으로 새 메모가 시작됩니다.`

(ASC 가 홍보 문구의 `⌥⌘` 기호를 「유효하지 않은 문자」로 거절했다. 설명 본문의 기호는 통과한다.)

### 키워드 (100자)

`메모,스티키,바탕화면,포스트잇,할일,체크리스트,캘린더,일정,마크다운,iCloud,메뉴바,단축키,오프라인,메모장`

### 설명

```
lazymemo 는 macOS 바탕화면에 상주하는 메모 + 달력입니다. 「사용자는 게으르다」를 전제로 만들었습니다.

앱을 「열어서」 쓰지 않습니다. 메모는 늘 바탕화면에 떠 있고, 새 메모는 어느 앱에서든 ⌥⌘N 한 번으로 시작되며, 저장 버튼이 없습니다. 「내일 오후 3시 치과」라고 적으면 날짜는 앱이 읽어 달력에 놓습니다.

• 종이 — 메모 한 장이 창 하나. 다른 앱의 창 뒤, 바탕화면 위에 눕습니다. 색을 고르고, 끌어 옮기고, 체크 목록·사진·링크 카드가 그대로 붙습니다.
• 빠른 입력 — ⌥⌘N. 한 줄 적고 ⌘↩. 날짜를 읽으면 「달력에 남기기」로 바뀝니다. 첫소리(ㅈㅂㄱ)로 찾기도 여기서.
• 서랍 — 지금 필요 없는 종이는 서랍에 밀어 둡니다. 폴더로 나누고, 찾고, 도로 꺼냅니다.
• 달력 — 달 격자와 그 날의 일정. 종이를 날짜에 놓고, 미루고, 그 날이 오면 바탕화면에 다시 섭니다.
• 「지금 여기」 — ⌥⌘L 을 누를 때만 자리를 한 번 재어 붙입니다.
• 다시 보기 — 종이를 우클릭해 다시 볼 시각을 정하면 그때 종이가 앞으로 나옵니다. 일정은 그대로. 원하면 이 기기에서만 알림을 받습니다 (기본 꺼짐).
• 서비스 메뉴·공유 — 어느 앱에서든 고른 글이 메모가 됩니다.
• 휴지통 — 지운 메모는 30일 동안 되돌릴 수 있습니다.

메모는 마크다운 파일입니다. 기본 자리는 iCloud Drive 의 「LazyMemo」 폴더(아이폰 앱과 같은 자리)이고, 원하는 폴더로 옮길 수 있습니다. Finder 로 열어도 되고, 다른 편집기로 고쳐도 화면이 따라옵니다. 계정도 서버도 없고, 개발자에게 오는 데이터도 없습니다. 앱을 지워도 메모는 남습니다.

아이폰 판이 있으면 같은 폴더를 봅니다 — 폰에서 던진 한 줄이 Mac 바탕화면에 종이로 섭니다.

macOS 26 이상. 한국어·영어. 메뉴 막대 앱이라 Dock 에 아이콘이 없습니다 — 메뉴 막대의 lazymemo 아이콘이 입구입니다.
```

### 스크린샷 — 5장 (`dist/store/mac/`, 2880×1800)

| 순서 | 파일 | 자막(넣는다면) |
|---|---|---|
| 1 | capture.png | ⌥⌘N — 한 줄 적으면 날짜는 앱이 읽는다 |
| 2 | desk.png | 바탕화면의 종이와 달력 |
| 3 | drawer.png | 지금 필요 없는 종이는 서랍에 |
| 4 | folder.png | 폴더로 나눈다 |
| 5 | desk-dark.png | 어두운 모양 |

이번 판(`macOS` 0.4.0)의 새로운 기능: `App Store 첫 판. GitHub 판과 같은 앱이되 샌드박스 안이라 Claude 연동과 자체 업데이트가 없고, 메모 폴더의 기본 자리가 iCloud Drive 의 「LazyMemo」다.`

## 영어 (English (U.S.) 로컬라이제이션 — 있으면 좋고, 첫 제출에 필수는 아니다)

- 이름 `lazymemo` · 부제(iPhone) `One line, dates read for you` (28) · 부제(Mac) `Notes living on your desktop` (28)
- 키워드 `notes,memo,todo,checklist,calendar,markdown,icloud,offline,quick note,sticky,desktop,menu bar`
- 설명은 위 한국어를 그대로 옮긴다 — `site/index.html` 의 영어 문장을 재료로.

## 절차 (ASC) — 2026-09-14 에 1~5 를 마쳤다 (Apple ID 6811815255)

1. ~~나의 앱 → ＋ → 새로운 앱~~ ✅ iOS·macOS, 한국어, `io.github.bunhine0452.lazymemo`, SKU `lazymemo`.
2. ~~앱 정보~~ ✅ 부제·카테고리 생산성·연령 등급 4+ (설문 전부 없음).
3. ~~가격 및 사용 가능 여부~~ ✅ $0.00 · 175개 국가.
4. ~~앱 개인정보~~ ✅ 처리방침 URL + 「데이터가 수집되지 않음」 게시.
5. ~~각 플랫폼 버전 페이지~~ ✅ 스크린샷(iPhone 6.9″ 5장 · Mac 5장)·홍보 문구·설명·키워드·URL·저작권·심사 메모·연락처(전화는 사용자가 직접 넣었다)·로그인 불필요. 저작권 칸은 버전 페이지에 있다.
6. **남은 것** — `archive.sh` / `archive.sh mac` 이 올린 빌드를 버전 페이지의 「빌드」에서 고르고, TestFlight 내부 테스터로 설치해 본 뒤 「심사에 추가」. 아카이브는 Xcode › Settings › Accounts 에 로그인돼 있어야 돈다.
7. 스크린샷 순서는 미디어 관리에서 끌어 바꾸는데 맥 쪽은 끌기가 안 먹었다 — 한 장씩 차례로 올리면 올린 순서가 곧 순서다.
