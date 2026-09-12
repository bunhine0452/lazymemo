---
oculpm_plan: v1
id: lazymemo-ios-icloud
title: "iOS 앱 + iCloud 컨테이너 동기화 — 폰에서 던지고 맥에서 받는다"
status: active
created: 2026-09-13
updated: 2026-09-13
owner: claude-code
---

LazyMemoCore 를 그대로 iOS 로 옮기고, 두 앱이 앱 전용 iCloud 컨테이너(iCloud.io.github.bunhine0452.lazymemo)의 Documents 를 같은 Vault 로 쓴다. 백엔드·계정 없음(D4 연장). 파생물(index·layout·settings)은 기기별로 남고, 창 위치·서랍은 맥의 개념이라 폰에는 없다. 폰 앱 = 빠른 입력·목록·달력·편집.

## LazyMemoCore 가 iOS 로 컴파일된다 {#core-ios}
- [x] Package.swift 에 iOS 26 플랫폼을 더한다 — Core 는 Foundation·SQLite3·CryptoKit·CoreGraphics 뿐이라 그대로 간다 {#core-platforms}
- [x] VaultWatcher(FSEvents)·UpdateInstaller·ClaudeRunner(Process) 와 그 참조 지점을 `#if os(macOS)` 로 울타리 친다 {#core-fence-macos}
- [x] xcodebuild 로 iOS 시뮬레이터 대상 LazyMemoCore 빌드 통과 {#core-ios-build}
- [x] LazyMemoCoreTests 를 iOS 시뮬레이터에서 돌려 통과 (macOS `swift test` 도 그대로 그린) {#core-tests-ios}

## Xcode 앱 프로젝트와 iCloud 컨테이너 {#ios-project}
- [x] ios/LazyMemo.xcodeproj — 로컬 패키지(LazyMemoCore) 참조, 파일 시스템 동기화 그룹, 생성 Info.plist, 같은 번들 id {#ios-xcodeproj}
- [x] iCloud Documents 컨테이너 entitlement + NSUbiquitousContainers 공개 — 파일 앱·Finder 에 「LazyMemo」 폴더로 보인다 {#ios-entitlements}
- [x] AppPaths 의 iOS 자리 — vault = 컨테이너 Documents, support = 앱 Application Support; 컨테이너가 없으면(iCloud 꺼짐) 로컬 Documents 로 폴백하고 그 사실을 들고 나온다 {#ios-paths}
- [x] 시뮬레이터에서 앱이 뜨고 메모 한 장이 파일로 떨어지는 스모크 {#ios-sim-build}

## iCloud 위에서도 정본이 정직하다 {#sync-core}
- [ ] iOS 용 VaultWatcher — NSMetadataQuery 로 컨테이너 변경을 받아 같은 handler 인터페이스로 넘긴다 {#sync-watcher-ios}
- [ ] 아직 안 내려온 파일(.icloud 플레이스홀더)에 다운로드를 요청한다 — 스캔에 안 보이는 메모가 없게 {#sync-placeholder}
- [ ] 충돌 정책 — updated 가 늦은 쪽이 남고 진 쪽은 새 ULID 로 휴지통에 (글은 절대 안 잃는다, D6 연장) + 테스트 {#sync-conflict}
- [ ] 컨테이너 안 읽기·쓰기에 NSFileCoordinator 가 필요한지 판단하고 필요한 자리에만 붙인다 {#sync-coordination}

## 폰 화면 — 빠른 입력·목록·달력·편집 {#ios-ui}
- [ ] 켜면 바로 키보드 — 빠른 입력. 공용 NaturalDateParser 로 날짜를 읽으면 「달력에 남기기」로 바뀐다 {#ui-capture}
- [ ] 목록 — 최근순, 찾기(첫소리 HangulInitials), 폴더 칩, 밀어서 지우기 + 되돌리기 {#ui-list}
- [ ] 달력 — 달 격자(MonthGrid) + 그 날 일정(DayAgenda), 미루기·종이로·지우기 {#ui-calendar}
- [ ] 편집 — 저장 버튼 없이 글자가 바뀌면 파일로, 바깥(맥)에서 바뀌면 화면이 따라온다 {#ui-editor}
- [ ] 휴지통 — 최근 삭제 목록·되돌리기 {#ui-trash}
- [ ] 공유 시트 확장 「lazymemo 에 적기」 — InboundNote 를 거쳐 컨테이너에 파일 하나 {#ui-share-ext}
- [ ] 빠른 입력의 「지금 여기」 — 누를 때만 위치를 재고 place·geo 를 붙인다 (첫 실행에 묻지 않는다) {#ui-location}

## 맥이 iCloud 를 같이 본다 {#mac-side}
- [ ] 설정 → 「iCloud 로 동기화」 — 컨테이너 자리 해석(entitlement 있으면 API, 없으면 Mobile Documents 경로) 뒤 VaultRelocation 재사용 {#mac-icloud-sync}
- [ ] vault 가 Mobile Documents 안이면 맥에서도 미다운로드 파일을 내려받는다 (Mac 저장 공간 최적화 대비) {#mac-placeholder}
- [ ] build-app.sh 에 Developer ID 서명·iCloud entitlement·프로비저닝·공증 경로 — 환경변수로 identity, 없으면 지금처럼 ad-hoc {#mac-signing}
- [ ] README·DESIGN §5.1·§12 에 iOS 앱과 iCloud 컨테이너를 적는다 — 단축어 절은 「앱 없이」 대안으로 남긴다 {#mac-docs}

## 손에 쥐어 본다 {#release}
- [ ] 실기기(아이폰) 설치 + 맥과 왕복 동기화 손검증 — 지연·충돌·오프라인·플레이스홀더 {#release-device}
- [ ] App Store Connect 앱 레코드 + TestFlight 업로드 {#release-testflight}
- [ ] 개인정보 처리방침·스토어 개인정보 응답 — README 프라이버시 절을 기준으로 {#release-privacy}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-13T02:06:14+09:00 | #core-platforms | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0206_feature_core-compiles-for-ios.md | .iOS(.v26) 추가 |
| 2026-09-13T02:06:20+09:00 | #core-fence-macos | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0206_feature_core-compiles-for-ios.md | VaultWatcher iOS 빈 감시자, Runner/Installer 파일 전체 |
| 2026-09-13T02:06:26+09:00 | #core-ios-build | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0206_feature_core-compiles-for-ios.md | generic/platform=iOS Simulator BUILD SUCCEEDED |
| 2026-09-13T02:06:30+09:00 | #core-tests-ios | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0206_feature_core-compiles-for-ios.md | 343 통과 (iPhone 17 시뮬레이터), 맥 361 그대로 |
| 2026-09-13T02:21:14+09:00 | #ios-xcodeproj | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md | 손으로 쓴 pbxproj, 타깃 LazyMemo-iOS, UI 시험 타깃 포함 |
| 2026-09-13T02:21:19+09:00 | #ios-entitlements | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md | App ID·컨테이너 등록됨, 기기 빌드 서명에 박힘 |
| 2026-09-13T02:21:24+09:00 | #ios-paths | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md | AppPaths.resolveCloud + usingCloud, 테스트 3 |
| 2026-09-13T02:21:29+09:00 | #ios-sim-build | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/0221_feature_ios-app-project-and-icloud-container.md | XCUITest 스모크 통과 — 적으면 파일, 파일이면 목록 |
<!-- oculpm:plan-log end -->
