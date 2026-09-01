---
schema_version: 1
type: feature
slug: "in-app-update"
status: done
difficulty: high
created_at: "2026-08-31T16:29:50+09:00"
session_id: "20260831-004"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Sources/LazyMemoCore/Model/SemanticVersion.swift"
    op: create
  - path: "Sources/LazyMemoCore/Update/UpdateCheck.swift"
    op: create
  - path: "Sources/LazyMemoCore/Update/InstallSource.swift"
    op: create
  - path: "Sources/LazyMemoCore/Update/UpdateInstaller.swift"
    op: create
  - path: "Sources/LazyMemoUI/Update/Updater.swift"
    op: create
  - path: "Sources/LazyMemoCore/Storage/SettingsStore.swift"
    op: update
  - path: "Sources/LazyMemoUI/MenuBar/MenuBarController.swift"
    op: update
  - path: ".github/workflows/release.yml"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/DESIGN.md"
    op: update
  - path: "Tests/LazyMemoCoreTests/SemanticVersionTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/UpdateCheckTests.swift"
    op: create
  - path: "Tests/LazyMemoCoreTests/UpdateInstallerTests.swift"
    op: create
  - path: "Tests/LazyMemoUITests/UpdaterTests.swift"
    op: create
related:
  - ref: "20260831/Features_to_add/1617_feature_place-ink-on-paper-and-calendar.md"
    kind: "followup"
tags:
  - "update"
  - "release"
  - "privacy"
  - "plan:lazymemo-v2-surface-place"
  - "mcp-tool"
---
[x] 앱 안에서 판 바꾸기 — 확인·검증 셋·되돌릴 수 있는 자리 바꾸기

사용자 요청. 배포는 태그 하나로 도는데(§12.3) **받는 쪽만 손이었다** — 브라우저로 릴리스에 가서 zip 을 받아 풀고 `/Applications` 에 끌어다 놓기. 게으르다를 전제로 한 앱이 그 절차를 남겨 둘 이유가 없다. 플랜에 6단계 `{#p6-update}` 를 더하고 7항목을 전부 끝냈다.

## 추가 기능

**설치 경로에 따라 하는 일이 다르다** (`InstallSource`).

| 어떻게 깔렸나 | 누가 바꾸나 |
|---|---|
| 손으로 받았거나 소스에서 지었다 | 앱이 스스로 바꾼다 |
| Homebrew cask | brew 가 바꾼다 — 앱은 명령을 클립보드에 넣어 준다 |
| `swift run` | 아무것도 하지 않는다 (바꿀 번들이 없다) |

brew 의 앱을 앱이 바꾸면 **Caskroom 의 장부가 어긋난다** — 옛 판이 적힌 채 남아 다음 `brew upgrade` 가 이미 새 판인 자리를 덮거나 checksum 이 안 맞는다고 멈춘다. 다만 «brew 가 깔려 있다» 만으로는 부족해서, **이 번들이 brew 가 놓은 자리에 있을 때**만 brew 에 미룬다 — 손으로 받아 다른 데 둔 앱까지 미루면 그 사람은 영영 업데이트를 못 받는다.

**검사가 셋인 이유는 공증이 없기 때문이다** (§12.2). 공증된 앱이면 Gatekeeper 가 대신 봐 주지만 여기엔 그 그물이 없어서 우리가 친다 — ① 릴리스에 함께 올린 `.zip.sha256` 대조(받다 만 파일), ② `codesign --verify --deep --strict`(풀다 깨진 번들), ③ 번들의 `CFBundleShortVersionString`(다른 것을 받았다). **셋이 다 통과한 뒤에야** 자리를 바꾼다.

**`SemanticVersion` 을 따로 둔 이유**: `"0.10.0" < "0.9.0"` 이 문자열로는 참이라, 판을 열 번 올린 순간부터 앱이 영영 «최신입니다» 라고 말하게 된다. 만든 사람 기계에서는 한 번도 안 보이고 시간이 지난 뒤 사용자에게만 나타나는 고장이다 — 릴리스 워크플로가 sha256 을 손으로 안 옮기는 것과 같은 이유로 시험으로 못 박았다.

## 동작 흐름

자기가 돌고 있는 번들을 자기가 갈아 끼울 수 없으므로, 앱이 죽기를 기다렸다가 바꾸고 다시 여는 작은 스크립트에 넘기고 물러난다(`swapScript`). 그 스크립트도 **지우고 쓰지 않는다** — 옆으로 밀어 두고(`mv`) 쓰고, `ditto` 가 실패하면 밀어 둔 것을 도로 끌어온다. 어느 갈래로 가든 마지막 줄이 `open` 이라 앱은 반드시 다시 뜬다. 여기서 지웠다가 실패하면 사용자에게는 앱이 통째로 사라진 것으로 보이고, 그건 업데이트가 아니라 사고다.

**그 스크립트를 시험이 실제로 돌린다.** `ditto` 와 `open` 을 인자로 받게 이음매를 냈다 — 성공 경로에서는 새 판이 자리에 앉고, `ditto` 를 `/usr/bin/false` 로 바꾼 실패 경로에서는 **옛 판이 도로 제자리로 온다.** 여기는 「잘 되겠지」로 둘 수 없는 유일한 자리다.

**네트워크 경로가 하나 더 생겼다.** §9.3 이 링크 카드에 걸었던 조건 셋을 그대로 걸었다 — 설정 `checksForUpdates` 로 끌 수 있고, 나가는 것은 GitHub 주소 하나뿐이며(**메모도 지금 판 번호도 싣지 않는다** — 견주는 일은 받아온 뒤 이 기계 안에서 한다), 메뉴에 «GitHub 에 판 번호만 물어봅니다» 라고 적힌다.

**창을 띄우지 않는다.** 새 판 알림은 메뉴의 한 줄이고, 사용자가 메뉴를 열었을 때 거기 있다 — 앱은 자기를 드러내지 않는다(§14.4)에 업데이트만 예외일 이유가 없다.

릴리스 워크플로는 `dist` 안에서 `shasum` 을 돌려 파일에 경로가 아닌 이름만 남게 하고, 세 갈래 업로드 모두에 자산을 함께 올린다.

## 검증

`./scripts/test.sh` — **452개 통과** (앞 420 → 새 32개: SemanticVersion 5, UpdateCheck 6, InstallSource 4, UpdateInstaller 11, Updater 6). `./scripts/verify-notes.sh` 통과 — 기동 직후 도는 확인 `Task` 가 앱을 막지 않는다. `swift build` 새 경고 없음.

## 메모

**아직 실제로 한 번도 갈아 끼워 보지 못했다.** 지금 나가 있는 가장 새 판이 0.1.0 이라 «새 판» 이 존재하지 않고, `.zip.sha256` 자산도 다음 릴리스부터 붙는다. 조각은 전부 시험했고 자리 바꾸기 스크립트는 양쪽 경로를 실제로 돌려 봤지만, **받기→검사→교체→재실행의 처음부터 끝까지는 다음 태그를 밀 때 처음 돌아간다.** 그때 눈으로 볼 것.