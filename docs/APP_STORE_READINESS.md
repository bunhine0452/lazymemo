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
| 필수 | 배포 계정·App Store Connect 메타데이터 미검증 | 무료 가격 설정, 지원 URL, 앱 설명, 연령 등급, 리뷰 안내 및 실제 앱 스크린샷 등록 — `.oculpm/planner/lazymemo-app-store.md` 가 진행을 적는다 |
| ~~품질~~ | ~~빠른 입력 초안은 프로세스 메모리에만 유지~~ **해결** — `CaptureDraftStore` 가 Application Support 의 `capture-draft.txt` 에 남기고 확정하면 지운다 | 앱 종료·충돌·판 갈이 뒤에도 미확정 입력을 복원한다. 검색어는 메모가 되지 않는다 |
| 품질 | macOS 26 이상만 지원, 한국어 UI 중심 | 출시 지원 범위를 명시. 다른 macOS 버전과 영어 지원은 별도 실제 기기 검증 후 확대 |

샌드박스 전환 시 기존 Documents 저장소의 메모가 사라진 것처럼 보이지 않도록 사용자가 기존 폴더를 선택해 가져오는 흐름도 필요하다 — 「메모 폴더 옮기기…」로 `~/Documents/lazymemo` 를 고르면 `VaultRelocation` 이 그 폴더를 채택(adopt)하고 열쇠가 붙는다. 스토어 판의 기본 자리는 iCloud Drive 의 「LazyMemo」 폴더이고(폰과 같은 자리), iCloud 가 꺼져 있으면 컨테이너 안이라고 메뉴가 적는다 — 조용히 바꾸지 않는다 (설계문서 §12.6).

## 제품 방향

핵심 가치는 **가입 없이, 내 Mac에, 한 줄로 남기는 바탕화면 메모**다. 무료 앱의 기본 경험은 외부 AI 설치·구독에 의존하지 않아야 한다. 날짜 인식·체크리스트·사진·검색·서랍이 첫날의 매력을 담당한다.

새 기능 수를 늘리기보다 다음 상황을 출시 검증에 포함한다: 재실행 후 내용 복원, 디스크 쓰기 실패, 외부 파일 수정, 한글 IME, 여러 화면 및 Space, VoiceOver 키보드 조작, 달력 권한 거부, 다크 모드, 긴 메모와 많은 검색 결과.

## Apple 근거

- [App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/): Mac App Store 앱의 샌드박스와 App Store 업데이트 요구 사항.
- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox): 샌드박스의 파일·자원 접근 제한과 호환성 검토.

이 문서는 승인 보장이 아니라 코드에서 확인한 제출 준비 상태다. 개발자 프로그램 가입 여부와 실제 배포 인증서·App Store Connect 설정은 별도다.
