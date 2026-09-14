---
schema_version: 1
type: chore
slug: "testflight-internal-group-and-handoff"
status: done
difficulty: low
created_at: "2026-09-14T19:15:27+09:00"
session_id: "20260914-003"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "176355c0-cdd8-46c9-b761-50bec054636d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "docs/APP_STORE_READINESS.md"
    op: update
related:
  - ref: "20260914/Chores/1814_chore_testflight-upload-both-platforms.md"
    kind: "followup"
  - ref: "20260914/Chores/1753_chore_asc-record-and-metadata.md"
    kind: "followup"
tags:
  - "app-store"
  - "testflight"
  - "handoff"
  - "mcp-tool"
---
[x] TestFlight 내부 그룹을 만들고 사용자를 테스터로 넣었다 — 두 빌드 「테스트 준비 완료」. 사용자가 「TestFlight 먼저, 제출은 손검증 뒤」로 정했다.

## 한 것

- ASC › TestFlight › 내부 테스팅 ＋ → 그룹 **「lazymemo internal」** (자동 배포 켬 — Xcode 로 올리는 빌드가 그룹에 바로 들어간다). 테스터 1명(계정 소유자 본인) 추가 → 「초대됨」. 그룹 빌드 탭에 iOS 0.1.0 (1)·macOS 0.4.0 (1) 둘 다 「테스트 준비 완료」.
- 내부 그룹엔 공개 링크가 없다 — 초대 메일의 「TestFlight 에서 보기」 또는 같은 Apple ID 의 TestFlight 앱에서 바로 보인다. 사용자가 링크를 물어 그렇게 답했다.
- `docs/APP_STORE_READINESS.md` 에 TestFlight 손검증 체크리스트(맥 9·아이폰 5)를 적었다 — 기계로 본 것과 사람 손이 남은 것을 갈랐다.

## 다음 세션이 이어받을 자리

**상태 한 줄:** ASC 는 빌드까지 붙어 두 버전 페이지 모두 「심사에 추가」 버튼이 활성이다. 누르지 않은 이유는 사용자가 TestFlight 손검증을 먼저 하기로 해서다.

1. 사용자가 손검증을 마치고 「제출해」라고 하면 — ASC 앱 6811815255 의 iOS 0.1.0 / macOS 0.4.0 버전 페이지에서 「심사에 추가」 → 심사 제출 흐름. 플랜 `asc-submit`.
2. 손검증에서 결함이 나오면 그것부터 고치고, 빌드 번호를 올려 다시 `./ios/scripts/archive.sh` / `archive.sh mac` (Xcode 로그인 상태면 그대로 돈다. 맥은 이 맥이 이미 기기로 등록돼 있어 `build` 선행이 필요 없다). 자동 배포라 그룹에 바로 들어간다. 새 빌드는 버전 페이지 「빌드」에서 갈아 끼운다.
3. 첫 기동이 iCloud 컨테이너에 환영 메모 한 장(「여기 적으면 됩니다」)을 만들어 뒀다 — 아이폰에도 보인다. 지워도 된다.
4. 심사 연락처 전화번호는 사용자가 직접 넣었다. 영어 로컬라이제이션은 안 넣었다(필수 아님) — 원고는 `docs/STORE_LISTING.md` 「영어」 절.
5. 브라우저 자동화 요령은 `1753_chore_asc-record-and-metadata.md` 의 「부딪힌 것」 — 폼은 native setter+input 이벤트, 스크린샷은 한 장씩, 홍보 문구에 `⌥⌘` 금지.

## 검증

- 그룹 빌드 탭 스크린샷으로 두 빌드 「테스트 준비 완료」 확인. 테스터 행 「초대됨」.
- 사람 손 확인 남음: TestFlight 앱에 실제로 뜨는지, 초대 메일 도착.