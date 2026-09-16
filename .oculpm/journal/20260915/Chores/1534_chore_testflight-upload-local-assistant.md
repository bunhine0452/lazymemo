---
schema_version: 1
type: chore
slug: "testflight-upload-local-assistant"
status: done
difficulty: low
created_at: "2026-09-15T15:34:31+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Features_to_add/1528_feature_assistant-ui-mac-ios-wiring.md"
    kind: "followup"
  - ref: "20260915/Chores/0308_chore_testflight-upload-recall-polish.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "jarvis"
  - "mcp-tool"
---
[x] 0803af3 을 아이폰·맥 TestFlight 에 올렸다 — 이 기기의 비서(모델 받기·묻기·시키기·오늘·다듬기) 판

사용자 지시(「플랜 다 만들고 TestFlight 에 올려 두면 테스트해 보고 알려줄게」)로 내 변경만 명시 경로·hunk 단위로 stage 해 커밋(`0803af3`)한 뒤 `ios/scripts/archive.sh` → `archive.sh mac` 을 돌렸다. 다른 세션의 미커밋 변경(Words/l10n·planner 등)은 워킹트리에 그대로 두었고 아카이브에는 포함된다.

## 검증
- iOS: `** EXPORT SUCCEEDED **`, `Upload succeeded` (15:32). 경고: `CLiteRTLM.framework` 의 dSYM 없음 — Google 배포 xcframework 에 심볼이 없어서다. 크래시 심볼화만 그 프레임워크 안에서 안 된다.
- 맥: `** EXPORT SUCCEEDED **`, `Upload succeeded` (15:34). 같은 경고(`libCLiteRTLM_mac.dylib`).
- ASC 처리는 곧 「테스트 준비 완료」로 바뀐다. 버전 문자열 0.1.0, 빌드 번호는 ASC 가 올림.

## 실기기에서 볼 것 (사용자)
1. 폰 목록 위 ✦ → 「받기」: 크기(2.59GB) 안내 → 진행 → Wi-Fi 끊고 다시 켰을 때 이어받기 → 확인 중 → 준비. 저장 공간 부족 문구.
2. 「치과 언제였지?」 같은 묻기 — 첫 답까지 시간, 근거 칩을 눌러 메모가 열리는지, 없는 것을 물으면 「찾지 못했습니다」.
3. 메모 열고 ✦ 「이 메모에게 시키기」 → 「금요일 10시에 다시 알려줘」 → 제안 문장에 시각이 맞는지 → 적용 → 다시 보기 알림이 그 시각에 오는지 → 되돌리기.
4. 「오늘」 → 최대 셋, 완료·휴지통 제외. 「지금」 띠 순서가 그대로인지.
5. 폰을 잠그거나 다른 앱으로 갔다 와도 앱이 죽지 않는지(jetsam), 15분 반복 뒤 발열.
6. 맥: 메뉴 「메모에게 묻기…」, 종이 ✧ 가 App Store 판에서 모델로 다듬는지, 모델 지우기.