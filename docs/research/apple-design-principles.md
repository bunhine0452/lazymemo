# 애플의 디자인 원칙 — 원문 노트

> 2026-09-13 · `docs/MOBILE_DESIGN.md` 재설계의 근거. 전부 developer.apple.com 원문(HIG 는 `tutorials/data/design/human-interface-guidelines/*.json` 데이터 엔드포인트, WWDC 는 세션 페이지 트랜스크립트)과 support.apple.com 에서 읽었다. 요약 블로그는 쓰지 않았다. **못 찾은 것은 못 찾았다고 적었다.**
>
> 형식: 원칙 → 출처 → 원문 한 줄 → **폰의 lazymemo 에 뜻하는 바** 한 줄.

## 0. 큰 틀 — 세 층위의 애플

애플이 말하는 디자인 원칙은 세 층으로 쌓여 있다.

1. **오래된 원칙** — iOS 7 이후 HIG 의 「Clarity·Deference·Depth」와 여섯 원칙(Aesthetic Integrity·Consistency·Direct Manipulation·Feedback·Metaphors·User Control). 지금 HIG 에는 그 페이지가 없다 (§1 참고).
2. **지금의 HIG** — 원칙을 페이지마다 「Best practices」 문장으로 풀어 둔 것. 이 노트의 대부분.
3. **iOS 26 의 새 디자인 시스템** — Liquid Glass. 「내비게이션 층은 유리, 콘텐츠 층은 유리가 아니다」가 핵심이고, 탭바·툴바·시트·검색의 자리가 바뀌었다.

lazymemo 의 다섯 문장(DESIGN.md §14)은 1 과 거의 같은 말이다. 「앱은 자기를 드러내지 않는다」= Deference, 「재질은 종이 하나」= Aesthetic Integrity + 콘텐츠 층. 충돌하는 자리는 §14 에 모았다.

## 1. 오래된 원칙 (iOS 7 ~ 2022 HIG)

**출처 문제.** `developer.apple.com/design/human-interface-guidelines/ios/overview/themes/` 는 2023년 HIG 개편으로 사라졌고, 이 환경에서는 web.archive.org 에 닿지 못했다. 아래 세 문장은 검색 결과 발췌에 남은 원문이고(넷구루 요약 페이지가 인용한 애플 문장 — 내 기억의 원문과 글자까지 같다), 여섯 원칙의 원문은 **찾지 못했다** — 이름만 적고 뜻은 지금 HIG 의 대응 페이지로 잇는다.

| 원칙 | 원문 | 폰에 뜻하는 바 |
|---|---|---|
| **Clarity** | "Throughout the system, text is legible at every size, icons are precise and lucid, adornments are subtle and appropriate, and a sharpened focus on functionality motivates the design." | 장식은 옅게, 글자는 어느 크기에서도 읽히게 — Dynamic Type, 대비 4.5:1 |
| **Deference** | "Fluid motion and a crisp, beautiful interface help people understand and interact with content while never competing with it. Minimal use of bezels, gradients, and drop shadows keep the interface light and airy, while ensuring that content is paramount." | 「앱은 자기를 드러내지 않는다」와 같은 말. 펜·바는 종이(메모)와 겨루지 않는다 |
| **Depth** | "Distinct visual layers and realistic motion convey hierarchy, impart vitality, and facilitate understanding." | 층이 곧 위계다 — iOS 26 에서 이것이 「유리 층 / 콘텐츠 층」이 됐다 (§3) |
| Aesthetic Integrity | (원문 못 찾음) 「생김새와 행동이 기능과 얼마나 잘 맞는가」 | 메모 앱의 종이 재질은 정당하다 — 기능(적고 읽기)과 맞는다 |
| Consistency | → WWDC17 802 (§2) | 시스템 부품·손짓을 쓴다. 우리만의 손짓을 만들지 않는다 |
| Direct Manipulation | → HIG Gestures, WWDC18 803 (§2) | 끌어 옮기기, 밀어 지우기 — 내용에 손을 댄다 |
| Feedback | → HIG Feedback (§4) | 적으면 적혔다는 것이, 지우면 지워졌다는 것이 보인다 |
| Metaphors | (원문 못 찾음) | 「종이」·「펜」·「무더기」는 은유다. 은유가 시스템 관용구와 부딪히면 관용구가 이긴다 |
| User Control | → HIG Undo (§4) | 앱이 대신 읽은 날짜를 사람이 끌 수 있어야 한다 |

