---
schema_version: 1
type: feature
slug: "homebrew-and-tag-is-the-release"
status: done
difficulty: high
created_at: "2026-08-31T14:19:36+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: "scripts/package-release.sh"
    op: create
  - path: ".github/workflows/release.yml"
    op: create
  - path: ".github/workflows/pages.yml"
    op: create
  - path: ".github/release-header.md"
    op: create
  - path: "site/index.html"
    op: create
  - path: "docs/DESIGN.md"
    op: update
  - path: "README.md"
    op: update
related: []
tags:
  - "release"
  - "homebrew"
  - "ci"
  - "pages"
  - "gatekeeper"
  - "mcp-tool"
---
[x] 홈브루로 .app 을 주고, 태그 하나가 배포를 다 하게 한다 — §12 를 뒤집으며

## 추가 기능

§12 는 「GitHub Releases 로 바이너리만 뿌리는 방식은 권하지 않는다」고 적어 두었다. **그 관찰은 지금도 사실이다** — macOS 15 부터 우클릭-열기 우회가 사라져, 검역 딱지가 붙은 미공증 앱은 「손상되었습니다」로 끝난다. 바뀐 것은 관찰이 아니라 **누가 그 마찰을 감당하는가**다.

- **Homebrew 탭** (`bunhine0452/homebrew-lazymemo`) — cask 가 설치 직후 검역 딱지를 뗀다(`postflight` 의 `xattr -dr`). 미봉책이고, cask 의 `caveats` 와 탭 README 와 §12.2 가 **같은 말을 한다** — 뗐다는 사실, 왜 뗐는지, 믿을 수 없으면 소스에서 빌드하라는 것. 조용히 떼는 것과 적어 두고 떼는 것은 다른 일이다. 옳은 답은 Developer ID 공증이고 받는 즉시 이 블록을 지운다 (지금은 인증서가 없다 — `security find-identity` 가 0건).
- **태그를 밀면 그것이 곧 배포다** (`release.yml`) — 시험 → 번들 → zip → 릴리스 → 탭의 sha256 까지.
- **소개 페이지** (`site/`, `pages.yml`) — 정적 파일 그대로. 바깥으로 나가는 요청이 하나도 없고, 워크플로가 배포 전에 그것을 실제로 검사한다. 앱이 §9.3 에서 한 약속을 그 앱의 페이지가 깨면 안 된다.

## 동작 흐름

`package-release.sh` 는 **`ditto` 로 묶고, 풀어서 서명을 다시 검사한다.** `zip` 은 확장 속성을 흘려 서명을 깨는데, 그러면 검역 딱지와 무관하게 안 열린다 — 받는 쪽에서만 드러나는 종류라 만든 자리에서 확인한다.

**파이프라인을 시험하다 실제로 깨뜨렸다.** 이미 나간 v0.1.0 에 워크플로를 다시 돌렸더니 러너가 만든 zip 의 바이트가 손으로 만든 것과 달랐고(`8e64795…` → `9c35688…`), `--clobber` 가 자산을 갈아 끼우는 순간 cask 의 sha256 이 어긋나 `brew install` 이 checksum mismatch 로 끝났다. **이 워크플로가 막으려던 바로 그 고장을, 그것을 시험하다 만들었다.** 만든 사람 기계에서는 여전히 아무 일도 안 일어난다.

그래서 둘을 고쳤다.

- **이미 나간 판의 바이트는 바꾸지 않는다.** 자산이 있으면 멈추고, 덮어쓰려면 `force` 를 일부러 골라야 한다. 대개 옳은 답은 판을 올리는 것이다.
- **탭을 못 갱신했으면 실행을 빨갛게 둔다.** 릴리스는 나갔지만 나간 zip 과 cask 의 값이 다르므로 끝난 상태가 깨진 것이다 — 초록인데 설치가 안 되는 것이 가장 나쁘다.

판이 어긋나면(태그·`Info.plist`·`Version.swift`) 시작도 안 하고, 시험이 빨가면 내보내지 않는다.

## 검증

- `brew audit --cask --online` 통과(exit 0, 경고 없음). 실제로 `brew install --cask` 해서 **검역 딱지 없음 · 서명 유효 · 앱이 뜸**까지 확인했다. 깨진 뒤에는 값을 맞추고 다시 설치해 통과를 재확인했다.
- 워크플로를 `workflow_dispatch` 로 v0.1.0 에 돌려 macos-26 러너에서 끝까지 성공하는 것을 봤다 — 그 실행이 위의 sha256 사고를 드러냈다.
- 첫 판 워크플로는 파싱에 실패해 빨갛게 남았다: `secrets` 는 step 의 `if` 에서 못 읽는다. `env` 로 받아 고쳤고, `git describe` 가 쓸 이력이 없어 `fetch-depth: 0` 도 함께.
- 페이지는 HTTP 200, 그림 넷 다 200, 브라우저로 열어 라이트 모드 렌더를 눈으로 확인했다.