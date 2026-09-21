---
schema_version: 1
type: bug
slug: "app-look-long-memo-top-tables-manifest"
status: done
difficulty: medium
created_at: "2026-09-18T22:07:47+09:00"
session_id: "20260918-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoUI/Windows/NoteWindowController.swift"
    op: update
  - path: "Sources/LazyMemoCore/Model/MarkdownScanner.swift"
    op: update
  - path: "Tests/LazyMemoCoreTests/MarkdownScannerTests.swift"
    op: update
  - path: "ios/LazyMemo/PrivacyInfo.xcprivacy"
    op: create
  - path: "ios/LazyMemoWidgets/PrivacyInfo.xcprivacy"
    op: create
  - path: "ios/LazyMemoShare/PrivacyInfo.xcprivacy"
    op: create
  - path: "ios/LazyMemoMac/PrivacyInfo.xcprivacy"
    op: create
  - path: "ios/LazyMemoUITests/DeepLinkTests.swift"
    op: update
  - path: "ios/LazyMemoUITests/ShotTests.swift"
    op: update
  - path: "scripts/verify-performance.sh"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
related:
  - ref: "20260918/Chores/2025_chore_polish-orchestration-integration.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1920_feature_mac-paper-fits-content.md"
    kind: "followup"
  - ref: "20260918/Features_to_add/1909_feature_web-page-evidence-and-digest-memo.md"
    kind: "followup"
  - ref: "20260918/Chores/2039_chore_release-0-9-0-themes-web-paper-widgets.md"
    kind: "followup"
tags:
  - "mac"
  - "ios"
  - "editor"
  - "store"
  - "mcp-tool"
---
[x] 앱을 직접 띄워 본 뒤 — 긴 메모가 끝부터 열리던 것, 표가 세로선 그대로 서던 것, 스토어 매니페스트 없던 것, 날짜에 썩은 시험 둘

사용자: 「이제 버그들좀 고치고 정식 배포해도될거같아? 네가 앱 봐봐 지금 어떤지」. 맥은 `render-ui.sh`·`render-settings.sh` 로 뷰 45장, 그리고 `.build` 의 앱을 임시 보관함으로 띄워 `screencapture -l <창 id>` 로 종이를 창 단위로 찍었다(바탕화면 레벨이라 전체 화면 캡처엔 안 잡힌다 — 창 id 는 `CGWindowListCopyWindowInfo` 로). 폰은 `uitest.sh --shots` 7장.

## 발생 원인

- **긴 메모가 끝부터 열렸다.** `fitToContent` 가 종이를 늘린 뒤 `scrollRangeToVisible(selectedRange)` 로 커서를 따라갔는데, 파일에서 온 메모는 커서가 글 끝에 서 있어 제목이 아니라 「출처」 줄부터 보였다 (0.9.0 회귀 — 붙여넣기용 규칙이 읽으러 연 종이에도 걸렸다).
- **표가 세로선 그대로.** 비서의 정리 메모(Digest)가 표를 적는데 `MarkdownScanner` 에 표가 없었다.
- **개인정보 매니페스트가 없었다.** UserDefaults·파일 수정 시각·남은 디스크·systemUptime 을 쓰는데 `PrivacyInfo.xcprivacy` 가 어느 타깃에도 없었다 — 심사에서 걸릴 자리.
- **시험 둘이 날짜에 썩었다.** `ShotTests` 는 9월 14·15일을 고정으로 심어 물러난 메모라 「치과 예약」을 못 찾았고, `DeepLinkTests` 는 하드웨어 키보드가 물린 시뮬레이터에서 글자를 치기 전엔 화면 키보드가 없는데도 `keyboards` 가 1 이라 「못 내렸다」로 끝났다. 임시 프로브 시험으로 확인: 키보드는 화면에 없고 탭바는 보인다 — 사용자 문제가 아니라 시험의 것. 오늘 작업 전 커밋에서도 같았다.
- **성능 예산이 늘 빨갰다.** `verify-performance.sh` 가 RSS 로 100MB 를 재는데 0.5.0 부터 실리는 LiteRT-LM dylib(65MB) 의 깨끗한 코드 페이지가 RSS 를 127MB 로 올린다. `footprint` 는 48MB.

## 해결 방법

- 커서 따라가기는 텍스트 뷰가 first responder 일 때만 (`d6e1ae8`).
- 스캐너에 `scanTables` — `|` 는 `.syntax`(커서 줄 밖에서 감춰짐), `| --- |` 줄은 통째로 마커, 바로 위 머리 칸은 `.strong`. 글자를 바꾸지 않는 규칙 안이라 칸 정렬은 안 한다 (`90ebbe9`). 종이에서 「구분 금액 / 시급 10,320원」으로 읽히는 것을 찍어 확인.
- 네 타깃에 `PrivacyInfo.xcprivacy`(추적·수집 없음, CA92.1·C617.1·E174.1·35F9.1). 동기화 그룹이라 앱·appex 번들에 자동으로 실림을 시뮬레이터 빌드에서 확인 (`05ceaf0`).
- 시험은 내일 기준 날짜를 심고, 딥링크는 한 글자 치고 지워 진짜 키보드를 올린 뒤 내린다 (`a49a910` 앞 커밋).
- 예산은 footprint 로 판정, RSS 는 참고. 설계문서 §11 재측정값 (`716e857`).
- 0.9.1 로 올려 태그·TestFlight (배포 일지 별도).

## 검증

- 맥 전체 시험 초록(UITests 377·스캐너 29), 폰 스모크 **23/23**, `verify-performance.sh` ✓ (footprint 48MB · idle 0%).
- 긴 메모·표 메모를 다시 띄워 창 캡처로 눈으로 확인 — 첫 줄부터, 표는 머리 굵게·세로선 없이.

## 메모

- 본 것 중 괜찮았던 것: 종이·빠른 입력·웹 답 카드·서랍·달력·설정(테마 절)·폰 펜/목록/편집/달력. 테마 견본 여덟이 설정 창에 4×2 로 서고 미드나잇은 빛 모드에서도 어둡다.
- 못 본 것: 위젯 실기(시뮬레이터 홈 화면에 못 놓는다), 테마 전환의 실시간 반응(테마 에이전트가 손검증), 실기기 폰.
- 홈의 `LazyMemo-bgsjk…` DerivedData(220M, 19:42)는 본 저장소 경로 것이라 두었다 — 어느 세션 것인지 모른다.