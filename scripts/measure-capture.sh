#!/usr/bin/env bash
# {#latency-measure} — 단축키에서 커서까지 150ms 목표 실측 (설계문서 §11).
#
# 임시 Vault 를 쓰므로 실제 메모를 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ROUNDS="${1:-15}"
VAULT="$(mktemp -d)/lazymemo-measure"
trap 'rm -rf "$VAULT"' EXIT

swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

echo "▸ release 빌드로 ${ROUNDS}회 측정"
LAZYMEMO_VAULT="$VAULT" LAZYMEMO_MEASURE="$ROUNDS" "$BIN"
