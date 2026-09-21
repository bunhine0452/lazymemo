#!/usr/bin/env bash
# 상자 바깥을 누르면 실제로 치워지는지 검증한다.
#
# 사용자가 겪은 결함: 바탕화면 메모를 고치던 중에 단축키로 상자를 열고
# 아무것도 안 친 채 바탕화면 쪽을 누르면 상자가 그대로 남았다. 원인은
# 감시가 하나뿐이었던 것 — `addGlobalMonitorForEvents` 는 **다른 앱으로 가는**
# 클릭만 본다. 바탕화면 메모 창은 우리 앱의 것이라 그 감시에 걸리지 않는다.
#
# 클릭을 밖에서 만들어 내려면 손쉬운 사용 권한이 필요하므로(osascript 는
# -25211 로 거절당한다) 앱이 자기 이벤트 큐에 가짜 클릭을 넣는 통로를 쓴다
# (LAZYMEMO_DISMISS=1). 지역 감시가 보는 자리는 사람이 누른 것과 같다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
VAULT="$(mktemp -d)/lazymemo-dismiss"
mkdir -p "$VAULT/vault/notes"
trap 'rm -rf "$VAULT"' EXIT

# 진단은 stderr 로 나온다 — 파이프에 갇히지 않는다.
OUT="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_DISMISS=1 "$BIN" 2>&1 || true)"
LINE="$(printf '%s\n' "$OUT" | grep '바깥클릭' || true)"

if [ -z "$LINE" ]; then
    echo "✗ 진단이 나오지 않았습니다"
    printf '%s\n' "$OUT"
    exit 1
fi

echo "▸ $LINE"

case "$LINE" in
    *"감시=2"*) ;;
    *) echo "✗ 클릭 감시가 둘 다 걸리지 않았습니다 — 한쪽 바깥은 감시되지 않습니다"; exit 1 ;;
esac
case "$LINE" in
    *"열림=true"*) ;;
    *) echo "✗ 상자가 열리지 않아 검증할 수 없습니다"; exit 1 ;;
esac
case "$LINE" in
    *"안쪽클릭뒤열림=true"*) ;;
    *) echo "✗ 상자 안을 눌렀는데 상자가 닫혔습니다"; exit 1 ;;
esac
case "$LINE" in
    *"바깥클릭뒤열림=false"*) ;;
    *) echo "✗ 우리 앱의 다른 창을 눌렀는데 상자가 남아 있습니다"; exit 1 ;;
esac

# 답을 든 채라면 바깥 클릭은 치우지 않고 비켜 선다 — 단축키가 도로 부른다 (2026-09-21).
case "$LINE" in
    *"비서없음"*) echo "· 비서가 없는 빌드 — 답을 든 상자의 검증은 건너뜁니다" ;;
    *"답들고바깥클릭뒤열림=true"*"비켜섬=true"*"단축키로돌아옴=true"*)
        echo "✓ 답을 든 상자는 바깥 클릭에 비켜 설 뿐 사라지지 않고, 단축키로 돌아옵니다" ;;
    *) echo "✗ 답을 든 상자가 바깥 클릭에 사라졌거나 단축키로 돌아오지 못했습니다"; exit 1 ;;
esac

echo "✓ 안쪽 클릭은 놔두고, 앱 안의 바깥 클릭은 (들고 있는 것이 없을 때) 상자를 치웁니다"
