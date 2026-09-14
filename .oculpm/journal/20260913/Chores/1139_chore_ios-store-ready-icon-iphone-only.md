---
schema_version: 1
type: chore
slug: "ios-store-ready-icon-iphone-only"
status: done
difficulty: low
created_at: "2026-09-13T11:39:11+09:00"
session_id: "20260913-006"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "7d904f0c-cded-40c1-b256-64c6cdc0ba13"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/make-icon.swift"
    op: update
  - path: "scripts/make-icon.sh"
    op: update
  - path: "ios/LazyMemo/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    op: create
  - path: "ios/LazyMemo/Assets.xcassets/AppIcon.appiconset/Contents.json"
    op: update
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "ios/Config/Info.plist"
    op: update
  - path: "site/privacy/index.html"
    op: create
  - path: "site/index.html"
    op: update
  - path: "site/ko/index.html"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
related: []
tags:
  - "ios"
  - "app-store"
  - "icon"
  - "privacy"
  - "mcp-tool"
---
[x] 아이폰 앱을 스토어용으로 다듬는다 — 아이콘·아이폰 전용·암호화 면제·개인정보 페이지

## 한 것

- **앱 아이콘이 없었다.** `AppIcon.appiconset/Contents.json` 에 1024 슬롯만 있고 그림이 없었다 — App Store 업로드가 거절하는 첫 번째 것. `make-icon.swift --ios` 를 더해 맥과 같은 그림을 **알파 없이**(`noneSkipLast`) 1024 로 렌더한다. iOS 아이콘은 알파가 있으면 검증에서 떨어진다. `make-icon.sh` 가 이 단계와 무손실 재압축(214KB→121KB)까지 같이 돈다.
- **아이폰 전용.** `TARGETED_DEVICE_FAMILY = 1` (앱·공유 확장·UI 테스트 전부) + iPad 방향 키 제거. 아이패드 스크린샷·레이아웃 심사를 첫 출시에서 뺀다 (사용자 결정).
- `ITSAppUsesNonExemptEncryption = false` — HTTPS 뿐이라 면제. 없으면 업로드마다 ASC 가 묻는다.
- 위치 사용 문구를 README 프라이버시 절과 같은 말로 (한 번 읽고 끊는다).
- `site/privacy/index.html` — docs/PRIVACY.md 를 ko·en 한 페이지로. 소개 페이지의 토큰만 가져왔고 바깥 요청은 없다 (Pages 워크플로의 grep 검사를 로컬에서 같은 식으로 통과). 두 소개 페이지 푸터에 링크. 맥 App Store 판에는 Claude 연동·새 판 확인이 없다는 줄을 표에 적었다 — 다음 작업(샌드박스 판)이 그것을 참이 되게 한다.

## 검증

`xcodebuild build` (iPhone 17 시뮬레이터) 통과. 산출물 Info.plist 에 `ITSAppUsesNonExemptEncryption=false`, `AppIcon60x60@2x.png` 이 번들에 들어 있음. `sips -g hasAlpha` → no.