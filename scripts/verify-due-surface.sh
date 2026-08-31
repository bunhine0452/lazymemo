#!/usr/bin/env bash
# {#surface-at-time} 자동 검증.
#
# 설계문서 §7.2 는 "날짜가 붙은 것은 달력이 맡는다 — 그 날이 오면 달력이 꺼내
# 준다" 고 약속한다. 그 약속의 뒷절반을 여기서 확인한다.
#
# 임시 Vault 에 세 장을 넣는다.
#   ① 오늘 이미 지난 시각의 일정  → 켤 때 종이로 나와야 한다
#   ② 한참 뒤의 일정              → 나오면 안 된다 (달력이 맡는다)
#   ③ 날짜 없는 메모              → 늘 나온다 (기준선)
#
# 그리고 **layout.json 을 함께 본다.** 꺼내 준 종이가 "사람이 꺼내 둔 것"으로
# 기록되면 그 일정은 영영 바탕화면에 남는다 — 화면만 봐서는 구별되지 않고,
# 다음 날에야 드러나는 종류의 결함이다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-due"
SUPPORT="$VAULT/support"
YEAR="$(date +%Y)"
MONTH="$(date +%m)"
mkdir -p "$VAULT/vault/notes/$YEAR/$MONTH"

# 한 시간 전과 열두 시간 뒤. 오늘 안에 있어야 하므로 정오를 기준으로 잡는다.
PASSED="$(date -v-1H '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
FUTURE="$(date -v+12H '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
TODAY="$(date '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"

write_memo() {
    local id="$1" body="$2" extra="$3"
    cat > "$VAULT/vault/notes/$YEAR/$MONTH/$id.md" <<MEMO
---
id: $id
created: $TODAY
updated: $TODAY
$extra
color: yellow
pinned: false
---
$body
MEMO
}

PASSED_ID="01K3ZQ8F7N2R4M6X8B0V5T9WQ1"
FUTURE_ID="01K3ZQ8F7N2R4M6X8B0V5T9WQ2"
PLAIN_ID="01K3ZQ8F7N2R4M6X8B0V5T9WQ3"

write_memo "$PASSED_ID" "지나간 약속" "at: $PASSED"
write_memo "$FUTURE_ID" "한참 뒤 약속" "at: $FUTURE"
write_memo "$PLAIN_ID"  "그냥 메모"    "tags: []"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_VAULT="$VAULT" "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

echo "▸ 임시 Vault: $VAULT"
echo "▸ 지난 시각: $PASSED / 뒤의 시각: $FUTURE"

# 지나간 일정 한 장 + 날짜 없는 메모 한 장 = 창 2개.
# 한참 뒤의 일정은 달력이 맡으므로 종이가 없어야 한다.
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 2

# 꺼내 준 종이가 layout.json 에 "나와 있다" 로 적히면 안 된다.
LAYOUT="$SUPPORT/layout.json"
for _ in $(seq 1 20); do
    [ -f "$LAYOUT" ] && break
    sleep 0.25
done

if [ ! -f "$LAYOUT" ]; then
    echo "✗ layout.json 이 만들어지지 않았습니다: $LAYOUT"
    exit 1
fi

HIDDEN="$(/usr/bin/python3 -c "
import json, sys
layout = json.load(open('$LAYOUT'))
entry = layout.get('windows', layout).get('$PASSED_ID')
print('없음' if entry is None else entry.get('hidden'))
")"

echo "▸ layout.json 의 꺼내 준 일정: hidden=$HIDDEN"
if [ "$HIDDEN" = "True" ] || [ "$HIDDEN" = "없음" ]; then
    echo "✓ 시각이 된 일정이 종이로 나오고, 그 자리는 여전히 달력입니다"
else
    echo "✗ 꺼내 준 종이가 「사람이 꺼내 둔 것」으로 기록됐습니다 — 영영 바탕화면에 남습니다"
    exit 1
fi
