#!/usr/bin/env bash
# {#place-handover} 자동 검증 — 자리가 바뀌면 종이도 따라 움직인다 (설계문서 §7.2).
#
# 규칙 자체는 `DesktopLandingTests` 가 못 박지만, **창이 정말 사라지고 다시
# 나는지**는 화면 밖의 값으로만 확인된다. 그리고 여기서 쓰는 경로는 파일을
# 밖에서 고치는 것 — MCP 로 Claude 가 날짜를 붙이는 것과 같은 길이다.
#
# 1) 날짜 없는 메모 하나 → 종이 1장 + 달력 = 바탕화면 레벨 창 2개
# 2) 파일에 due: 를 넣는다 → 달력이 맡는다 → 창 1개 (달력만)
# 3) due: 를 도로 뺀다   → 종이가 돌아온다 → 창 2개
#
# 실제 메모(~/Documents/lazymemo)는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-handover"
NOTES="$VAULT/vault/notes/2026/08"
ID="01K3ZQ8F7N2R4M6X8B0V5T9WQY"
mkdir -p "$NOTES"

# $1=날짜 줄(없으면 빈 문자열)
write_memo() {
    {
        echo "---"
        echo "id: $ID"
        echo "created: 2026-08-29T10:00:00+09:00"
        echo "updated: 2026-08-29T10:00:00+09:00"
        [ -n "$1" ] && echo "$1"
        echo "color: yellow"
        echo "pinned: false"
        echo "---"
        echo "우유 사기"
    } > "$NOTES/$ID.md"
}

write_memo ""

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

# 달력을 열어 둔다. 일정이 갈 곳이 그곳이고, 창이 0개가 되면 검증기가
# "앱이 창을 못 올렸다" 와 구별하지 못한다.
LAZYMEMO_VAULT="$VAULT" LAZYMEMO_CALENDAR=1 "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

# 앞으로 나왔다 내려앉는 몸짓(riseBriefly, 1.6초)이 끝나야 레벨이 제자리다.
settle() { sleep 3.5; }

settle
echo "▸ 날짜 없는 메모 — 종이 1장 + 달력"
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 2 | tail -1

write_memo "due: 2026-09-01"
settle
echo "▸ 밖에서 날짜를 붙였다 — 달력이 맡고 종이는 물러난다"
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 1 | tail -1

write_memo ""
settle
echo "▸ 밖에서 날짜를 뗐다 — 종이가 돌아온다"
swift "$ROOT/scripts/verify-window.swift" "$APP_PID" --expect 2 | tail -1
