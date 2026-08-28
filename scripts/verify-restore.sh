#!/usr/bin/env bash
# {#restore-test} — 앱을 껐다 켜도 메모 내용과 창 위치가 그대로인지 확인한다.
#
# 실제 재부팅을 대신한다. 재부팅이 추가로 검증하는 것은 OS 가 프로세스를
# 되살리는 부분뿐이고, 복원 책임은 전적으로 Vault 와 layout.json 에 있다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-restore"
trap 'rm -rf "$VAULT"' EXIT

swift build >/dev/null
APP="$(swift build --show-bin-path)/LazyMemo"
MCP="$(swift build --show-bin-path)/lazymemo-mcp"

# 메모는 MCP 서버(별도 프로세스)로 만든다 — 그 경로도 함께 검증된다.
LAZYMEMO_VAULT="$VAULT" "$MCP" >/dev/null 2>&1 <<'JSONL'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"첫째 메모"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"둘째 메모","due":"2026-09-01"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"셋째 메모","color":"pink"}}}
JSONL

run_once() {
    LAZYMEMO_VAULT="$VAULT" LAZYMEMO_CALENDAR=1 "$APP" &
    local pid=$!
    local result
    result="$(swift "$ROOT/scripts/verify-window.swift" "$pid" --expect 4 --json || true)"
    # LayoutStore 는 드래그 중 디스크를 두들기지 않으려고 500ms 디바운스를 둔다.
    # 강제 종료는 그 마지막 구간을 잃을 수 있으므로 여기서 기다려 준다.
    sleep 1.5
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    echo "$result"
}

echo "▸ 1차 기동"
FIRST="$(run_once)"
echo "  창 배치: $FIRST"

echo "▸ 2차 기동 (껐다 켠 뒤)"
SECOND="$(run_once)"
echo "  창 배치: $SECOND"

FAILED=0

if [ "$FIRST" = "$SECOND" ] && [ -n "$FIRST" ]; then
    echo "  ✓ 창 위치와 크기가 그대로 복원됨"
else
    echo "  ✗ 창 배치가 달라졌습니다"
    FAILED=1
fi

BODIES="$(LAZYMEMO_VAULT="$VAULT" "$MCP" 2>/dev/null <<'JSONL' | /usr/bin/python3 -c "
import json,sys
rows=[json.loads(l) for l in sys.stdin if l.strip()]
memos=json.loads([r for r in rows if r.get('id')==2][0]['result']['content'][0]['text'])
print('|'.join(sorted(m['text'] for m in memos)))
"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_memos","arguments":{}}}
JSONL
)"

if [ "$BODIES" = "둘째 메모|셋째 메모|첫째 메모" ]; then
    echo "  ✓ 메모 내용이 그대로 남아 있음"
else
    echo "  ✗ 메모 내용이 다릅니다: $BODIES"
    FAILED=1
fi

if [ -f "$VAULT/support/layout.json" ]; then
    echo "  ✓ layout.json 이 기록됨"
else
    echo "  ✗ layout.json 이 없습니다"
    FAILED=1
fi

echo
[ "$FAILED" -eq 0 ] && echo "✓ 재기동 복원 검증 통과" || { echo "✗ 실패한 항목이 있습니다"; exit 1; }
