#!/usr/bin/env bash
# 실제 뷰를 PNG 로 렌더한다. 화면 기록 권한 없이 UI 를 확인하기 위한 통로.
# 임시 Vault 를 쓰므로 실제 메모는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${1:-build/ui}"
VAULT="$(mktemp -d)/lazymemo-render"
trap 'rm -rf "$VAULT"' EXIT

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_VAULT="$VAULT" LAZYMEMO_RENDER="$ROOT/$OUT" "$BIN"
echo "✓ $OUT"
ls -1 "$OUT"
