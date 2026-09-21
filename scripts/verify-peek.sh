#!/usr/bin/env bash
# 「종이 보기」(⌥⌘P)를 진짜 키 이벤트로 검증 — 바탕에 누운 종이가 전부 앞에 서는가, 4초 뒤 스스로
# 눕는가, 다시 누르면 곧바로 눕는가, 서 있는 동안 누른 종이만 남는가.
#
# `PeekTests` 는 레벨 값만 본다. 이것은 다른 앱 창이 앞에 있는 **실제 화면**에서 Carbon 단축키가
# 이벤트를 받아 창이 정말 올라오는지를 본다 (2026-09-21 손검증을 스크립트로 옮긴 것).
# 전제: 이 셸에 손쉬운 사용(Accessibility) 권한 — 도는 동안 포인터가 한 번 움직인다.
# 설치된 LazyMemo 가 돌고 있어도 된다 — ⌥⌘P 를 그쪽이 먼저 잡고 있으면 이 검증은 실패한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-peek"
mkdir -p "$VAULT/vault/notes/2026/09"

write_memo() {
    cat > "$VAULT/vault/notes/2026/09/$1.md" <<MEMO
---
id: $1
created: 2026-09-21T10:00:00+09:00
updated: 2026-09-21T10:00:00+09:00
color: $3
pinned: false
---
$2
MEMO
}

write_memo "01K5MZ8F7N2R4M6X8B0V5T9WQY" "종이 보기 검증 — 첫 장" "yellow"
write_memo "01K5MZ8F7N2R4M6X8B0V5T9WQZ" "종이 보기 검증 — 둘째 장, 강남역 치과" "blue"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_VAULT="$VAULT" "$BIN" >/dev/null 2>&1 &
APP_PID=$!
disown   # 끝에 kill 할 때 셸이 「Terminated」를 적지 않게
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$(dirname "$VAULT")"' EXIT
sleep 4

swift "$ROOT/scripts/verify-peek.swift" "$APP_PID"
