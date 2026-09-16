# lazymemo 무료 Mac App Store 출시 점검

2026-09-12 코드 검토 기준. **현재 산출물은 로컬 테스트용이며 App Store 제출 빌드가 아니다.**

## 이번 개선

- 첫 실행에 종이 질감의 시작 화면. 메모·달력·서랍으로 바로 이동하며 메뉴에서 다시 열 수 있다.
- 빠른 입력의 시각적 위계, 사진·링크·할 일 검색 바로가기, 최근 목록의 제목과 개수, 클릭 가능한 확정 버튼.
- 키보드로 고른 메모와 포인터가 닿은 메모의 구분 및 삭제 되돌리기 유지. 목록 행을 접근성 버튼으로 변경.
- 펼친 검색 결과를 스크롤 영역에 담아 입력창이 화면 밖으로 길어지는 것을 방지. 키보드 선택을 스크롤로 따라간다.
- App Store 영수증 및 `LazyMemoAppStoreBuild` 플래그로 외부 업데이트 확인·설치·메뉴를 차단.

## 제출 전 해결할 항목

| 우선순위 | 발견한 상태 | 완료 기준 |
|---|---|---|
| ~~필수~~ | ~~`build-app.sh`는 ad-hoc 서명, 샌드박스 entitlement 없음~~ **해결 (2026-09-13)** — `ios/LazyMemo.xcodeproj` 의 `LazyMemo-macOS` 타깃이 샌드박스 entitlement(`ios/Config/LazyMemo-macOS.entitlements`)로 자동 서명·아카이브한다. `./ios/scripts/archive.sh mac` | 검증된 archive 가 TestFlight 에 올라간다 |
| ~~필수~~ | ~~`VaultMover`는 외부 폴더의 문자열 경로만 저장~~ **해결** — `VaultBookmark` 가 고른 폴더의 security-scoped bookmark 를 `settings.json` 에 같이 적고, `AppPaths.resolve` 가 그것으로 문을 연다. 낡은 열쇠는 갱신, 못 열면 `missingVault` 로 정직하게 돌아온다 | 외장 디스크 해제·iCloud 미다운로드는 손검증 항목 |
| ~~필수~~ | ~~`ClaudeSupport` / `ClaudeRunner`가 외부 CLI를 실행~~ **해결** — 스토어 판(`InstallSource.current.isAppStore`)에서는 `ClaudeSupport.resolve` 가 `nil` 이라 셸도 안 띄우고 메뉴에도 없다. MCP 서버 바이너리는 스토어 번들에 들어가지 않는다 | 기본 메모·달력은 외부 구독 없이 그대로 |
| ~~필수~~ | ~~현재 빌드 스크립트에 스토어 전용 구성이 없음~~ **해결** — `ios/Config/Mac-Info.plist` 가 `LazyMemoAppStoreBuild = true`. 로컬에서 ad-hoc 서명한 스토어 판의 메뉴에 업데이트 줄이 없는 것을 확인 | |
| ~~필수~~ | ~~공개 개인정보 처리방침 및 스토어 개인정보 응답 미확정~~ **해결** — `docs/PRIVACY.md` → https://bunhine0452.github.io/lazymemo/privacy/ (ko·en). 스토어 응답 초안은 그 문서 끝 | 제출 때 그대로 옮긴다 |
| ~~필수~~ | ~~배포 계정·App Store Connect 메타데이터 미검증~~ **해결 (2026-09-14)** — 앱 레코드(Apple ID 6811815255)·무료·4+·개인정보 게시·설명·키워드·스크린샷·심사 메모 전부 입력, iOS 0.1.0(1)·macOS 0.4.0(1) 빌드가 TestFlight 에 올라가 각 버전에 붙어 있다. 원고는 `docs/STORE_LISTING.md` | 「심사에 추가」 만 남았다 — 아래 TestFlight 손검증 뒤 |
| ~~품질~~ | ~~빠른 입력 초안은 프로세스 메모리에만 유지~~ **해결** — `CaptureDraftStore` 가 Application Support 의 `capture-draft.txt` 에 남기고 확정하면 지운다 | 앱 종료·충돌·판 갈이 뒤에도 미확정 입력을 복원한다. 검색어는 메모가 되지 않는다 |
| ~~품질~~ | ~~macOS 26 이상만 지원, 한국어 UI 중심~~ **영어 해결 (2026-09-14)** — 맥·아이폰·공유 확장·MCP 의 화면 말 전부가 `en.lproj` 표를 지난다(한국어 원문이 열쇠, `Sources/LazyMemoCore/Words.swift`). 개발 언어를 영어로 두어 한국어가 아닌 사용자는 영어를 본다. 빠진 열쇠는 `scripts/check-l10n.sh --ios` 가 잡는다 | macOS 26 이상만 지원은 그대로. 영어 스토어 스크린샷은 `ShotTests`·`DemoTour` 가 한국어 낱말로 누르는 자리를 식별자로 바꾼 뒤 |

