---
schema_version: 1
type: chore
slug: "testflight-upload-assistant-quality"
status: done
difficulty: low
created_at: "2026-09-15T21:30:43+09:00"
session_id: "20260915-003"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "abd8e9f2-901d-480a-ac98-0cda5003a73a"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Features_to_add/2117_feature_assistant-retrieval-resolver-quality.md"
    kind: "followup"
  - ref: "20260915/Chores/1534_chore_testflight-upload-local-assistant.md"
    kind: "followup"
tags:
  - "testflight"
  - "release"
  - "ios"
  - "mac"
  - "jarvis"
  - "mcp-tool"
---
[x] 3f24393 을 아이폰·맥 TestFlight 에 올렸다

사용자 지시(「굿 좋아 업데이트해줘」)로 이번 세션의 변경만 명시 경로로 커밋(`3f24393`)한 뒤 `ios/scripts/archive.sh` → `archive.sh mac`. 다른 세션의 미커밋 변경(Words/l10n·planner 등)은 워킹트리에 그대로 두었고 아카이브에는 포함된다. 푸시는 하지 않았다(origin/main 보다 2개 앞: 0803af3·3f24393).

## 검증
- 첫 시도는 둘 다 실패 — Xcode 가 27.0(27A266a)으로 올라가 있었고 새 라이선스 미동의. 사용자가 `sudo xcodebuild -license accept` 로 동의한 뒤 재실행.
- iOS: `** ARCHIVE SUCCEEDED **` → `Upload succeeded` (21:28). 맥: `** ARCHIVE SUCCEEDED **` → `Upload succeeded` (21:30).
- 경고: DVTCoreDeviceCore 플러그인 로드 실패·CoreSimulator 구판(1051 < 1171) — Xcode 27 과 OS 의 CoreSimulator 가 안 맞는다. 아카이브·업로드에는 영향 없었지만 실기기 연결·시뮬레이터 실행은 Xcode 27 첫 실행(추가 구성 요소 설치)이 필요할 수 있다.

## 실기기에서 볼 것 (사용자)
1. 폰: 모델을 받지 않은 채 메모 열고 ✦ → 「금요일 오전 10시에 다시 알려줘」 → 즉시 제안(모델 없이) → 적용 → 되돌리기.
2. 폰·맥: 「치과 언제였지?」처럼 자기 말로 묻기 → 답 밑에 메모 원문 줄·근거 칩. 없는 것을 물으면 「찾지 못했습니다」+관련 메모.
3. 열린 메모 없이 「지수 메모 지워」 → 후보 칩이 뜨고 하나를 고르면 그 메모에게 다시 묻는다.
4. 맥: 종이 우클릭 「이 메모에게 시키기…」.