---
schema_version: 1
type: chore
slug: "jarvis-device-toolchain-check"
status: done
difficulty: low
created_at: "2026-09-15T14:48:15+09:00"
session_id: "20260915-002"
agent:
  id: "claude-code"
  version: "Fable 5.1"
  session: "2161e740-75c7-4cd1-a227-03f70e026276"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20260915/Chores/1421_chore_jarvis-local-models-handoff.md"
    kind: "followup"
tags:
  - "jarvis"
  - "litert"
  - "toolchain"
  - "capacity"
  - "mcp-tool"
---
[x] 자비스 검증 환경 확인 — Xcode 26.6 만 설치, iPhone·M1 미연결, 가중치는 저장소 밖 캐시에 파일 하나

## 확인한 것 (명세 §0 `#device-toolchain`)

| 항목 | 결과 |
|---|---|
| 개발 Mac | Mac16,8 (M4 Pro) · 24GB · macOS 27.0 (26A428) · 디스크 여유 약 87GB |
| Xcode | **26.6 (17F113)** 만 설치. SDK iOS 26.5 / macOS 26.5. **Xcode 27 없음** — 설치·전환은 사용자 결정, 임의 실행하지 않음 |
| iPhone 15 Pro | `devicectl list devices` 결과 없음 — 연결 안 됨. iOS 버전·저장 공간 미측정 |
| M1 8GB Mac | 이 세션에서 접근 불가. M4 수치로 대체하지 않는다 |
| LiteRT-LM v0.16.0 | Package.swift 최소 iOS 15 / macOS 12 → Xcode 26.6 으로 spike 빌드 가능. OS27 전환은 `#sandbox-release` 의 별도 항목 |
| 저장소 상태 | 다른 세션의 미커밋 변경 41건. `spikes/**`·`Tests/Fixtures/Assistant/**`·`docs/research/local-model-benchmark-*.md`·`.gitignore` 만 claim |

## 가중치 — 용량 규칙

사용자 지시 「용량 주의」에 따라 HF 저장소(27.3GB) snapshot 대신 **파일 하나**만 받았다.

- `~/Library/Caches/lazymemo-models/gemma-4-E2B-it.litertlm` · revision `b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1` · 2,588,147,712 bytes
- SHA256 `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c` (HF LFS etag 와 일치, 로컬 shasum 으로 확인)
- vault·iCloud 밖. 지우려면 폴더 삭제.
- Qwen/MLX 가중치(2.3GB)는 받지 않았다 — 비교 필요 시 `spikes/MLXSpike/README.md` 의 명령으로.
- SwiftPM 이 LiteRT-LM git 미러를 `~/Library/Caches/org.swift.swiftpm` 에 2.7GB 만들었다 (checkout 539MB · xcframework 220MB 별도). 정리 후보.

## 검증

- `xcodebuild -version`, `xcrun devicectl list devices`, `df -h`, `sysctl hw.model hw.memsize` 출력으로 확인.
- 가중치 SHA256 은 다운로드 뒤 `shasum -a 256` 으로 대조.