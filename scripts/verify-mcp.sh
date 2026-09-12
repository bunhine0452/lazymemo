#!/usr/bin/env bash
# {#mcp-server} 자동 검증 — JSON-RPC 대화를 통째로 흘려보내고 응답을 확인한다.
#
# 임시 Vault 를 쓰므로 실제 메모를 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-mcp"
trap 'rm -rf "$VAULT"' EXIT

swift build >/dev/null
BIN="$(swift build --show-bin-path)/lazymemo-mcp"

OUT="$(LAZYMEMO_VAULT="$VAULT" "$BIN" 2>/dev/null <<'JSONL'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"verify","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"치과 예약 — 강남역 3번 출구","at":"2026-09-01T14:00:00+09:00","tags":["병원"],"color":"blue"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"장보기 목록"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_memos","arguments":{"query":"강남역"}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"list_memos","arguments":{"from":"2026-09-01","to":"2026-09-30"}}}
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"list_memos","arguments":{"tag":"병원"}}}
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"create_memo","arguments":{"due":"틀린날짜"}}}
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}
{"jsonrpc":"2.0","id":10,"method":"unknown/method"}
{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"커피","place":"광화문 교보문고","geo":"37.5709,126.9769"}}}
{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_memos","arguments":{"place":"광화문"}}}
{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"어디","geo":"여기쯤"}}}
{"jsonrpc":"2.0","id":14,"method":"prompts/list"}
{"jsonrpc":"2.0","id":15,"method":"prompts/get","params":{"name":"weekly-tidy"}}
{"jsonrpc":"2.0","id":16,"method":"prompts/get","params":{"name":"없는것"}}
{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"회의","at":"2026-09-10T15:00:00+09:00","surface_at":"2026-09-10T14:30:00+09:00"}}}
{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"list_memos","arguments":{"from":"2026-09-10","to":"2026-09-10"}}}
{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"분리수거","due":"2026-09-08","every":"매주"}}}
{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"가끔","every":"이따금"}}}
{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"create_memo","arguments":{"text":"우산 새로 사기","folder":" 장보기 "}}}
{"jsonrpc":"2.0","id":22,"method":"tools/call","params":{"name":"list_folders","arguments":{}}}
{"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"list_memos","arguments":{"folder":"장보기"}}}
JSONL
)"

echo "$OUT" > "$VAULT/responses.jsonl"

check() {
    local label="$1" expr="$2"
    if echo "$OUT" | /usr/bin/python3 -c "
import json,sys
lines=[json.loads(l) for l in sys.stdin if l.strip()]
by_id={r.get('id'):r for r in lines}
sys.exit(0 if ($expr) else 1)
"; then
        echo "  ✓ $label"
    else
        echo "  ✗ $label"
        FAILED=1
    fi
}

FAILED=0
echo "▸ MCP 대화 검증"

check "initialize 가 프로토콜 버전을 되돌려준다" \
    "by_id[1]['result']['protocolVersion']=='2025-06-18'"
check "tools/list 가 도구 8개를 노출한다" \
    "len(by_id[2]['result']['tools'])==8"
check "나올 시각을 정하는 도구가 있다" \
    "any(t['name']=='surface_memo' for t in by_id[2]['result']['tools'])"
check "하드 삭제 도구가 없다 (D6)" \
    "not any('purge' in t['name'] or 'permanently' in t['name'] for t in by_id[2]['result']['tools'])"
check "create_memo 가 id 를 돌려준다" \
    "len(json.loads(by_id[3]['result']['content'][0]['text'])[0]['id'])==26"
check "한글 전문 검색이 만든 메모를 찾는다" \
    "len(json.loads(by_id[5]['result']['content'][0]['text']))==1"
check "날짜 범위 조회가 at 을 가진 메모만 돌려준다" \
    "len(json.loads(by_id[6]['result']['content'][0]['text']))==1"
check "태그 필터가 동작한다" \
    "json.loads(by_id[7]['result']['content'][0]['text'])[0]['tags']==['병원']"
check "잘못된 날짜는 isError 로 돌려준다 (프로토콜 오류 아님)" \
    "by_id[8]['result']['isError'] is True"
check "없는 도구도 isError 로 돌려준다" \
    "by_id[9]['result']['isError'] is True"
check "모르는 메서드는 JSON-RPC 오류다" \
    "by_id[10]['error']['code']==-32601"
check "알림에는 응답하지 않는다" \
    "len(lines)==23"
check "되풀이하는 일의 주기를 낱말로 돌려준다" \
    "json.loads(by_id[19]['result']['content'][0]['text'])[0]['every']=='매주'"
check "모르는 주기는 isError 로 돌려준다" \
    "by_id[20]['result']['isError'] is True"