## 2. WWDC 가 말한 원칙

### Essential Design Principles — WWDC17 802
https://developer.apple.com/videos/play/wwdc2017/802/

| 원칙 | 원문 | 폰에 뜻하는 바 |
|---|---|---|
| Wayfinding | "Wayfinding systems help people to navigate complex environments quickly and successfully." | 「내가 어디 있나」 — 큰 제목, 탭 둘 |
| Feedback | "Feedback helps us to operate cars confidently and safely." | 남기면 줄이 보이고, 지우면 줄이 사라진다 |
| Visibility | "The usability of a design is greatly improved when controls and information are clearly visible." | 숨긴 조작(길게 누름)만 있는 기능은 없다 — 전부 보이는 길이 하나는 있다 |
| Consistency | "The principle of consistency is about representing similar design features in similar ways." | 목록은 위에서 아래로, 새것이 위에 — 다른 모든 목록 앱과 같이 |
| Mental Model | "…that model represents the faucet as a system of parts and functions and behaviors." | 사람의 「메모 목록」 모델은 Notes 다. 그 모델을 거스르면 배워야 한다 |
| Proximity | "Proximity is about the distance between a control and the object that it affects." | 편집의 꼬리(날짜·색)는 종이 옆에, 펜의 칩은 펜 옆에 |
| Grouping | "Grouping helps people to understand the relationships between elements…" | 툴바 항목을 기능·빈도로 묶는다 (§3 의 356 과 같다) |
| Mapping | "Mapping is about designing controls to resemble the objects that they affect." | 달력의 「미루기」는 오른쪽(앞으로)으로 민다 |
| Affordances | "Our notions about how we interact with this plate are called affordances." | 칩이 눌리는 것이면 눌리게 생겨야 한다 |
| Progressive Disclosure | "Progressive disclosure gradually eases people from the simple to the more complex." | 펜은 한 줄, 필요할 때 다섯 줄. 폴더는 있을 때만 |
| 80/20 | "80 percent of a system's effects come from 20 percent of its causes." | 적기·미루기·지우기가 20% 다. 나머지는 한 겹 아래 |

### The Qualities of Great Design — WWDC18 801
https://developer.apple.com/videos/play/wwdc2018/801/
- "It's simple. It doesn't try to do more than it needs to do. And what it does, it does it really well." → 폰은 적기·읽기·미루기만 잘하면 된다.
- "You're not aware of an interface which has been well designed." → 「앱은 자기를 드러내지 않는다」.

### Designing Fluid Interfaces — WWDC18 803
https://developer.apple.com/videos/play/wwdc2018/803/
- "If you introduce any amount of lag, things all of a sudden just kind of fall off a cliff in terms of how they respond to you." → 파서·검색은 타자 사이에 묻혀야 한다 (Core 의 150ms 예산과 같은 말).
- "Touch and content should stay together and move as one thing." → 옮기기는 **끌기**다. 「들고 기다리기」 같은 모드가 아니다.
- "By keeping the discrete animation and the gesture aligned, we can use one to teach the other." → 밀어 지우기의 애니메이션이 곧 안내다.
- "Allow for constant redirection and interruption…" → 끌다 놓으면 그만둔다. 되돌릴 수 없는 모드를 만들지 않는다.

### Design foundations from idea to interface — WWDC25 359
https://developer.apple.com/videos/play/wwdc2025/359/
- 구조의 세 질문: "Where am I?" / "What can I do?" / "Where can I go from here?"
- "each extra tab means one more decision for people to make" → 탭 둘.
- "tabs are for navigation, not for taking action" → 검색 탭이 메모를 만들면 안 된다.
- 툴바 = 화면 제목 + 화면 고유 동작 + 「내가 어디 있나」의 단서.
- "Replace grids with lists for better scannability" · 시스템 텍스트 스타일 · 시맨틱 컬러 · "visual anchors for most important content".

## 3. iOS 26 — Liquid Glass 와 새 구조

### Materials (HIG)
https://developer.apple.com/design/human-interface-guidelines/materials
- "Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer…"
- **"Don't use Liquid Glass in the content layer."** "…use standard materials for elements in the content layer, such as app backgrounds."
- "Use Liquid Glass effects sparingly. … Limit these effects to the most important functional elements in your app."
- "The regular variant blurs and adjusts the luminosity of background content to maintain legibility… Most system components use this variant."
→ **종이는 콘텐츠 층, 펜·탭바·툴바·시트는 유리 층.** 첫 판이 「적는 면은 종이여야 한다」며 펜을 종이로 칠한 것은 이 층 원칙에 어긋난다 — 펜은 조작(입력)이지 콘텐츠가 아니다.

