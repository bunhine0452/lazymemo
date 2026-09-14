---
schema_version: 1
type: feature
slug: "recall-polish-and-intro-videos"
status: done
difficulty: high
created_at: "2026-09-15T03:00:12+09:00"
session_id: "20260915-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "a21353b2-7510-4482-806f-384b70daace4"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Agenda/Recall.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/Memo.swift"
    op: update
  - path: "Sources/LazyMemoCore/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoReminders/RecallViews.swift"
    op: update
  - path: "Sources/LazyMemoReminders/RecallWindow.swift"
    op: update
  - path: "Sources/LazyMemoReminders/Resources/en.lproj/Localizable.strings"
    op: update
  - path: "Sources/LazyMemoUI/Demo/DemoTour.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/RecallTests.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MemoTitleTests.swift"
    op: create
  - path: "ios/LazyMemo/NowBand.swift"
    op: update
  - path: "ios/LazyMemo/StackView.swift"
    op: update
  - path: "ios/LazyMemo/MemoRowView.swift"
    op: update
  - path: "ios/LazyMemo/en.lproj/Localizable.strings"
    op: update
  - path: "ios/LazyMemoUITests/SmokeTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/DemoTests.swift"
    op: create
  - path: "ios/scripts/record-demo.sh"
    op: create
  - path: "scripts/record-demo.sh"
    op: update
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "site/media/demo.mp4"
    op: update
  - path: "site/media/phone.mp4"
    op: create
  - path: "README.md"
    op: update
  - path: "docs/MOBILE_DESIGN.md"
    op: update
related:
  - ref: "20260915/Features_to_add/0108_feature_recall-notifications-first-release.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0137_feature_demo-tour-recording.md"
    kind: "followup"
tags:
  - "recall"
  - "ios"
  - "mac"
  - "demo"
  - "video"
  - "site"
  - "mcp-tool"
---
[x] 다시 보기 다듬기 — 다가오는 것 먼저·「봤어요」·「나머지」·사진 줄·접힌 안내, 그리고 맥·폰 소개 영상

리뷰 지적 2~4번과 다시 보기 화면의 설명 과다, 그리고 「새 소개 영상 (iOS·맥)」.

## 추가 기능
- **「지금」 차례** (`Recall.nowCards`): 이유별이 아니라 **시각이 정한다** — 다가오는 것(가까운 순) → 지나간 것(방금 지난 순) → 시각 없는 것(오늘 날짜만 → 고정, 최근 손댄 순). 아침에 지난 셋이 오후에 곧 올 하나를 밀어내지 않는다. `Card.stamp`(시각, 없으면 오늘 시작)가 등장의 이름표.
- **「봤어요」**: 카드 위 캡슐 단추 + 길게 눌러 메뉴. `seen: [ULID: Date]` 를 `nowCards` 에 넘기면 이름표가 같은 동안만 빠진다 — 미루거나 날이 바뀌면 다시 오른다. 폰은 `NowSeen`(UserDefaults, 기기별, 어제 것은 저장 때 버림)에 둔다. 파일에 적지 않는다 — 폰에서 봤다고 맥 종이가 물러날 이유가 없다.
- **중복 제거**: 띠에 오른 메모는 아래 목록에서 빠지고 「나머지 N장」 머리가 선다. 카드도 줄이 하는 일을 다 한다(고정·지우기 쓸어 넘기기, 메뉴). `NowBand` 는 이제 List 안에 제 줄들을 직접 낸다. 전부 띠에 올라 목록이 비어도 빈 화면 안내는 안 선다.
- **사진 줄** (`Memo.title`/`previewLine`/`photoCount`): 사진 참조는 글이 아니다. 사진만 붙인 메모의 제목은 경로가 아니라 「사진 1장」, 둘째 줄은 사진을 건너뛰고, 줄 끝에 `photo` 아이콘으로 「사진 N장」. Core 에 두어 맥의 창 제목·알림 제목도 같이 낫는다.
- **접힌 안내** (`ReminderSettingsView.folded`): 켜져 있고 탈이 없으면 잠금 화면·기기별·집중 모드 문단이 「기기별 알림 안내」 DisclosureGroup 뒤로 접힌다. 켜기 전엔 그대로 다 보인다 — 켜기 전에 읽는다는 원칙은 지킨다.
- **맥 영상** (`DemoTour`): 「우산」 뒤에 다시 보기 장면 — 달력이 맡은 치과 메모의 `surface` 를 23초 뒤로 적고 `RecallWindow` 를 무대 안(`RecallWindow.demo`)에 2.8초 띄운 뒤, 서랍 장면을 다 돌고 닫으면 `DueClock` 이 그 종이를 바탕화면으로 꺼낸다. 번들(`build-app.sh`)로 돌려 알림 절이 「켤 수 있는」 모양이다. 36.7초.
- **폰 영상** (`DemoTests` + `ios/scripts/record-demo.sh`): `simctl io recordVideo` 로 담고, 시험이 `push` 파일에 메모 id 를 적으면 스크립트가 `simctl push` 로 배너를 넣는다(시험은 시뮬레이터 밖 명령을 못 부른다). 적기 → 달력에 남기기 → 종 → 한 시간 뒤 → 「지금」 맨 위 → 알림 켜기(권한 창 허용) → 배너 → 누르면 그 메모. `ready`/`done` 시각으로 앞뒤를 자른다. 45초, 590×1282.
- 사이트(ko·en)에 맥 영상 단계 4개를 다시 적고 「같은 메모를, 폰에서도」 절과 폰 영상을 더했다. README·MOBILE_DESIGN §4 갱신.

## 동작 흐름
폰: 목록이 `Recall.nowCards(store.memos, now:, seen:)` → 띠 카드 → 「봤어요」 → `seen[id] = stamp` → `NowSeen.save` → 카드가 빠지고 아래 「나머지」로 돌아간다. 분이 바뀌거나 앞으로 오면 시계가 다시 재고, 자정이 지나면 이름표가 달라 다시 오른다.

## 검증
- 패키지 시험 775개 통과(`RecallTests` 2개·`MemoTitleTests` 4개 추가), `check-l10n.sh` 패키지 넷 빠짐 0.
- XCUITest: `testSeenPutsTheCardDownIntoTheRest`(새로), `testPhotoFromMacShowsOnThePaper`(경로 없음·「사진 1장」), `testRevisitWritesSurfaceAndNowBandShowsPinned`, `testTypingFiltersTheStack` 통과.
- 두 영상은 ffmpeg 접촉 인쇄로 눈으로 확인 — 다시 보기 창이 무대 안에 서고, 끝에 치과 종이가 올라오며, 폰은 배너를 누르면 그 메모가 열린다.

## 메모
- 헛돈 것 둘: (1) `screencapture -V` 는 Bash 샌드박스 안에서 파일도 안 만들고 멈춘다 → 샌드박스 끄고 돌려야 한다. (2) 화면이 잠겨 있으면 잠금 화면이 찍혀 `site/media/demo.*` 를 덮어썼다 → `git checkout` 으로 되살리고 스크립트에 잠금 가드를 넣었다.
- `RecallWindow` 의 크기는 SwiftUI 가 화면에 올린 다음 턴에야 정해진다 — 그 전 frame 으로 자리를 잡으면 위가 잘린다. 두 턴 뒤에 자리 잡고 그때까지 alpha 0.
- 배너는 springboard 에서 `.otherElements` 로는 안 잡히고 `.any` + `NotificationShortLookView` 로만 잡힌다.
- 커밋하지 않았다 — 요청이 없었다. 폰 영상은 45초로 계획서의 20초보다 길다.