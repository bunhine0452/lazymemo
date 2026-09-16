---
schema_version: 1
type: chore
slug: "footprint-diet-7gb-to-80mb"
status: done
difficulty: low
created_at: "2026-09-16T14:57:07+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Package.swift"
    op: update
  - path: "spikes/LiteRTSpike/Package.swift"
    op: update
  - path: "spikes/README.md"
    op: update
  - path: "scripts/clean.sh"
    op: update
  - path: "README.md"
    op: update
  - path: "spikes/LiteRTSpike/.build"
    op: delete
  - path: ".build"
    op: delete
  - path: "build"
    op: delete
related:
  - ref: "20260915/Features_to_add/1518_feature_model-download-store-litert-provider.md"
    kind: "followup"
  - ref: "20260915/Features_to_add/1454_feature_litert-spike-fixtures-bench-runner.md"
    kind: "followup"
tags:
  - "footprint"
  - "spike"
  - "clean"
  - "swiftpm"
  - "litert"
  - "mcp-tool"
---
[x] 프로젝트 용량 다이어트 — 7.1GB → 82MB

## 실측 (2026-09-16, 지우기 전)

| 어디 | 크기 | 정체 |
|---|---|---|
| `spikes/LiteRTSpike/.build` | 3.6GB | `.package(url: LiteRT-LM.git, exact: 0.16.0)` 이 저장소를 통째로 클론 — `repositories/` 2.7GB(모델 자산이 git 에 있다) + `checkouts/` 539MB + artifacts 220MB + 산출물 205MB |
| `.build` | 3.1GB | `out/` 920MB · `ios/` 895MB(시뮬레이터 derived data) · `arm64-apple-macosx/` 797MB(debug 577·release 221) · `xc-mac/` 328MB · `artifacts/` 220MB |
| `build/` | 261MB | TestFlight 업로드가 끝난 xcarchive 239MB + render-ui PNG 22MB |
| `~/Library/Developer/Xcode/DerivedData/LazyMemo-*` | 1.0GB | 프로젝트 밖, 이 프로젝트 것 |
| 소스·문서·git·.oculpm | 81MB | 남는 것 |

`libCLiteRTLM_mac.dylib`(136MB, x86_64 75MB + arm64 68MB fat)이 build 디렉터리마다 복제돼 아홉 벌 있었다.

## 한 것

1. **지웠다** — 위 파생물 전부. 프로젝트 7,284MB → 81MB, DerivedData 1.0GB 별도. 지우기 전 `swift-build`·`swift-frontend`·`xcodebuild` 프로세스가 없는지 확인했다(여러 세션이 한 워킹트리를 쓴다). `pgrep -f` 는 자기 셸의 명령줄에 걸려 거짓 양성이 나므로 `pgrep -x` 로 이름만 본다.
2. **spike 가 다시 2.7GB 를 받지 않게** — 제품 패키지가 9/15 에 내린 결정(래퍼 소스 vendoring, `Sources/LiteRTLM/README.md`)을 spike 에도 적용했다. 루트 `Package.swift` 에 `.library(name: "LiteRTLM")` product 를 열고, `spikes/LiteRTSpike/Package.swift` 는 `.package(name: "LazyMemo", path: "../..")` 로 그것을 빌린다. 루트 최소 판이 macOS 26 이라 spike 의 `platforms` 도 `.macOS("26.0")`(문자열 — tools 5.10 에 `.v26` 이 없다)로 올렸다. 의존 방향은 spike → 루트 한쪽이라 제품 타깃은 여전히 spike 를 모른다. 결과: spike `.build` 3.6GB → 423MB, `repositories/` 0B, 빌드 7초.
3. **`scripts/clean.sh`** — `--all` 이 `.build`·`build`·`dist`·`spikes/*/.build`·Xcode DerivedData(Xcode 가 닫혀 있을 때만)까지 안다. 기본은 `ModuleCache*`·`index` 만. 다른 세션의 빌드 프로세스가 있으면 지우지 않고 멈춘다. 없는 대상은 목록에 싣지 않는다.
4. **README 「개발」절** — 무엇이 어디에 얼마나 쌓이는지 표와 `clean.sh` 의 두 모드, 가중치 캐시(`~/Library/Caches/lazymemo-models` 3.2GB)는 지우지 않는다는 것.

## 알게 된 것

- `.build/out`·`.build/xc-mac` 은 xcodebuild 잔재가 아니라 **Swift 6.2 `swift build` 의 자기 자리**다 — spike 를 새로 빌드하자 `out/` 이 생겼다. 플랜 항목 `#main-build` 의 「xcodebuild 잔재」 표현은 틀렸고, clean.sh 주석과 README 는 맞게 적었다.
- 작업 중 다른 세션이 `.build/ios` 를 두 번 다시 만들었다(iOS 시뮬레이터 빌드). 가드가 한 번 실제로 걸려 멈췄고, 끝난 뒤 지웠다 — 그 세션의 다음 xcodebuild 는 전체 빌드다.
- **`build-app.sh` 가 dylib 을 번들에 넣지 않는다.** `LazyMemo` 실행 파일이 `@rpath/libCLiteRTLM_mac.dylib`(rpath `@loader_path`)를 링크하는데 `dist/LazyMemo.app/Contents/MacOS/` 에는 실행 파일·mcp 만 복사한다. v0.4.0(9/13) 은 LiteRT 이전이라 무사했고, **다음 GitHub 판은 켜지지 않을 것**이다. 번들에 넣으면 3.6MB → 68MB(arm64 thin) 또는 136MB(fat). 결정 항목으로 플랜 `#bundle-dylib` 에 남겼다.

## 검증

- `swift package dump-package` 의 products 에 `LiteRTLM` 이 있다.
- `cd spikes/LiteRTSpike && swift build -c release` → Build complete (6.8s), `.build/repositories` 0B, `litert-spike --help` 종료 0.
- `./scripts/clean.sh` / `--all` / 빈 상태 세 번 — 각각 캐시만 · 전부 · 「지울 것이 없습니다」. 가드는 다른 세션의 xcodebuild 에 실제로 한 번 걸려 멈췼다.