### Meet Liquid Glass — WWDC25 219
https://developer.apple.com/videos/play/wwdc2025/219/
- "You may be tempted to use Liquid Glass everywhere but it is best reserved for the navigation layer that floats above the content of your app."
- "Consider this tableview: making it Liquid Glass would make it compete with other elements and muddy the hierarchy. So keep it in the content layer instead to ensure clarity."
- "Scroll edge effects work in concert with Liquid Glass to maintain that crucial separation between the UI and content layers and ensure legibility…"
- "Always avoid glass on glass."
- "Tinting should only be used to bring emphasis to primary elements and actions in the UI." / "Avoid tinting all your elements."
- 접근성: "Reduced Transparency, makes Liquid Glass frostier… Increased contrast, makes elements predominantly black or white… Reduced Motion decreases the intensity of some effects…"
→ 첫 판의 뒤집힌 목록은 scroll edge effect 를 **꺼야만** 보였다. 유리 층의 가독성 장치를 끄는 구현은 그 자체로 원칙 위반의 증거다.

### Get to know the new design system — WWDC25 356
https://developer.apple.com/videos/play/wwdc2025/356/
- "Liquid Glass defines a new functional layer in the UI, floating above your content to bring structure and clarity, without ever stealing focus."
- 탭바 액세서리: "Tab bars can also support persistent features using accessory views, like media playback controls that stay visible across your app. Avoid placing screen-specific actions here—a checkout button, for example, belongs with the content it supports."
- 검색: "When content isn't visible upfront, Search becomes essential. That's why iOS now includes a dedicated Search tab at the bottom…"
- 툴바: "Group bar items by function and frequency." / "If your bar is feeling too crowded, use it as a cue to remove anything unnecessary and move secondary actions into a more menu…" / "Instead of relying on decoration, hierarchy should be expressed through layout and grouping."
- scroll edge: "…replacing hard dividers with subtle blur to reduce clutter and keep UI legible." / "scroll edge effects are not decorative… shouldn't be used where there aren't any floating UI elements." / "Soft is the default… Hard is mostly used on macOS."
- 동심원: "By aligning radii and margins around a shared center, shapes can comfortably nest within each other." 세 종류 — fixed · capsule · concentric.
- 글자: "Typography has been refined… now bolder and left-aligned…"
→ 펜은 두 탭에 걸쳐 남는 「persistent feature」라 액세서리 자리가 맞다. 화면 고유 동작(휴지통·치워 둔 것)은 그 화면의 툴바에.

### Build a SwiftUI app with the new design — WWDC25 323
https://developer.apple.com/videos/play/wwdc2025/323/
- `tabViewBottomAccessory` + `tabBarMinimizeBehavior(.onScrollDown)`; 액세서리는 `tabViewBottomAccessoryPlacement` 가 `.inline` 일 때 compact 레이아웃을 따로 그린다.
- "Search in the toolbar places the field at the bottom of the screen, within easy reach."
- `ToolbarSpacer(.fixed)` 로 관련 동작을 묶고, `.flexible` 로 벌린다.
- "For denser UIs with a lot of floating elements, like in the calendar app, tune the sharpness of the effect… `scrollEdgeEffectStyle`."
- 시트: "On iOS 26, partial height sheets are inset by default with a Liquid Glass background… If you've used the `presentationBackground` modifier… consider removing that and let the new material shine."
- `glassEffect`: "For especially important views, use a tint modifier… only use this to convey meaning and not just for visual effect."
- **액세서리 안의 텍스트 입력 예시는 없다** — 트랜스크립트에 재생 컨트롤뿐. 액세서리가 키보드 위로 오르는지는 **애플 문서에서 확인하지 못했다.**

## 4. HIG — 패턴

### Designing for iOS
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- "Help people concentrate on primary tasks and content by limiting the number of onscreen controls while making secondary details and actions discoverable with minimal interaction."
- "…it tends to be easier and more comfortable for people to reach a control when it's located in the middle or bottom area of the display, so it's especially important let people swipe to navigate back or initiate actions in a list row."
→ 조작은 바닥에(펜), 줄의 동작은 밀기로. **단, 이것은 조작의 자리이지 내용의 차례가 아니다.**