## TestFlight 손검증 — 제출 전에 사람 손으로 (2026-09-14, 내부 그룹 「lazymemo internal」)

기계로 본 것: 서명본이 샌드박스 컨테이너에서 뜨고, 메모 폴더가 iCloud Drive 의 「LazyMemo」로 잡히고(entitlement 로 찾음), 재시작해도 같은 자리·같은 메모 수, 설정 메뉴에 Claude·업데이트 줄이 없다. 첫 기동이 빈 컨테이너에 환영 메모 한 장을 만들었다 — 아이폰에도 보일 것이다.

사람 손으로 봐야 하는 것 — **맥** (TestFlight 앱 → lazymemo 설치. GitHub 판이 떠 있으면 먼저 종료: 같은 번들 id 라 핫키가 둘이 된다)

- [ ] 메뉴 막대 아이콘이 서고 바탕화면에 환영 메모가 눕는다 (Dock 아이콘 없음)
- [ ] `⌥⌘N` 빠른 입력 → 「내일 오후 3시 치과」 → 달력 칩 → `⌘↩` → 달력에 선다
- [ ] 달력 창을 처음 열 때 캘린더 권한을 **한 번만** 묻는다 (거절해도 앱은 멀쩡)
- [ ] `⌥⌘L` 을 처음 누를 때 위치 권한을 한 번만 묻는다 → 종이에 장소 자국
- [ ] 설정 → 메모 폴더 옮기기… → 패널로 `~/Documents/lazymemo` 를 골라 채택 → 종이가 따라온다 → **앱을 완전히 종료하고 다시 켜서** 같은 폴더를 여는지 (security-scoped bookmark)
- [ ] 설정 → 「iCloud 로 동기화…」 로 도로 컨테이너로 → 아이폰의 lazymemo 에 같은 메모가 보인다 / 아이폰에서 적은 한 줄이 맥 바탕화면에 종이로 선다
- [ ] 설정 → 「로그인할 때 시작」 켜기 → 시스템 설정 › 일반 › 로그인 항목에 lazymemo 가 나타난다
- [ ] 종이를 옮기고 달력·서랍을 열어 둔 채 종료 → 다시 켜면 창 자리·열림이 그대로다
- [ ] 다른 앱을 앞에 두면 종이가 뒤로 눕고, 바탕화면을 클릭하면 도로 보인다

**아이폰** (TestFlight 앱 → 설치)

- [ ] 켜면 바로 키보드 · 한 줄 남기기 · 「내일 오후 3시 치과」가 달력에
- [ ] 핀을 눌렀을 때만 위치를 묻는다 (첫 실행엔 안 묻는다)
- [ ] 사파리·지도에서 공유 → 「lazymemo 에 적기」 → 메모가 된다 (지도 공유는 장소로)
- [ ] 맥과 왕복 — 폰에서 적은 것이 맥에, 맥에서 고친 것이 폰에 (지연 · 같은 메모를 양쪽에서 고쳤을 때 휴지통에 한 장)
- [ ] 비행기 모드에서 적고 → 켜면 올라간다

