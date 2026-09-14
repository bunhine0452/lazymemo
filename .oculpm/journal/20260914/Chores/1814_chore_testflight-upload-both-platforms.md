---
schema_version: 1
type: chore
slug: "testflight-upload-both-platforms"
status: done
difficulty: medium
created_at: "2026-09-14T18:14:35+09:00"
session_id: "20260914-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/scripts/archive.sh"
    op: update
related:
  - ref: "20260914/Chores/1753_chore_asc-record-and-metadata.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/1155_feature_mac-app-store-sandbox-build.md"
    kind: "followup"
tags:
  - "app-store"
  - "testflight"
  - "ios"
  - "mac"
  - "signing"
  - "sandbox"
  - "mcp-tool"
---
[x] 사용자가 Xcode 에 로그인한 직후 — `archive.sh` (iOS) 와 `archive.sh mac` 둘 다 업로드 성공, ASC 버전 페이지에 빌드를 붙이고 버전 문자열을 빌드와 맞췄다

## 한 것

- **iOS**: 아카이브·업로드 한 번에 통과. 로그인 전에도 아카이브는 됐고(개발용 프로필이 캐시돼 있었다) 업로드만 `Failed to Use Accounts` 였다.
- **맥**: `Your team has no devices from which to generate a provisioning profile` — 아카이브 단계가 **Mac App Development 프로필**을 먼저 쓰는데, 그 프로필은 등록된 기기가 있어야 생긴다. `-allowProvisioningDeviceRegistration` 을 archive 에 붙였지만 `generic/platform=macOS` 대상으로는 어느 기기를 등록할지 몰라 안 됐다. `xcodebuild build -destination 'platform=macOS,arch=arm64' -allowProvisioningUpdates -allowProvisioningDeviceRegistration` 을 한 번 돌리니 이 맥이 등록되고 프로필이 생겼고, 그 뒤 `archive.sh mac` 이 통과했다 (App Sandbox ✓ · iCloud entitlement ✓ · LazyMemoAppStoreBuild ✓ · pkg 업로드). 플래그는 스크립트에 남겨 둔다 — 다음 맥에서도 build 한 번이 먼저다.
- **ASC**: 두 빌드가 몇 분 안에 처리돼 「빌드 추가」에 나타났다. 붙인 뒤 **버전 문자열을 빌드와 맞췄다** — ASC 가 만든 기본값 1.0 대신 iOS `0.1.0`, macOS `0.4.0` (제출 때 빌드 버전과 어긋나면 막힌다). 두 페이지 모두 「심사에 추가」 활성.
- **샌드박스 판 기계 검증** — 아카이브 안의 서명본(`build/ios/LazyMemo-macOS.xcarchive/Products/Applications/LazyMemo.app`, Apple Development + 진짜 entitlement)을 `LAZYMEMO_MENU=1` 로 두 번 띄웠다. 샌드박스 컨테이너에서 뜨고, 메모 폴더가 「iCloud Drive 의 LazyMemo 폴더」(ubiquity 컨테이너를 entitlement 로 찾음), 「iCloud 로 동기화 중」, 설정 메뉴에 Claude·업데이트 줄 없음, `settings.json` 에 `vaultPath` 가 컨테이너 Documents 로 적힘, 두 번째 기동도 같은 자리·같은 메모 수(1장). 첫 기동이 컨테이너가 비어 있어 환영 메모 「여기 적으면 됩니다」를 iCloud 에 한 장 만들었다 — 아이폰에도 갈 것이다.

## 검증

- xcodebuild 출력 `Upload succeeded` 둘, ASC 「빌드 추가」에 iOS 1(0.1.0)·macOS 0.4.0(1) 표시, 저장 뒤 사이드바가 「0.1.0 제출 준비 중」「0.4.0 제출 준비 중」.
- 사람 손이 남은 것 (`mac-sandbox-handtest` 의 나머지): 메모 폴더 옮기기 패널 → 북마크로 재시작 뒤 접근, ⌥⌘N 핫키, 달력 권한 대화상자, ⌥⌘L 위치, 로그인 항목, 창 복원. TestFlight 앱으로 설치해서 봐야 한다.

## 메모

- 사용자의 GitHub 판(`dist/LazyMemo.app`)이 떠 있는 채로 스토어 판을 잠깐 띄웠다 — 같은 번들 id 라 핫키가 잠깐 둘이었을 수 있다. 진단 모드라 1~2초 만에 스스로 꺼졌다.