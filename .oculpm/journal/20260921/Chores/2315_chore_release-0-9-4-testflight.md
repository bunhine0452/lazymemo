---
schema_version: 1
type: chore
slug: "release-0-9-4-testflight"
status: done
difficulty: low
created_at: "2026-09-21T23:15:49+09:00"
session_id: "20260921-001"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "0b60d3b9-67f4-4690-9c09-74b70b505cd7"
language: "ko"
verified_by_user: false
files_touched:
  - path: "ios/LazyMemo.xcodeproj/project.pbxproj"
    op: update
  - path: "Sources/LazyMemoCore/Version.swift"
    op: update
  - path: "Resources/Info.plist"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/CHANGELOG.md"
    op: update
related:
  - ref: "20260919/Chores/0017_chore_release-0-9-3-link-cards-overflow.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1847_feature_phone-app-intents-write-today-pen.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1901_feature_widget-checkbox-writes-file.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1944_feature_tutorials-rewritten-phone-mac.md"
    kind: "followup"
  - ref: "20260921/Features_to_add/1945_feature_calendar-color-dots-glide-widget-circle.md"
    kind: "followup"
  - ref: "20260921/Bugs/1955_bug_capture-parks-instead-of-closing-with-answer.md"
    kind: "followup"
tags:
  - "release"
  - "testflight"
  - "mcp-tool"
---
[x] 0.9.4 TestFlight — 아이폰·맥 업로드

사용자: 「테스트플라이트에 이제 올려줘」 → 「맥 업로드 끝나면 커밋하고 정리해줘」.

## 한 일

- 판 번호 0.9.4 — `ios/LazyMemo.xcodeproj` 의 `MARKETING_VERSION`(여섯 자리 전부, 0.1.0 이던 것을 처음으로 실제 판으로), `Version.swift`, `Resources/Info.plist` 0.9.4 (21). README 「이번 판 — 0.9.4」(여섯 항목), 0.9.3 은 CHANGELOG 로.
- 폰 스모크 `SmokeTests`+`DeepLinkTests` 25/25 초록 뒤에 올렸다.
- 아이폰: 아카이브 → `Upload succeeded` (20:10). 맥: 아카이브는 됐으나 첫 업로드가 애플 쪽 -19235(「did not receive a response」)로 실패 → 같은 아카이브로 `-exportArchive` 만 다시 → `Upload succeeded` (23:15). dSYM 경고(추론 엔진 프레임워크의 심볼 없음)는 지난 판들과 같고 업로드에는 무관.
- GitHub 판(태그·릴리스)은 만들지 않았다 — 요청은 TestFlight 였다.

## 검증

- 두 플랫폼 모두 `** EXPORT SUCCEEDED **` 와 `Uploaded LazyMemo-iOS` / `Uploaded LazyMemo-macOS`. App Store Connect 처리 완료와 테스터 배포는 사용자가 ASC 에서 확인.

## 메모

- `build/ios`(277MB)와 홈의 `DerivedData/LazyMemo-*` 는 업로드 뒤 지웠다(용량 규칙 4). `MARKETING_VERSION` 이 0.1.0 이던 지난 업로드들은 ASC 의 자동 관리(`manageAppVersionAndBuildNumber`)가 판을 맞춰 준 것으로 보인다 — 이제 프로젝트가 실제 판을 든다.