### Layout
https://developer.apple.com/design/human-interface-guidelines/layout
- **"Order content by relative importance. Place the most important items near the top and leading side of the window or display."**
- "Differentiate controls from content. Take advantage of the Liquid Glass material to provide a distinct appearance for controls. Instead of applying solid or semi-opaque backgrounds, use a scroll edge effect to visually elevate controls above content."
→ 가장 중요한 내용(최근·고정)은 **위**에. 조작은 유리로 가른다 — 불투명 띠(첫 판의 종이색 펜 줄·로컬 띠)가 아니라.

### Entering data
https://developer.apple.com/design/human-interface-guidelines/entering-data
- "Get information from the system whenever possible."
- "Be clear about the data you need."
- "When possible, offer choices instead of requiring text entry."
- "Dynamically validate field values… provide feedback as soon as you detect a problem — you give them the opportunity to correct errors right away."
→ 펜의 안내 문구는 무엇을 받는지 말한다. 앱이 읽어 낸 날짜는 **치는 동안** 칩으로 보이고, 그 자리에서 고칠 수 있다.

### Searching
https://developer.apple.com/design/human-interface-guidelines/searching
- "If search is important, give it a primary position in your app or view. For example, in the Notes app, a search field is in the bottom toolbar… In apps that use tab bars, like Photos and Apple TV, search is a dedicated tab."
- "Aim to make your app's content searchable through a single location."
- "Clearly display the current scope of a search."
→ 찾는 자리는 하나, 바닥. 검색 탭은 「찾기」만 하는 탭이라 **적기를 겸하는 펜과는 다른 것** — 359 의 「탭은 동작이 아니다」와 함께 검색 탭을 뺀 근거.

### Undo and redo
https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- "Help people predict the results of undo and redo as much as possible. On iPhone, for example, you can describe the result in the alert that displays when people shake the device…"
- "Show the results of an undo or redo… you might scroll the document to show the restored paragraph."
- **"Provide undo and redo buttons only when necessary. People generally expect to initiate undo and redo in system-supported ways, such as… shaking their iPhone. If it's important to provide dedicated undo and redo buttons in your app, use the standard system-provided symbols and put the buttons in a toolbar."**
- "Avoid redefining standard gestures for undo and redo. For example, people can use a three-finger swipe… or shake their iPhone."
- "Briefly and precisely describe the operation to be undone… 'Undo Name'…"
→ 첫 판의 「되돌리기 띠」(8초 토스트)는 시스템 관용구가 아니다. 시스템 되돌리기(흔들기·세 손가락)에 동작 이름을 달고, 되돌린 결과를 **보여 준다**(스크롤·강조).

### Feedback
https://developer.apple.com/design/human-interface-guidelines/feedback
- "Consider integrating status feedback into your interface… For example, Mail in iOS and iPadOS describes the most recent update and displays the number of unread messages in the toolbar of the mailbox screen, making the information unobtrusive but easy for people to check…"
- "When it makes sense, confirm that a significant action or task has completed… reserve this type of confirmation for activities that are sufficiently important."
- "Show people when a command can't be carried out and help them understand why."
→ 「iCloud 와 함께 봅니다 / 이 기기에만」은 Mail 의 「Updated Just Now」처럼 **제목 밑 한 줄**이 자리다. 남길 때마다 확인 알림은 없다 — 줄이 보이는 것으로 족하다.

### Modality · Sheets
https://developer.apple.com/design/human-interface-guidelines/modality · https://developer.apple.com/design/human-interface-guidelines/sheets
- "Present content modally only when there's a clear benefit."
- "Always give people an obvious way to dismiss a modal view… in iOS… a button in the top toolbar or swipe down."
- 시트: "Provide an alternative to the Done button. Always pair a Done button with a Cancel button or Back button…" / "Support the medium detent for progressive disclosure" / "Include a grabber in resizable sheets." / "Use a nonmodal view when you want to present supplementary items that affect the main task in the parent view."
→ 날짜 시트는 medium detent + 그래버, 즉시 반영(비모달 성격). 「날짜 떼기」는 Cancel 자리에 두지 않는다 — Cancel 은 「바꾼 것을 버린다」는 뜻이다.

### Onboarding
https://developer.apple.com/design/human-interface-guidelines/onboarding
- "Teach through interactivity." / "Consider providing a collection of context-specific tips instead of a single onboarding flow."
→ 첫 실행 안내 없음. 빈 상태 한 줄과 안내 문구가 가르친다.

