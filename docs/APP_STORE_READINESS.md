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
| 품질 | macOS 26 이상만 지원, 한국어 UI 중심 | 출시 지원 범위를 명시. 다른 macOS 버전과 영어 지원은 별도 실제 기기 검증 후 확대 |

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

## 제품 방향

핵심 가치는 **가입 없이, 내 Mac에, 한 줄로 남기는 바탕화면 메모**다. 무료 앱의 기본 경험은 외부 AI 설치·구독에 의존하지 않아야 한다. 날짜 인식·체크리스트·사진·검색·서랍이 첫날의 매력을 담당한다.

새 기능 수를 늘리기보다 다음 상황을 출시 검증에 포함한다: 재실행 후 내용 복원, 디스크 쓰기 실패, 외부 파일 수정, 한글 IME, 여러 화면 및 Space, VoiceOver 키보드 조작, 달력 권한 거부, 다크 모드, 긴 메모와 많은 검색 결과.

## Apple 근거

- [App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/): Mac App Store 앱의 샌드박스와 App Store 업데이트 요구 사항.
- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox): 샌드박스의 파일·자원 접근 제한과 호환성 검토.

이 문서는 승인 보장이 아니라 코드에서 확인한 제출 준비 상태다. 개발자 프로그램 가입 여부와 실제 배포 인증서·App Store Connect 설정은 별도다.
