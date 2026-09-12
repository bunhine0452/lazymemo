---
schema_version: 1
type: chore
slug: "icloud-ios-docs-and-privacy"
status: done
difficulty: low
created_at: "2026-09-13T03:18:59+09:00"
session_id: "20260913-002"
agent:
  id: "claude-code"
  session: "ebbbba2e-b348-4963-bb3b-0672d4d7dd12"
language: "ko"
verified_by_user: false
files_touched:
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "docs/PRIVACY.md"
    op: create
related:
  - ref: "20260913/Features_to_add/0239_feature_mac-icloud-sync-and-developer-id.md"
    kind: "followup"
  - ref: "20260913/Features_to_add/0314_feature_phone-here-pin.md"
    kind: "followup"
tags:
  - "docs"
  - "privacy"
  - "icloud"
  - "ios"
  - "mcp-tool"
---
[x] README·DESIGN 에 iCloud 컨테이너와 아이폰 앱을 적고, 개인정보 처리방침 초안을 쓴다

- **README** — 「메모는 어디에 있나」에 「iCloud 로 동기화…」와 「LazyMemo」 폴더, 「아이폰 — 같은 폴더를 보는 앱」 절 신설(종이도 서랍도 없다·펜·무더기·달력·공유 시트·핀, 화면 규칙은 MOBILE_DESIGN.md), 단축어 절은 「앱 없이」 대안으로 남김. 프라이버시 표에 **iCloud 로 동기화**(메모 파일 전부, 당신의 iCloud 로, 직접 누를 때만) 한 줄 — 「본문이 나가는 길은 넷, 셋은 Claude 로 하나는 iCloud 로」. 공증 문단에 Developer ID 경로가 이미 있다는 괄호.
- **DESIGN §5.1** — 「아이폰과 같은 폴더 — iCloud 컨테이너」 문단: planCloud → merge, 폰의 자리 차례, 플레이스홀더, ConflictSettlement, NSFileCoordinator 를 안 쓰는 이유. **§12.2** 에 build-app.sh 의 서명 셋. **§13** 미결에 공증 자격·프로필과 실기기 왕복.
- **docs/PRIVACY.md** (한·영) — README 표를 기준으로 무엇이 어디로 가는지, 권한 넷, 저장 자리, App Store Connect 「앱 개인정보」 응답 초안(Data Not Collected — 개발자에게 오는 것이 없다; 위치는 애플 지오코딩에만 좌표, 메모는 사용자의 iCloud). **제출 전 사용자가 확인할 것.** `site/` 에 얹어 URL 을 만드는 일은 TestFlight 때.

## 검증

문서라 읽어서 봤다. README 의 표·링크 앵커(`docs/MOBILE_DESIGN.md`, `#프라이버시`)가 존재한다.