### Privacy
https://developer.apple.com/design/human-interface-guidelines/privacy
- "Request permission only when your app clearly needs access… wait to request permission until people actually use an app feature that requires access."
- "Consider using the location button to give people a lightweight way to share their location for specific app features… Attach their location to a message or post…" / "If your app has no authorization status: Tapping the location button has the same effect as when a person chooses 'Allow Once'."
- "You cannot customize other visual attributes to help people recognize and trust location buttons."
→ 「지금 여기」는 **시스템 위치 단추**(`LocationButton`)여야 한다 — 한 번 허용, 시스템 생김새 그대로.

### Motion
https://developer.apple.com/design/human-interface-guidelines/motion
- "Add motion purposefully…" / "In apps, generally avoid adding motion to UI interactions that occur frequently."
→ 남기기·지우기의 움직임은 시스템 것으로 족하다. 종이가 「잠깐 앞으로 나오는」 맥의 장면은 폰에 옮기지 않는다.

## 5. HIG — 부품

### Tab bars
https://developer.apple.com/design/human-interface-guidelines/tab-bars
- "Use a tab bar to support navigation, not to provide actions."
- "Make sure the tab bar is visible when people navigate to different sections… The exception is when a modal view covers the tab bar."
- "Don't disable or hide tab bar buttons…"
- iOS: "A tab bar floats above content at the bottom of the screen. Its items rest on a Liquid Glass background…" / "For tab bars with an attached accessory, like the MiniPlayer in Music, you can choose to minimize the tab bar and move the accessory inline with it when a person scrolls down." / "A tab bar can include a dedicated search tab at the trailing end."
- "Avoid applying a similar color to tab labels and content layer backgrounds… prefer a monochromatic appearance for tab bars…"
→ 탭바에 색을 칠하지 않는다(모노크롬). 편집 화면이 탭바를 숨기는 것은 push 라 원칙상 **숨기면 안 된다** — 첫 판의 `toolbar(.hidden, for: .tabBar)` 는 심판 대상.

### Toolbars
https://developer.apple.com/design/human-interface-guidelines/toolbars
- "Add a More menu to contain additional actions. Prioritize less important actions for inclusion in the More menu. Try to include all actions in the toolbar if possible, and only add this menu if you really need it."
- "Reduce the use of toolbar backgrounds and tinted controls… use the content layer to inform the color and appearance of the toolbar, and use a `ScrollEdgeEffectStyle`…"
- "Prefer using standard components in a toolbar. By default, standard buttons, text fields, headers, and footers have corner radii that are concentric with bar corners."
- iOS: "Use a large title to help people stay oriented as they navigate and scroll."
→ 휴지통은 툴바 단추로, 드문 것(치워 둔 N장)만 More 에. 큰 제목 「메모」.

### Lists and tables
https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- "Prefer displaying text in a list or table."
- "Keep item text succinct so row content is comfortable to read."
- "If you need to let people drill into a list or table row's subviews, use a disclosure indicator accessory control." (Notes 의 목록 줄에는 › 가 없다 — 열면 편집이지 계층이 아니다.)

### Text fields · Virtual keyboards
https://developer.apple.com/design/human-interface-guidelines/text-fields · https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards
- "Show a hint in a text field to help communicate its purpose."
- "Display a Clear button in the trailing end of a text field to help people erase their input."
- 키보드 위의 조작: "Apply Liquid Glass — If your view uses Liquid Glass elsewhere… apply it to controls above the keyboard for consistency" / "Use standard toolbar — Automatically adopts Liquid Glass" / "Respect layout guide."
→ 편집의 꼬리는 **표준 툴바**(키보드 위로 따라 오르는 `.keyboard`/`.bottomBar` 배치)여야 한다 — 첫 판의 종이색 커스텀 줄이 아니라.

### Buttons
https://developer.apple.com/design/human-interface-guidelines/buttons
- "use a button that has a prominent visual style for the most likely action in a view."
- "Keep the number of prominent buttons to one or two per view."
- "consider starting the label with a verb…" / "Consider using text when a short label communicates more clearly than an icon."
- "a button needs a hit region of at least 44x44 pt"
→ 「남기기」가 그 화면의 유일한 프로미넌트 단추. 글자 단추가 맞다 — 「달력에 남기기」로 바뀌는 것이 뜻을 나른다.