전부 지나면 ASC 의 두 버전 페이지에서 「심사에 추가」.

샌드박스 전환 시 기존 Documents 저장소의 메모가 사라진 것처럼 보이지 않도록 사용자가 기존 폴더를 선택해 가져오는 흐름도 필요하다 — 「메모 폴더 옮기기…」로 `~/Documents/lazymemo` 를 고르면 `VaultRelocation` 이 그 폴더를 채택(adopt)하고 열쇠가 붙는다. 스토어 판의 기본 자리는 iCloud Drive 의 「LazyMemo」 폴더이고(폰과 같은 자리), iCloud 가 꺼져 있으면 컨테이너 안이라고 메뉴가 적는다 — 조용히 바꾸지 않는다 (설계문서 §12.6).

## 2026-09-15 정식 출시 점검 — 찾은 것과 고친 것

기계로 전부 돌렸다: 패키지 시험 776 · `verify-*.sh` 12개 · `verify-mcp.sh` · 아이폰 XCUITest 15. 셋 다 처음엔 빨갰고, 원인은 하나로 모였다.

| 무엇 | 어디서 드러났나 | 고친 것 |
|---|---|---|
| **한국어 앱에 영어 복수형이 선다** — 「1 photos」 (폰의 사진 메모 줄), 「3 notes」류. ko 표에 없는 복수형 열쇠를 Foundation 이 영어 `stringsdict` 로 건너뛰고, 한국어엔 단·복수가 없어 「other」 꼴을 고른다 | 시뮬레이터 `testPhotoFromMacShowsOnThePaper`, 스크래치 번들 재현 | `Words.locale` 이 늘 **이름 있는 로케일**을 낸다 (`Locale(identifier: Locale.current.identifier)`) — 이름을 주면 그 표만 본다. 아이폰 앱의 SwiftUI 리터럴은 `ko.lproj/Localizable.stringsdict` 를 두어 건너뛸 일이 없게 했다 |
| **영어 「1 photos」·「1 reminders scheduled」·「among 1 notes」** — `.strings` 에 복수형 없이 적힌 셋 | `swift test` 출력 | Core·Reminders·iOS 의 `stringsdict` 로 옮기고 시험을 하나 더 |
| **`swift test` 가 한국어 기계에서도 영어로 돈다** — 툴체인 헬퍼가 주 번들이라 lproj 가 없어 늘 개발 언어로 떨어진다. 한국어 원문을 기대하는 시험 39개가 빨갛고, 릴리스 워크플로(en 러너)는 시험 단계에서 멈췄을 것 | `./scripts/test.sh` | `test.sh` 가 `LAZYMEMO_LANGUAGE=ko` 로 고정. `swift run`·`.build` 의 MCP 도 같은 이유로 영어였다 — 이제 기계의 말을 따른다 (`verify-tidy`·`verify-mcp` 가 그래서 빨갰었다) |
| 시험이 `~/Library/Preferences` 에 plist 를 하나씩 남긴다 (96개 쌓여 있었다) | `ReminderCenterTests` | 폴더와 같은 이름의 도메인을 쓰고 끝에 지운다. 쌓인 것은 치웠다 |
| 시뮬레이터에 기기별 기억이 남아 다음 시험이 첫 실행이 아니다 — 소개 영상(DemoTests)이 켜 둔 「알림 켜짐」, 앞 시험이 「봤어요」로 내려놓은 「지금」 카드 | `testRemindersSheetOpensFromMore`·`testRevisit…`·`testSeen…` (둘째 실행에서만 빨갛다) | 시험 실행 인자 `-recall.notifications.enabled NO -now-seen {}` — 인자 도메인이 저장된 값을 가린다 |
| 스토어 판 메뉴에 ⌥ 로 나오는 개발용 「바탕화면 창 스파이크」 | 코드 | 스토어 판에서는 항목 자체를 안 만든다 |
| 개인정보 처리방침이 「알림 — 요구하지 않는다」고 적고, 자리 카드·가는 길을 폰 것으로만 적었다 (맥에도 있다) | `docs/PRIVACY.md`·`site/privacy/` | 알림(직접 켤 때만·기기별·로컬)·자리 카드(맥·폰)·가는 길을 적고 날짜를 올렸다. README 프라이버시 표도 같이 |
| 스토어 설명에 「다시 보기」가 없고 심사 메모에 알림 권한 설명이 없다 | `docs/STORE_LISTING.md` | 한 줄씩 더했다 — **ASC 에도 옮겨 적어야 한다** |
| 소개 페이지가 「TestFlight 준비 중」·「MCP 만 나간다」·영어판 「한국어만」 상태 | `site/` | 출시판으로 다시 썼다 (아래) |

