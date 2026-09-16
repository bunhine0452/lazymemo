---
schema_version: 1
type: feature
slug: "ci-on-push-and-pr"
status: done
difficulty: low
created_at: "2026-09-16T15:22:43+09:00"
session_id: "20260916-001"
agent:
  id: "claude-code"
  version: "Opus 5"
  session: "e2e29a3b-7809-493c-a460-5c0ede2903ca"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/ci.yml"
    op: create
related: []
tags:
  - "ci"
  - "github-actions"
  - "tests"
  - "safety-net"
  - "mcp-tool"
---
[x] 밀 때마다 시험한다 — push·PR CI

## 추가 기능

`.github/workflows/ci.yml`. 지금까지 워크플로는 `release.yml`(태그)·`pages.yml`(site) 둘이라, 태그를 밀기 전까지 빨간 것이 며칠 쌓일 수 있었다 — 여러 세션이 한 워킹트리에서 번갈아 커밋하는 지금 특히. 단위 테스트만이 릴리스의 문지기라는 README 의 말 그대로, 그 문지기를 커밋마다 세운다.

- **트리거**: `push`(main)·`pull_request`·`workflow_dispatch`. `.oculpm/**`·`docs/**`·`site/**`·`**.md`·다른 워크플로만 바뀐 커밋은 건너뛴다 — 일지 커밋마다 러너를 깨우지 않는다.
- **러너**: `macos-26` (플랫폼 목표가 macOS 26 이라 그 아래에서는 컴파일이 안 된다 — release.yml 과 같은 이유), 40분 상한.
- **동시성**: `ci-${{ github.ref }}`, 앞 것 취소.
- **캐시 둘**: `~/Library/Caches/org.swift.swiftpm`(LiteRT-LM xcframework zip 128MB — `Package.swift` 해시 키) · `.build`(Package.swift+Sources+Tests 해시 키, restore-keys 로 가까운 것 복원). 키가 어긋나면 전체 빌드일 뿐 틀린 결과가 나오는 길은 없다.
- **한 단계**: `./scripts/test.sh` — `LAZYMEMO_LANGUAGE=ko` 고정과 swift-testing rpath 처리가 그 안에 있다.

## 동작 흐름

push → paths-ignore 판정 → checkout → 캐시 복원 → `scripts/test.sh`(debug 빌드 + 5개 테스트 번들) → 실패면 빨간 체크. 태그 릴리스는 그대로 `release.yml` 이 다시 시험한다 — 두 번 도는 것이 맞다, 릴리스는 캐시 없이 처음부터.

## 검증

- YAML 파싱(ruby psych): jobs `test`, on `push,pull_request,workflow_dispatch`, steps 5.
- 같은 명령을 로컬에서: `./scripts/test.sh` → 5개 번들 **829 tests passed**(324+12+1+451+41), 실패 0. 오늘 고친 `Package.swift`(LiteRTLM product 추가)도 이 빌드를 지났다.
- **워크플로 자체는 아직 돌지 않았다** — main 에 밀린 뒤 첫 실행을 봐야 한다. 러너의 Xcode 판이 Swift 6.2 미만이면 첫 실행이 빨갈 수 있다(release.yml 이 같은 러너에서 통과했으므로 가능성은 낮다).