### Context menus · Edit menus
https://developer.apple.com/design/human-interface-guidelines/context-menus · https://developer.apple.com/design/human-interface-guidelines/edit-menus
- "Always make context menu items available in the main interface, too."
- "In iOS… List potentially destructive actions (Delete, Remove) at the end of the menu and identify them as destructive."
- "Hide unavailable menu items, don't dim them."
- 편집 메뉴: "Prefer the system-provided edit menu." / "Support undo and redo when possible."

### Gestures
https://developer.apple.com/design/human-interface-guidelines/gestures
- "Give people more than one way to interact with your app… Don't assume that people can use a specific gesture…"
- "Avoid using a familiar gesture like tap or swipe to perform an action that's unique to your app; similarly, avoid creating a unique gesture to perform a standard action…"
- "Indicate when a gesture isn't available."
- 표: three-finger swipe = undo/redo · shake = undo/redo.
→ 밀기 동작은 전부 컨텍스트 메뉴와 VoiceOver 동작에도 있어야 한다. 「들고 기다리기」는 우리만의 손짓이다.

## 6. HIG — 기초

### Color
https://developer.apple.com/design/human-interface-guidelines/color
- "Avoid hard-coding system color values…" / "Avoid redefining the semantic meanings of dynamic system colors."
- "By default, Liquid Glass has no inherent color… You can apply color to some Liquid Glass elements… useful for drawing emphasis to a specific control, like a primary call to action…"
- "Apply color sparingly to the Liquid Glass material… reserve it for elements that truly benefit from emphasis, such as status indicators or primary actions. To emphasize primary actions, apply color to the background rather than to symbols or text."
- "…in apps with primarily monochromatic content or backgrounds, choosing your brand color as the app accent color can be an effective way to tailor your app experience…"
- "Even if your app ships in a single appearance mode, provide both light and dark colors to support Liquid Glass adaptivity…"
- "Make sure all your app's colors work well in light, dark, and increased contrast contexts… If you define a custom color, make sure to supply light and dark variants, and an increased contrast option…"
→ 크림 종이는 「monochromatic content」라 포레스트를 accent 로 쓰는 것은 애플이 권하는 경우 그 자체다. 다만 accent 는 **프로미넌트 단추의 바탕**과 상태 표시에만. 커스텀 색(Paper·accentInk·highlightInk)에는 **Increase Contrast 판**이 있어야 한다.

### Typography
https://developer.apple.com/design/human-interface-guidelines/typography
- "Consider using the built-in text styles."
- "Make sure your app's layout adapts to all font sizes."
- "Keep text truncation to a minimum as font size increases."
- "Consider adjusting your layout at large font sizes… consider using a stacked layout where text appears above secondary items."
- iOS 최소 11pt, 기본 17pt. Large Title 34 · Title 2 22 · Body 17 · Subhead 15 · Footnote 13 · Caption 1 12 · Caption 2 11.
→ 줄의 시각 조각은 큰 글자에서 제목 **아래**로 내려간다(쌓기). 11pt 미만 없음.

### Accessibility
https://developer.apple.com/design/human-interface-guidelines/accessibility
- 과녁: iOS 기본 44×44pt, 최소 28×28pt.
- "give people the option to enlarge text by at least 200 percent"
- 대비: 17pt 이하 4.5:1, 18pt 이상 3:1, 볼드 3:1. "Prefer system-defined colors." / "If your app doesn't provide minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on."
- Reduce Motion: "Replacing transitions in x-, y-, and z-axes with fades…"
- "Prefer system gestures and behaviors people are already familiar with over creating custom gestures…"
- "Convey information with more than color alone."
→ **첫 판의 `fadedInk`(잉크 52%)는 미색 위에서 약 3.3:1 — 캡션 글자에 못 쓴다.** 둘째 줄·시각은 시스템 `.secondary` 로. 바램(`MemoAge`)은 제목의 대비를 4.5:1 아래로 내리지 않고, Increase Contrast 에서는 끈다.

## 7. 애플 1st-party 앱 — 같은 문제를 어떻게 푸나

