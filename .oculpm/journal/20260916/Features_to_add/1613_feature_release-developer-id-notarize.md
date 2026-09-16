---
schema_version: 1
type: feature
slug: "release-developer-id-notarize"
status: done
difficulty: medium
created_at: "2026-09-16T16:13:55+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/release.yml"
    op: update
  - path: "scripts/build-app.sh"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Bugs/1613_bug_bundle-litert-engine-dylib.md"
    kind: "followup"
tags:
  - "release"
  - "notarization"
  - "developer-id"
  - "github-actions"
  - "codesign"
  - "mcp-tool"
---
[x] 릴리스 워크플로에 서명·공증 길

## 추가 기능

- **`build-app.sh`** — 공증 자격을 둘 중 하나로 받는다: `LAZYMEMO_NOTARY_PROFILE`(키체인 프로필, 지금까지) 또는 `LAZYMEMO_NOTARY_KEY`(.p8)+`_KEY_ID`+`_ISSUER`(App Store Connect API 키 — 키체인이 없는 CI 의 길). 서명은 됐는데 자격이 없으면 「서명만 했습니다 — 검역 딱지가 남습니다」라고 적는다. 공증 거절은 `--wait` 가 0 아닌 코드로 끝나 그 자리에서 멈춘다 — 거절된 것을 미공증처럼 내보내면 「공증했다」가 거짓이 된다.
- **`release.yml`** — 새 단계 「서명 준비」: 시크릿 다섯(`DEVELOPER_ID_P12`·`_PASSWORD`·`NOTARY_KEY_P8`·`NOTARY_KEY_ID`·`NOTARY_ISSUER_ID`)이 **전부** 있을 때만. 임시 키체인을 만들어 .p12 를 들이고 partition list 를 열고 검색 목록에 넣은 뒤, 인증서 이름을 `security find-identity` 로 읽어 `LAZYMEMO_SIGN_IDENTITY` 로 넘긴다(.p8 은 base64 든 원문이든 받는다). 선택 `DEVELOPER_ID_PROFILE` 이 있으면 iCloud entitlement 용 프로필도. 「묶기」가 요약에 ✅ 공증 / ⚠️ 미공증 을 적고, 마지막 「서명 자취 지우기」(`always()`)가 키체인과 키 파일을 지운다.
- **README** — 「설치」의 미공증 문단을 지금 상태(파이프라인은 있고 첫 공증 판은 아직)로 고치고, 「배포」에 시크릿 표와 로컬 명령을 적었다.

## 동작 흐름

태그 push → 시험 → (시크릿 있으면) 서명 준비 → `package-release.sh` → `build-app.sh` 가 엔진·mcp·앱을 Developer ID·강화된 런타임·타임스탬프로 서명 → `notarytool submit --wait` → `stapler staple` → `spctl` 확인 → ditto zip(스테이플 포함) → 릴리스·탭 갱신 → 키체인 삭제. 시크릿이 없으면 「서명 준비」를 건너뛰고 지금과 같은 ad-hoc 판.

## 검증

- 워크플로 YAML 파싱 ✓, 모든 `run` 블록 `bash -n` ✓.
- 로컬에서 Developer ID 서명 경로 실행(이 맥에 인증서가 있다): 앱·mcp·dylib 셋이 TeamIdentifier BP57Z7L498·`flags=runtime`, `codesign --verify --deep --strict` ✓, `spctl` 「Unnotarized Developer ID」 — 공증 전 기대값.
- **공증 자체는 돌리지 않았다** — 이 맥에 notarytool 자격(프로필·API 키)이 없고, Apple 에 올리는 일은 사용자 몫이다. 시크릿을 넣고 다음 태그를 밀면 첫 공증 판이 나간다. 그 뒤 할 일: 홈브루 탭 cask 의 검역 딱지 떼기 삭제(다른 저장소), README 「설치」 미공증 문단 삭제, homebrew-core 검토.