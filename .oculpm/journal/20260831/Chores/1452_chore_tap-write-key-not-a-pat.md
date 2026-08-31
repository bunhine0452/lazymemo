---
schema_version: 1
type: chore
slug: "tap-write-key-not-a-pat"
status: done
difficulty: low
created_at: "2026-08-31T14:52:33+09:00"
session_id: "20260831-002"
agent:
  id: "claude-code"
  version: "Opus 5 (1M context)"
language: "ko"
verified_by_user: false
files_touched:
  - path: ".github/workflows/release.yml"
    op: update
  - path: "docs/DESIGN.md"
    op: update
related: []
tags:
  - "ci"
  - "security"
  - "homebrew"
  - "mcp-tool"
---
[x] 탭 갱신 열쇠를 발급했다 — PAT 가 아니라 배포 키로

## 무엇을 했나

릴리스 워크플로가 탭(`bunhine0452/homebrew-lazymemo`)에 `sha256` 을 적으려면 다른 저장소에 쓸 열쇠가 필요하다. 기본 토큰은 제 저장소 밖으로 못 나간다.

**PAT 를 쓰지 않았다.** 손쉬운 길은 둘이었다 — 개인 액세스 토큰을 새로 만들거나, 이미 로그인돼 있는 `gh` 의 OAuth 토큰(`repo` 스코프)을 그대로 시크릿에 넣는 것. 둘 다 **그 사람이 가진 모든 저장소에 닿는 열쇠**를 CI 에 두는 일이다. 이 워크플로가 하는 일은 파일 한 줄에 sha256 을 적는 것뿐인데.

그래서 **탭 하나에만 쓰기가 되는 배포 키**를 새로 만들었다.

- `ssh-ed25519` 한 쌍을 만들어 공개키를 탭의 Deploy keys 에 `read_only=false` 로 등록.
- 비밀키는 `lazymemo` 의 `TAP_DEPLOY_KEY` 시크릿에만 넣고 **로컬 사본은 남기지 않았다.**
- 워크플로는 HTTPS + 토큰에서 SSH + 키로 바꿨다. 러너에서 키는 파일로 잠깐 존재하고 실행이 끝나면 러너째 사라진다.

새는 순간 잃는 것의 크기가 다르고, 거두는 것도 탭의 Deploy keys 에서 그 키 하나만 지우면 된다 — 개인 토큰이었으면 그것을 거두는 순간 그 사람의 다른 것들도 함께 끊긴다.

## 검증

`workflow_dispatch` 로 v0.1.0 에 `force=true` 로 한 바퀴 돌려 **끝까지 초록**인 것을 봤다. 「홈브루 탭 갱신」이 실제로 실행됐고(건너뛰기 아님), 탭에 `github-actions[bot]` 이름으로 `cask: lazymemo 0.1.0` 커밋이 올라갔다.

끝난 상태가 맞는지도 확인했다 — 공개된 zip 의 sha256(`eada1a5e…`)과 cask 에 적힌 값이 **일치**하고, 캐시를 비우고 다시 `brew install --cask` 해서 검역 딱지 없음 · 서명 유효까지 봤다. 앞서 이 값이 어긋나 설치가 깨진 적이 있어서, 이번에는 기계가 적은 값으로 그 고리를 처음부터 끝까지 돌려 봤다.