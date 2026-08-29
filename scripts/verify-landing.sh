#!/usr/bin/env bash
# {#desktop-landing} 자동 검증 — 날짜가 붙은 메모는 종이가 되지 않는다 (설계문서 §7.2).
#
# 사용자가 겪은 결함: 달력에 일정을 넣을 때마다 바탕화면에 종이가 한 장씩 생겼다.
# 규칙 자체는 `DesktopLandingTests` 가 못 박지만, **창이 정말 안 뜨는지**는
# 화면 밖의 값으로만 확인된다. 그래서 임시 Vault 에 날짜 있는 메모 둘과 날짜
# 없는 메모 하나를 넣고 띄운 뒤, 바탕화면 레벨 창이 **하나뿐인지** 본다.
#
# 실제 메모(~/Documents/lazymemo)는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-landing"
mkdir -p "$VAULT/vault/notes/2026/08"

# $1=id  $2=본문  $3=날짜 줄(없으면 빈 문자열)
write_memo() {
    {
        echo "---"
        echo "id: $1"
        echo "created: 2026-08-29T10:00:00+09:00"
        echo "updated: 2026-08-29T10:00:00+09:00"
        [ -n "$3" ] && echo "$3"
        echo "color: yellow"
        echo "pinned: false"
        echo "---"
        echo "$2"
    } > "$VAULT/vault/notes/2026/08/$1.md"
}

write_memo "01K3ZQ8F7N2R4M6X8B0V5T9WQY" "우유 사기"        ""
write_memo "01K3ZQ8F7N2R4M6X8B0V5T9WQZ" "치과"             "due: 2026-09-01"
write_memo "01K3ZQ8F7N2R4M6X8B0V5T9WR0" "팀 회의"          "at: 2026-09-01T15:00:00+09:00"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

# 달력은 일부러 열지 않는다 — 세는 창이 종이뿐이어야 한다.
LAZYMEMO_VAULT="$VAULT" "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

echo "▸ 임시 Vault: $VAULT"
echo "▸ 메모 3장 중 날짜 없는 1장만 종이가 되어야 한다"
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 1