## 출시 날 할 일 — 순서대로

1. **새 빌드부터.** ASC 에 붙어 있는 빌드(iOS 0.1.0·macOS 0.4.0, 09-15 03:08 업로드)에는 「1 photos」 가 들어 있다. 위 수정을 커밋한 깨끗한 트리에서 `./ios/scripts/archive.sh` 와 `./ios/scripts/archive.sh mac` 을 돌려 올리고, 두 버전 페이지의 「빌드」를 새것으로 바꾼다.
2. **ASC**: 두 버전 페이지의 설명에 「다시 보기」 줄, 심사 메모에 알림 문단을 붙여 넣는다 (`docs/STORE_LISTING.md`). 그 뒤 「심사에 추가」.
3. 심사 중에는 아무것도 안 한다. 소개 페이지는 지금 상태(「심사 중」 배지, 스토어 단추는 회색)로 나가도 거짓이 없다.
4. **승인되면** `site/index.html`·`site/ko/index.html` 의 `<body data-store="soon">` 을 `"live"` 로 — 그 한 낱말이 머리의 배지·스토어 단추·폰 절의 문장을 한꺼번에 바꾼다 (두 판이 같은 파일에 산다). 스토어 주소는 `https://apps.apple.com/app/id6811815255?platform=mac|iphone` 으로 이미 적혀 있다. main 에 밀면 Pages 워크플로가 내보낸다.
5. README 「설치」의 「App Store 판(준비 중)」 을 「App Store 판」 으로.
6. GitHub 판은 따로 — 판을 올려 태그를 밀면 워크플로가 시험을 돌려 낸다. **시험이 이제 en 러너에서도 초록이다** (위 표 셋째 줄).

판 번호는 그대로 둔다 — ASC 에 macOS 0.4.0·iOS 0.1.0 레코드가 빌드와 함께 서 있어 바꾸면 다시 올려야 한다. 1.0 으로 이름을 붙이고 싶으면 다음 판에서.

## 제품 방향

핵심 가치는 **가입 없이, 내 Mac에, 한 줄로 남기는 바탕화면 메모**다. 무료 앱의 기본 경험은 외부 AI 설치·구독에 의존하지 않아야 한다. 날짜 인식·체크리스트·사진·검색·서랍이 첫날의 매력을 담당한다.

새 기능 수를 늘리기보다 다음 상황을 출시 검증에 포함한다: 재실행 후 내용 복원, 디스크 쓰기 실패, 외부 파일 수정, 한글 IME, 여러 화면 및 Space, VoiceOver 키보드 조작, 달력 권한 거부, 다크 모드, 긴 메모와 많은 검색 결과.

## Apple 근거

- [App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/): Mac App Store 앱의 샌드박스와 App Store 업데이트 요구 사항.
- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox): 샌드박스의 파일·자원 접근 제한과 호환성 검토.

이 문서는 승인 보장이 아니라 코드에서 확인한 제출 준비 상태다. 개발자 프로그램 가입 여부와 실제 배포 인증서·App Store Connect 설정은 별도다.
