#!/usr/bin/env bash
# {#perf-measure} — 성능 예산 실측 (설계문서 §11).
#
#   메모 10장 표시 시 RSS ≤ 100MB · idle CPU 0%
#
# release 빌드로 임시 Vault 를 띄워 재고, 실제 메모는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUDGET_RSS_MB=100
BUDGET_CPU=1.0     # idle 목표는 0% 이지만 샘플링 잡음을 감안한 상한

VAULT="$(mktemp -d)/lazymemo-perf"
trap 'rm -rf "$VAULT"' EXIT

echo "▸ release 빌드"
swift build -c release >/dev/null
APP="$(swift build -c release --show-bin-path)/LazyMemo"
MCP="$(swift build -c release --show-bin-path)/lazymemo-mcp"

echo "▸ 메모 10장 생성"
{
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}'
    for i in $(seq 1 10); do
        echo "{\"jsonrpc\":\"2.0\",\"id\":$((i+1)),\"method\":\"tools/call\",\"params\":{\"name\":\"create_memo\",\"arguments\":{\"text\":\"성능 측정용 메모 $i — 본문을 조금 길게 적어 실제 사용에 가깝게 만든다.\"}}}"
    done
} | LAZYMEMO_VAULT="$VAULT" "$MCP" >/dev/null 2>&1

LAZYMEMO_VAULT="$VAULT" "$APP" &
PID=$!
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

swift "$ROOT/scripts/verify-window.swift" "$PID" --expect 10 --json >/dev/null || {
    echo "✗ 메모 창 10개가 뜨지 않았습니다"; exit 1
}
echo "▸ 창 10개 확인, 3초 안정화 후 측정"
sleep 3

RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
RSS_MB="$(/usr/bin/python3 -c "print(f'{$RSS_KB/1024:.1f}')")"
# 예산은 **footprint(더러운 메모리)** 로 잰다. RSS 는 디스크에서 그대로 올린 깨끗한 코드 페이지까지
# 세는데, 0.5.0 부터 실리는 추론 엔진(LiteRT-LM dylib 65MB)이 그것만으로 RSS 를 40MB 가까이 올린다 —
# 시스템이 압박받으면 그냥 버리는 페이지라 이 앱이 «쓰는» 메모리가 아니다 (2026-09-18 재측정:
# RSS 127MB · footprint 48MB). 설계문서 §11.
FOOT_MB="$(footprint -p "$PID" 2>/dev/null | awk '/phys_footprint:/ { print $2; exit }' | tr -d 'MB')"
FOOT_MB="${FOOT_MB:-$RSS_MB}"

# ps 의 %cpu 는 프로세스 시작 이후 평균이라 idle 판정에 못 쓴다.
# top 의 순간 샘플을 여러 번 떠서 최댓값을 본다.
# 첫 표본은 프로세스 시작 이후 누적값이라 버리고, 이후 순간 표본의 최댓값을 본다.
CPU="$(top -l 4 -s 1 -pid "$PID" -stats pid,cpu 2>/dev/null \
    | awk -v pid="$PID" '$1 == pid { print $2 }' \
    | tail -3 | sort -rn | head -1 || true)"
CPU="${CPU:-0}"

echo
echo "  footprint ${FOOT_MB} MB   (예산 ${BUDGET_RSS_MB} MB) · RSS ${RSS_MB} MB (참고 — 깨끗한 코드 페이지 포함)"
echo "  idle CPU  ${CPU} %      (예산 0%)"
echo

FAILED=0
/usr/bin/python3 -c "import sys; sys.exit(0 if $FOOT_MB <= $BUDGET_RSS_MB else 1)" \
    && echo "  ✓ 메모리 예산 이내" || { echo "  ✗ 메모리 예산 초과"; FAILED=1; }
/usr/bin/python3 -c "import sys; sys.exit(0 if $CPU <= $BUDGET_CPU else 1)" \
    && echo "  ✓ idle CPU 0%" || { echo "  ✗ idle 상태에서 CPU 를 씁니다"; FAILED=1; }

echo
[ "$FAILED" -eq 0 ] && echo "✓ 성능 예산 통과" || { echo "✗ 예산을 넘었습니다"; exit 1; }
