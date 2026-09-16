---
schema_version: 1
type: bug
slug: "bundle-litert-engine-dylib"
status: done
difficulty: medium
created_at: "2026-09-16T16:13:26+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/build-app.sh"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260916/Chores/1457_chore_footprint-diet-7gb-to-80mb.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/1518_feature_model-download-store-litert-provider.md"
    kind: "followup"
tags:
  - "release"
  - "build-app"
  - "litert"
  - "dylib"
  - "rpath"
  - "bundle-size"
  - "mcp-tool"
---
[x] GitHub 판 번들에 추론 엔진이 없었다

## 발생 원인

9/15 에 `LazyMemoUI → LazyMemoAssistantUI → LazyMemoLocalLiteRT → LiteRTLM → CLiteRTLM_mac(binaryTarget, dylib)` 의존이 들어오면서 `LazyMemo` 실행 파일이 `@rpath/libCLiteRTLM_mac.dylib` 을 링크하게 됐다(`otool -L`). `scripts/build-app.sh` 는 실행 파일 둘·plist·아이콘·번들·lproj 만 복사하므로 `dist/LazyMemo.app` 안에 그 dylib 이 없다 — dyld 가 「Library not loaded」로 즉시 죽는다. v0.4.0(9/13)은 LiteRT 이전이라 무사했고, **다음 태그가 첫 사고**였다. 스토어 판은 Xcode 가 xcframework 를 알아서 넣어 문제가 없었다.

세 갈래를 재고 **번들에 넣기**로 정했다(사용자: 「네가 판단해」):
- (b) GitHub 판에서 로컬 비서를 빼기 — GitHub 판이 1차 배포 경로인데 진행 중인 핵심 기능을 거기서 빼는 것은 거꾸로다.
- (c) 엔진도 모델처럼 나중에 받기 — `LiteRTLM` 이 C 심볼을 링크 시점에 묶어 `dlopen`+약한 링크로 다 갈아야 하고, 강화된 런타임에서 다른 팀 서명 dylib 을 열려면 library-validation 을 꺼야 한다. 크고 약하다.
- (a) 넣기 — 실행 파일이 이미 arm64 전용(`swift build` 는 호스트 아키텍처)이라 dylib 도 arm64 만 남기면 된다. 136MB → 65MB.

## 해결 방법

`build-app.sh`: 실행 파일 복사 뒤 `$BIN_PATH/libCLiteRTLM_mac.dylib` 을 `lipo -thin <실행 파일의 arch>` 로 `Contents/Frameworks/` 에 넣고, `install_name_tool -add_rpath @loader_path/../Frameworks` 를 **서명 앞에서** 적는다(실행 파일이 여러 arch 면 그대로 복사). 서명은 안에 든 것부터 — ad-hoc 도 Developer ID 도 엔진을 우리 서명으로 다시 찍는다(강화된 런타임은 다른 팀의 라이브러리를 열어 주지 않는다). 엔진이 없으면 `::warning` 을 내고 계속한다.

README 「설치」의 크기 문단을 고쳤다: 번들 70MB · zip 23MB, 그중 65MB 가 엔진, 모델 2.6GB 는 번들 밖.

## 검증

- `./scripts/build-app.sh release` → 「엔진 포함: libCLiteRTLM_mac.dylib (arm64, 65M)」, `otool -l` 에 `@loader_path/../Frameworks`, `lipo -archs` arm64, `codesign --verify --deep --strict` ✓, 번들 안 dylib 을 `ctypes.CDLL` 로 열어 의존성 결손 없음 확인.
- `LAZYMEMO_SIGN_IDENTITY="Developer ID Application: …"` 로 다시 → 앱·mcp·dylib 셋이 같은 TeamIdentifier, `flags=runtime`, deep-strict ✓, `spctl` 은 「Unnotarized Developer ID」로 거절 — 공증 전이라 맞는 답.
- `./scripts/package-release.sh` → zip 23MB, 풀어서 서명 재검사 ✓.
- **앱을 실제로 띄우지는 않았다** — 지금 도는 lazymemo 와 같은 vault·핫키를 두고 두 벌이 뜬다. 띄워서 비서까지 확인하는 것은 사용자 손검증으로 남긴다.