check "나올 시각을 일정과 따로 적는다 — 회의는 3시, 종이는 2시 30분" \
    "json.loads(by_id[17]['result']['content'][0]['text'])[0]['surface_at'].startswith('2026-09-10T14:30')"
check "나올 시각은 일정을 바꾸지 않는다" \
    "json.loads(by_id[17]['result']['content'][0]['text'])[0]['at'].startswith('2026-09-10T15:00')"
check "나올 시각이 달력의 자리를 바꾸지 않는다" \
    "len(json.loads(by_id[18]['result']['content'][0]['text']))==1"
check "prompts 를 쓸 수 있다고 알린다" \
    "'prompts' in by_id[1]['result']['capabilities']"
check "사람이 고를 프롬프트를 5개 내놓는다" \
    "len(by_id[14]['result']['prompts'])==5"
check "프롬프트마다 사람이 읽는 이름이 있다" \
    "all(p.get('title') and p.get('description') for p in by_id[14]['result']['prompts'])"
check "prompts/get 이 시킬 말을 돌려준다" \
    "by_id[15]['result']['messages'][0]['content']['text'].strip() != ''"
check "정리 프롬프트는 지우기 전에 묻게 되어 있다" \
    "'묻기 전에 지우지 마' in by_id[15]['result']['messages'][0]['content']['text']"
check "없는 프롬프트는 JSON-RPC 오류다" \
    "by_id[16]['error']['code']==-32602"
check "create_memo 가 place 와 geo 를 그대로 돌려준다" \
    "json.loads(by_id[11]['result']['content'][0]['text'])[0]['place']=='광화문 교보문고'"
check "좌표는 적은 그대로 왕복한다" \
    "json.loads(by_id[11]['result']['content'][0]['text'])[0]['geo']=='37.5709,126.9769'"
check "장소 필터가 부분일치로 찾는다" \
    "len(json.loads(by_id[12]['result']['content'][0]['text']))==1"
check "장소는 자리를 바꾸지 않는다 — 날짜 없는 메모는 일정이 되지 않는다" \
    "'at' not in json.loads(by_id[11]['result']['content'][0]['text'])[0] and 'due' not in json.loads(by_id[11]['result']['content'][0]['text'])[0]"
check "읽을 수 없는 좌표는 isError 로 돌려준다" \
    "by_id[13]['result']['isError'] is True"
check "폴더 이름표는 앞뒤 공백을 걷어 내고 그대로 돌아온다" \
    "json.loads(by_id[21]['result']['content'][0]['text'])[0]['folder']=='장보기'"
check "list_folders 가 폴더와 장수를 센다" \
    "json.loads(by_id[22]['result']['content'][0]['text'])==[{'name':'장보기','count':1}]"
check "폴더 필터가 그 칸의 것만 돌려준다" \
    "[m['text'] for m in json.loads(by_id[23]['result']['content'][0]['text'])]==['우산 새로 사기']"

# 삭제 → 휴지통 → 복원 왕복
MEMO_ID="$(echo "$OUT" | /usr/bin/python3 -c "
import json,sys
lines=[json.loads(l) for l in sys.stdin if l.strip()]
print(json.loads([r for r in lines if r.get('id')==3][0]['result']['content'][0]['text'])[0]['id'])
")"

OUT2="$(LAZYMEMO_VAULT="$VAULT" "$BIN" 2>/dev/null <<JSONL
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"delete_memo","arguments":{"id":"$MEMO_ID"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_trash","arguments":{}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"list_memos","arguments":{}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"restore_memo","arguments":{"id":"$MEMO_ID"}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"list_memos","arguments":{}}}
JSONL
)"

OUT="$OUT2"
check "delete_memo 후 휴지통에 남아 있다" \
    "len(json.loads(by_id[3]['result']['content'][0]['text']))==1"
check "삭제한 메모는 목록에서 빠진다" \
    "len(json.loads(by_id[4]['result']['content'][0]['text']))==5"
check "restore_memo 로 되돌아온다" \
    "len(json.loads(by_id[6]['result']['content'][0]['text']))==6"

# 파일이 실제로 남아 있는지 (하드 삭제가 아니었음을 파일 시스템에서 확인)
if [ -n "$(find "$VAULT/vault" -name '*.md' | head -1)" ]; then
    echo "  ✓ 정본 마크다운 파일이 디스크에 남아 있다"
else
    echo "  ✗ 마크다운 파일이 없다"
    FAILED=1
fi

echo
[ "$FAILED" -eq 0 ] && echo "✓ MCP 서버 검증 통과" || { echo "✗ 실패한 항목이 있습니다"; exit 1; }
