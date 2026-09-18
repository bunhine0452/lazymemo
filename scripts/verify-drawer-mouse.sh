#!/usr/bin/env bash
# 「서랍」을 진짜 마우스로 검증 — 잡아 끌리는가, 눌러 펼쳐지는가, 머리 줄로 끌리는가, × 와 바깥 클릭에 접히는가.
#
# `verify-drawer.sh` 가 못 보는 것이다: 이벤트가 AppKit 을 실제로 통과해야 드러난다
# (2026-09-18 — `performDrag` 가 곧바로 돌아와 잡기만 해도 펼쳐지던 고장은 산수 검증을 다 통과했다).
# 합성 HID 이벤트는 **그 자리의 맨 앞 창**에 닿으므로 두 판으로 나눠 띄운다 —
#   ① LAZYMEMO_STAGE=1  : 창을 남의 창 위에 세운다(무대). 탭 끌기·누르기·머리 줄·×.
#   ② LAZYMEMO_DRAWER=summon : 메뉴바 「서랍」처럼 펼친 채 앞으로. 머리 줄 끌기·바깥 클릭에 접힘.
# 전제: 이 셸에 손쉬운 사용(Accessibility) 권한. 도는 동안 포인터가 움직인다 — 손을 떼고 있을 것.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
DRIVER="$(mktemp -d)/verify-drawer-mouse"
swiftc -O scripts/verify-drawer-mouse.swift -o "$DRIVER" 2>&1 | grep -E "error" || true

run() {  # <이름> <시나리오> <환경…>
    local name="$1" scenario="$2"; shift 2
    local vault; vault="$(mktemp -d)/lazymemo-drawer-mouse"
    mkdir -p "$vault/support"
    echo '{"drawer":{"x":500,"y":300,"width":232,"height":60,"hidden":false}}' > "$vault/support/layout.json"
    env LAZYMEMO_VAULT="$vault" "$@" "$BIN" >/dev/null 2>&1 &
    local app=$!
    disown   # 끝에 kill 할 때 셸이 「Terminated」를 적지 않게
    sleep 4
    echo "▸ $name"
    "$DRIVER" "$app" "$scenario" || FAILED=1
    kill "$app" 2>/dev/null || true
    sleep 1
    rm -rf "$vault"
}

FAILED=0
run "무대 위의 탭" tab LAZYMEMO_STAGE=1
run "앞으로 부른 판" summoned LAZYMEMO_DRAWER=summon
rm -rf "$(dirname "$DRIVER")"
[[ "$FAILED" == 0 ]] && echo "✓ 서랍 (마우스)" || { echo "✗ 서랍 (마우스)"; exit 1; }
