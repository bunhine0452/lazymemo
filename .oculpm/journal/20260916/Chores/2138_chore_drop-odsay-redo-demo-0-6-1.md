---
schema_version: 1
type: chore
slug: "drop-odsay-redo-demo-0-6-1"
status: done
difficulty: low
created_at: "2026-09-16T21:38:35+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoPlaces/TransitRouter.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/RoutePlanner.swift"
    op: update
  - path: "Sources/LazyMemoPlaces/NaverWebRouter.swift"
    op: update
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: "ios/LazyMemo/RouteSettingsView.swift"
    op: update
  - path: "Tests/LazyMemoPlacesTests/ODsayRouterTests.swift"
    op: delete
  - path: "Tests/LazyMemoPlacesTests/PlaceLocatorTests.swift"
    op: create
  - path: "ios/LazyMemoUITests/DemoTests.swift"
    op: update
  - path: "ios/scripts/record-demo.sh"
    op: update
  - path: "site/media/route.mp4"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/PRIVACY.md"
    op: update
related:
  - ref: "20260916/Chores/2004_chore_release-0-6-0-route-demo.md"
    kind: "followup"
  - ref: "20260916/Errors/2117_error_ci-route-summary-race.md"
    kind: "followup"
tags:
  - "release"
  - "route"
  - "demo"
  - "site"
  - "mcp-tool"
---
[x] 0.6.1 — ODsay 를 완전히 뺐고, 시연 영상을 「자동 완성」 풍선 없이 다시 찍었다

사용자: 「자동 완성 풍선 없이 다시 찍고 랜딩페이지 업로드했어? 남은거 다해. odsay는 절대 안쓸거야.」

## 한 일

- **ODsay 제거**: `ODsayRouter`·`Settings.transitKey`·맥 메뉴의 키 항목과 알림창·폰 설정의 키 칸·en 표·시험·README·PRIVACY 에서 전부. `RouteFinder()` 는 네이버 → 택시뿐, `Services.find` 에서 키 인자를 뺐다. 옛 `settings.json` 에 `transitKey` 가 남아 있어도 Codable 이 모르는 키라 그냥 무시된다. 결정은 `NaverWebRouter` 머리말에 적어 뒀다 — 키가 필요한 다른 길찾기는 두지 않는다.
- **풍선의 정체**: 첫 프레임의 「자동 완성」은 편집 메뉴가 아니라, 시뮬레이터에 하드웨어 키보드가 물려 있을 때 iOS 가 글쇠판 대신 띄우는 AutoFill 풍선이었다(시트를 닫고 펜에 커서만 선 순간). `ready` 앞에서 한 글자 쳤다 지워 글쇠판을 올려 두니 사라졌다. 접촉 인쇄로 처음 5초·전체를 확인.
- **xcodebuild 멈춤**: 주행은 61초에 끝났는데 xcodebuild 가 결과 묶음을 마무리하다 8분을 매달렸다(첫 두 번은 안 그랬다). 녹화기에 먼저 SIGINT 를 줘 raw.mov 를 마무리시키고 `ready`/`done` 과 함께 건져 손으로 인코딩했다(시작은 raw.mov 의 생성 시각으로 어림, 1초 여유). 스크립트에 「`done` 뒤 90초 넘게 안 끝나면 끊고, 로그에 passed 가 있으면 성공으로」를 넣었다.
- 판 0.6.1: README 「이번 판」·Info.plist (7)·Version.swift. 태그 → release 워크플로, TestFlight 아이폰·맥 다시 업로드(키 칸이 빠진 판).

## 검증

- 전체 Swift 시험 통과(Places 19), l10n 검사(남은 7은 전부터), 아이폰 시뮬레이터 빌드 통과.
- 영상 42초: 빈 펜·글쇠판 → 적기 → 「어디서 출발하시나요?」 → 강남역 → 경로 6개 → 지하철 → 카드 → 배너 「18:12 출발 — 강남역에서 2호선 · 14분」 → 열림.