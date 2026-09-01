#!/usr/bin/env bash
# 「서랍」 검증 — 펼치고 접는 것이 실제 창에서 약속대로 되는가.
#
# 시험(`DrawerGeometryTests`)은 산수만 본다. 창이 진짜로 그 크기가 되는지,
# 접었을 때 왼쪽 위가 제자리로 돌아오는지는 NSWindow 를 세워 봐야 안다.
# 임시 Vault 를 쓰므로 실제 메모는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-drawer"
trap 'rm -rf "$VAULT"' EXIT

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

OUT="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_DRAWER=1 "$BIN" 2>&1 || true)"
echo "$OUT" | grep "서랍" || { echo "✗ 서랍 진단이 나오지 않았습니다"; echo "$OUT"; exit 1; }

echo "$OUT" | grep -q "모서리고정=true" || { echo "✗ 펼칠 때 폴더가 있던 모서리를 떠났습니다"; exit 1; }
echo "$OUT" | grep -q "제자리복귀=true" || { echo "✗ 접었더니 자리가 달라졌습니다"; exit 1; }
echo "$OUT" | grep -q "계획크기=true"   || { echo "✗ 펼친 크기가 판형과 다릅니다"; exit 1; }
echo "✓ 서랍"
