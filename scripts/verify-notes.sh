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

# 종이가 **창 전환기에 서지 않는지.** 화면으로는 확인할 수 없다 — 표준 창이든
# 떠 있는 창이든 그림은 똑같고, 다른 점은 AltTab 같은 창 단위 전환기가 이 창을
# 목록에 넣느냐뿐이다. 앱에게 직접 물어본다.
ROLE="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_WINDOWROLE=1 "$BIN" 2>&1 | sed -n 's/^\[capture\] 창역할 //p')"
echo "▸ $ROLE"

# AXStandardWindow 는 물론이고 AXDialog 도 안 된다 — 창 전환기는 둘 다 목록에
# 넣는다. 떠 있는 창이라고 밝혀야 빠진다.
case "$ROLE" in
    *"subrole=AXFloatingWindow"*"비활성숨김=false"*)
        echo "✓ 종이는 떠 있는 창이라 창 전환기에 서지 않고, 다른 앱을 써도 사라지지 않습니다"
        ;;
    *"비활성숨김=true"*)
        echo "✗ 다른 앱을 쓰는 동안 메모가 화면에서 사라집니다 (hidesOnDeactivate)"
        exit 1
        ;;
    *)
        echo "✗ 종이가 창 전환기에 설 역할입니다 — 알트탭에 메모가 줄줄이 섭니다: $ROLE"
        exit 1
        ;;
esac
