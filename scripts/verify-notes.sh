#!/usr/bin/env bash
# {#note-window} 자동 검증.
#
# 임시 Vault 에 메모 두 장을 넣고 캘린더까지 띄운 뒤, 바탕화면 레벨 창이
# 3개 올라왔는지 확인한다. 실제 메모(~/Documents/lazymemo)는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-verify"
mkdir -p "$VAULT/vault/notes/2026/08"

write_memo() {
    cat > "$VAULT/vault/notes/2026/08/$1.md" <<MEMO
---
id: $1
created: 2026-08-28T16:00:00+09:00
updated: 2026-08-28T16:00:00+09:00
color: $3
pinned: false
---
$2
MEMO
}

write_memo "01K3ZQ8F7N2R4M6X8B0V5T9WQY" "첫 번째 메모" "yellow"
write_memo "01K3ZQ8F7N2R4M6X8B0V5T9WQZ" "두 번째 메모 — 강남역 치과" "blue"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_VAULT="$VAULT" LAZYMEMO_CALENDAR=1 "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

echo "▸ 임시 Vault: $VAULT"
# 메모 2장 + 캘린더 1개
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 3
