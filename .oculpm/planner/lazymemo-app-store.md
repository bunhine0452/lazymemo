---
oculpm_plan: v1
id: lazymemo-app-store
title: "App Store 출시 — 아이폰과 맥, 하나의 앱 레코드로"
status: active
created: 2026-09-13
updated: 2026-09-13
owner: claude-code
---

iOS 는 지금 Xcode 프로젝트를 스토어용으로 다듬고, 맥은 샌드박스 스토어 판(Claude 연동 없음)을 Xcode 타깃으로 따로 둔다. 같은 번들 id 라 App Store Connect 앱 레코드는 하나. GitHub/Homebrew 판은 지금 그대로.

## 아이폰 — 스토어용으로 다듬기 {#ios-store}
- [x] 아이폰 전용 (TARGETED_DEVICE_FAMILY = 1, 앱·공유 확장 둘 다) + iPad 방향 키 제거 {#ios-iphone-only}
- [x] Info.plist 스토어 키 — ITSAppUsesNonExemptEncryption=false, 위치 사용 문구를 README 프라이버시 절과 맞춘다 {#ios-plist-store}
- [x] AppIcon 1024 이 자산 카탈로그에 있는지, 아카이브가 여전히 통과하는지 {#ios-icon-check}
- [x] 스토어 스크린샷 — ShotTests 를 6.9″ 시뮬레이터에서 돌려 dist/store/ios/ 에 모은다 {#ios-screenshots}

## 맥 — 샌드박스 스토어 판 {#mac-store}
- [x] 스토어 판 판별 하나로 모은다 — InstallSource 의 App Store 판별을 Claude 연동·MCP 안내·업데이트가 같이 본다 {#mac-flavor}
- [x] 스토어 판에서 Claude 연동을 통째로 숨긴다 — ClaudeSupport.resolve 가 nil, ✧ 다듬기·아침 브리핑·MCP 등록 메뉴 없음, 로그인 셸을 띄우지 않는다 {#mac-hide-claude}
- [x] 메모 폴더를 security-scoped bookmark 로 기억한다 — 고른 폴더는 북마크로 저장, 기동 때 접근 시작, 낡은 북마크 갱신, 못 열면 기본 자리로 정직하게 돌아온다 {#mac-bookmark}
- [x] 스토어 판의 기본 자리 — iCloud 컨테이너 Documents(폰과 같은 자리), iCloud 가 꺼져 있으면 샌드박스 컨테이너. 설정 메뉴가 어디인지 적는다 {#mac-default-vault}
- [x] ios/LazyMemo.xcodeproj 에 LazyMemo-macOS 타깃 — LazyMemoUI 패키지 의존, 스토어 Info.plist(LazyMemoAppStoreBuild, 카테고리, 암호화 면제), 샌드박스 entitlement(iCloud·네트워크·위치·캘린더·사용자 선택 파일·북마크) {#mac-xcode-target}
- [x] ios/scripts/archive.sh 가 --mac 으로 맥 타깃도 아카이브·업로드한다 {#mac-archive-script}
- [~] 샌드박스 판 손검증 — 폴더 고르기·재시작 뒤 접근 유지·iCloud 동기화·핫키·달력 권한·위치·로그인 항목·창 복원 {#mac-sandbox-handtest}

## App Store Connect {#asc}
- [x] 개인정보 처리방침을 site/privacy/ 에 얹는다 (ko·en, 바깥 요청 없음) — Pages 로 URL 이 생긴다 {#asc-privacy-page}
- [x] 앱 레코드 생성 — 이름·기본 언어 한국어·번들 id·SKU, iOS + macOS 플랫폼 {#asc-record}
- [~] 아이폰 TestFlight 업로드 + 내부 테스터로 설치 {#asc-testflight-ios}
- [~] 맥 TestFlight 업로드 + 설치해서 샌드박스 판이 실제로 뜨는지 {#asc-testflight-mac}
- [x] 메타데이터 — 설명(ko·en)·키워드·카테고리 생산성·무료·연령 4+·지원 URL·개인정보 URL·앱 개인정보 「수집 안 함」·심사 메모 {#asc-metadata}
- [x] 맥 스크린샷 — render-ui.sh 산출물을 스토어 규격(2880×1800)으로 {#asc-mac-screenshots}
- [ ] 심사 제출 — 아이폰·맥 {#asc-submit}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-13T11:39:18+09:00 | #ios-iphone-only | claude-code | ☐→x | .oculpm/journal/20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md | TARGETED_DEVICE_FAMILY=1, iPad 방향 키 제거 |
| 2026-09-13T11:39:23+09:00 | #ios-plist-store | claude-code | ☐→x | .oculpm/journal/20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md | 암호화 면제 키 + 위치 문구 |
| 2026-09-13T11:39:28+09:00 | #ios-icon-check | claude-code | ☐→x | .oculpm/journal/20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md | 아이콘이 아예 없었다 — make-icon --ios 로 알파 없는 1024 생성 |
| 2026-09-13T11:39:33+09:00 | #asc-privacy-page | claude-code | ☐→x | .oculpm/journal/20260913/Chores/1139_chore_ios-store-ready-icon-iphone-only.md | site/privacy/ ko·en — main 에 push 되면 Pages 가 URL 을 만든다 |
| 2026-09-13T11:55:39+09:00 | #mac-flavor | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | InstallSource.current |
| 2026-09-13T11:55:45+09:00 | #mac-hide-claude | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | ClaudeSupport nil + 메뉴 가림, 샌드박스 스모크로 확인 |
| 2026-09-13T11:55:50+09:00 | #mac-bookmark | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | VaultBookmark + Settings.vaultBookmark, 테스트 3개 |
| 2026-09-13T11:55:55+09:00 | #mac-default-vault | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | resolve(cloudContainer:) + rememberVault 고정 + VaultLabel |
| 2026-09-13T11:56:01+09:00 | #mac-xcode-target | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | LazyMemo-macOS 타깃·스킴·plist·entitlements — 무서명 빌드 통과 |
| 2026-09-13T11:56:06+09:00 | #mac-archive-script | claude-code | ☐→x | .oculpm/journal/20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md | archive.sh mac — 실제 아카이브는 Xcode 계정 로그인 뒤 |
| 2026-09-13T11:59:29+09:00 | #ios-screenshots | claude-code | ☐→x | .oculpm/journal/20260913/Chores/1159_chore_ios-store-screenshots.md | dist/store/ios 5장, 1320×2868 |
| 2026-09-14T17:16:06+09:00 | #asc-mac-screenshots | claude-code | ☐→x | .oculpm/journal/20260914/Chores/1715_chore_mac-store-screenshots-and-checklist-fix.md | store-shots.sh → dist/store/mac 5장 2880×1800 |
| 2026-09-14T17:20:53+09:00 | #asc-record | claude-code | ☐→x |  | ASC 에 lazymemo 레코드 생성 — iOS+macOS, ko, io.github.bunhine0452.lazymemo, SKU lazymemo |
| 2026-09-14T17:53:10+09:00 | #asc-metadata | claude-code | ☐→x | .oculpm/journal/20260914/Chores/1753_chore_asc-record-and-metadata.md | ASC 앱 정보·연령 4+·무료·개인정보 게시·iOS/macOS 버전 메타데이터+스크린샷 전부 입력. 빌드만 남음 |
| 2026-09-14T18:14:43+09:00 | #asc-testflight-ios | claude-code | ☐→~ | .oculpm/journal/20260914/Chores/1814_chore_testflight-upload-both-platforms.md | 빌드 1(0.1.0) 업로드·처리 완료·버전에 붙임. 내부 테스터 설치는 사용자 손 |
| 2026-09-14T18:14:49+09:00 | #asc-testflight-mac | claude-code | ☐→~ | .oculpm/journal/20260914/Chores/1814_chore_testflight-upload-both-platforms.md | 빌드 0.4.0(1) 업로드·처리 완료·버전에 붙임. 기기 등록이 먼저였다. TestFlight 설치는 사용자 손 |
| 2026-09-14T18:14:55+09:00 | #mac-sandbox-handtest | claude-code | ☐→~ | .oculpm/journal/20260914/Chores/1814_chore_testflight-upload-both-platforms.md | 서명본 기계 검증: 샌드박스 기동·iCloud 기본 자리·재시작 유지·Claude 없음 ✓. 패널·핫키·권한·로그인 항목·창 복원은 사람 손 |
| 2026-09-14T19:15:36+09:00 | #asc-submit | claude-code | ☐→☐ | .oculpm/journal/20260914/Chores/1915_chore_testflight-internal-group-and-handoff.md | 두 버전 「심사에 추가」 활성. 사용자 결정: TestFlight 손검증(READINESS 체크리스트) 뒤 「제출해」 신호에 누른다 |
<!-- oculpm:plan-log end -->