| 앱 | 관찰 | 출처 |
|---|---|---|
| **Notes** | 새 메모는 오른쪽 아래 Compose 단추 → 빈 종이가 열리고 키보드가 오른다. 목록은 위에서 아래로 **최근 수정순**, 고정은 위 구역. 찾기는 바닥 툴바의 검색 필드. 오른쪽으로 밀면 고정, 왼쪽으로 밀면 지우기. 「Recently Deleted」 폴더가 되돌리는 길이고 토스트는 없다. 기존 메모를 열면 키보드가 **안** 오른다 | support.apple.com/en-asia/118442 ("Swipe right over the note… Tap the Pin button" / "Swipe left… Tap the Trash button" / "Tap the Search field"), HIG Searching ("in the Notes app, a search field is in the bottom toolbar"). 키보드·정렬은 관찰 |
| **Reminders** | 「+ New Reminder」가 바닥 툴바 왼쪽. 누르면 목록 **끝**에 빈 줄이 생기고 키보드가 오르며, 키보드 위 quick toolbar 에 날짜·위치·깃발·사진·태그 | support.apple.com/en-us/102484 ("Tap + New Reminder, then type your reminder" · "Tap the Date and Time button…") |
| **Messages** | 입력 줄이 바닥, 새 말풍선이 바닥에, 위로 갈수록 옛것 — **대화**라서다. 말풍선은 고치거나 옮기지 않는다 | 관찰 (문서 못 찾음) |
| **Calendar** | 월 격자 위·그 날 아래, 오늘은 채운 원. 일정 옮기기는 길게 눌러 **끌기**, 또는 편집에서 날짜 | 관찰 |
| **Journal** | 가운데 바닥의 「+」로 새 항목, 제안이 먼저 보이고 「Add to Entry」로 쓰기 시작 | support.apple.com 「Write in your journal on iPhone」 검색 발췌 |
| **Mail** | 제목 밑 「Updated Just Now」·읽지 않은 수 — 상태를 툴바에 통합 | HIG Feedback 원문 |

**읽히는 것.** 애플의 목록 앱은 **하나도 목록을 뒤집지 않는다.** 뒤집는 것은 대화(Messages)뿐이고, 그 이유는 「가장 새것 = 지금 이 순간」이며 말풍선에 손을 대지 않기 때문이다. 메모는 고치고 옮기고 지우는 것이라 Notes/Reminders 의 모델이다. 입력의 자리는 바닥(Reminders 의 새 줄·Notes 의 검색·Messages 의 입력 줄)이고, **바닥에 있는 것은 언제나 유리 위의 조작**이다.

## 8. lazymemo 의 다섯 문장과 부딪히는 자리

| lazymemo (DESIGN.md §14) | 애플 | 판정 |
|---|---|---|
| 앱은 자기를 드러내지 않는다 | Deference · 801 "You're not aware of an interface which has been well designed" | 같은 말. 충돌 없음 |
| 재질은 종이 하나 | Materials — 콘텐츠 층은 표준 재질, 유리는 조작 층 | **양립한다** — 종이는 콘텐츠 층에 산다. 조작(펜·꼬리·바)까지 종이로 칠하면 층이 무너진다 → 조작은 유리 |
| 시간이 유일한 구조 | Layout "most important near the top" · 359 「시간으로 조직」 | 양립. 최근이 위, 옛것이 아래로 가라앉는다 |
| 오래된 것은 스스로 물러난다 (바램) | Accessibility 대비 4.5:1 | **충돌** → 바래되 제목은 4.5:1 아래로 안 내리고, Increase Contrast 면 안 바랜다 |
| 완성을 요구하지 않는다 | Entering data "Be clear about the data you need" | 양립 — 요구하지 않되 무엇을 받는지는 말한다 (안내 문구·칩) |
| 8초 되돌리기 (맥의 D6) | Undo "system-supported ways… shaking" · "buttons only when necessary" | **충돌** → 폰은 시스템 되돌리기 + 휴지통. 띠는 뺀다 |
| 「손이 안 움직인다」는 펜 위로 쌓기 | Layout "top and leading" · Consistency · Notes/Reminders | **충돌** → 조작은 바닥, 내용은 위에서 아래로. 새 줄은 위에 생기고 화면이 그리로 간다 (Undo "scroll… to show the restored paragraph" 의 논리) |

## 9. 못 찾은 것 (지어내지 않았다)

- 옛 HIG 여섯 원칙의 원문 (§1).
- `tabViewBottomAccessory` 안의 텍스트 필드가 키보드 위로 오르는지 — 323 트랜스크립트에는 재생 컨트롤 예시뿐.
- Reminders 가 제목 안의 「tomorrow at 3」을 날짜로 제안하는 기능의 공식 문서 — 102484 는 날짜 단추와 Siri 만 적는다.
- Notes 의 정렬 기본값·기존 메모를 열 때 키보드 동작의 공식 문서 — 관찰로 적었다.

## 10. 맥 — popover·검색 필드·텍스트 필드·피드백·되돌리기·데이터 입력 (2026-09-15 추가)

> 빠른 입력 × 비서 융합(`quick-capture-assistant-2026-09-15.md`)의 근거. HIG 데이터 엔드포인트 원문.

### Popovers — https://developer.apple.com/design/human-interface-guidelines/popovers
- "Use a popover to expose a small amount of information or functionality." / "Because a popover disappears after people interact with it, limit the amount of functionality in the popover to a few related tasks."
- "Make sure a popover's arrow points as directly as possible to the element that revealed it."
- "Use a Close button for confirmation and guidance only." / "Otherwise, a popover generally closes when people click or tap outside its bounds or select an item in the popover."
- **"Always save work when automatically closing a nonmodal popover."**
- "Show one popover at a time." / "Don't show another view over a popover."
- "Avoid making a popover too big." / "Make a popover only big enough to display its contents and point to the place it came from." / "Provide a smooth transition when changing the size of a popover."
- macOS: "You can make a popover detachable in macOS, which becomes a separate panel when people drag it." / "Consider letting people detach a popover."
→ 말풍선은 하나, 그 위에 다른 창을 띄우지 않는다(「메모에게 묻기」 창을 없애는 근거). 되묻기 중 esc 는 초안을 버리지 않고 적는다.

### Search fields — https://developer.apple.com/design/human-interface-guidelines/search-fields
- "Use placeholder text to help people know what they can search for." / "If possible, start search immediately when a person types."
- "Provide the most relevant search results first to minimize the need for someone to scroll…" / "Consider showing suggested search terms."
- "Use a scope bar to filter among clearly defined search categories." / "Default to a broader scope and let people refine it as they need."
- 맥 고유 문장 없음.
→ 치는 동안 랭킹된 목록이 곧 근거 후보. 범위 막대(모드)는 두지 않는다 — 넓은 범위가 기본이고 앱이 가른다.

### Text fields — https://developer.apple.com/design/human-interface-guidelines/text-fields
- "Show a hint in a text field to help communicate its purpose." / "Because placeholder text disappears when people start typing, it can also be useful to include a separate label describing the field…"
- "To the extent possible, match the size of a text field to the quantity of anticipated text." / "Validate fields when it makes sense."
- macOS: "Consider using a combo box if you need to pair text input with a list of choices."
→ 되묻기 때 입력 위에 초안 요약 줄(라벨)을 둔다. 답은 칩(선택지)과 자유 입력 둘 다.

### Feedback — https://developer.apple.com/design/human-interface-guidelines/feedback
- "Consider integrating status feedback into your interface." / "When it makes sense, confirm that a significant action or task has completed." / "Show people when a command can't be carried out and help them understand why." / "Warn people when they initiate a task that can cause data loss that's unexpected and irreversible."
→ 「메모를 읽는 중」은 힌트 줄에, 「모델을 받으면 답합니다」는 한 줄로. 휴지통만 되묻는다.

### Undo and redo — https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- "Help people predict the results of undo and redo as much as possible." / "…modify the menu item labels to identify the result. For example… Undo Typing or Redo Bold."
- "Show the results of an undo or redo." / "Let people undo multiple times." / "Provide undo and redo buttons only when necessary."
- macOS: "Place undo and redo commands in the Edit menu and support the standard keyboard shortcuts." / "…Command–Z and Shift–Command–Z…"
→ 결과 줄은 무엇을 했는지 그대로 적는다(「…에 다시 보여 줍니다 · 되돌리기」). 상자에는 Edit 메뉴가 없어 줄을 두되 ⌘Z 도 받는다.

### Entering data — https://developer.apple.com/design/human-interface-guidelines/entering-data
- "Get information from the system whenever possible." / "Be clear about the data you need." / "When possible, offer choices instead of requiring text entry." / "Dynamically validate field values." / "When data entry is necessary, make sure people understand that they must provide the required data before they can proceed."
→ 날짜·자리는 앱이 읽고 칩으로 보인다. 빠진 시각은 선택 칩으로 준다. 시각을 받기 전에는 ⌘↵ 라벨이 「답하기」다.
