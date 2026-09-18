#!/usr/bin/env bash
# 「lazymemo 설정」 창을 그림으로 — 위와 끝, 두 장 (build/ui/settings*.png).
#
# `ImageRenderer` 는 grouped Form 을 못 그리므로(§14.9) 창을 실제로 열어 뷰가 스스로 그린 것을
# 받는다 (`SettingsWindow.snapshot` — 화면 기록 권한이 필요 없다). 임시 Vault 라 실제 설정은 안 건드린다.
# 확인이 끝나면 build/ui 를 지운다 (용량 규칙 4).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build/ui"
mkdir -p "$OUT"

swift build 2>&1 | grep -E "error:" || true
BIN="$(swift build --show-bin-path)/LazyMemo"

shoot() {  # <파일> [끝까지 스크롤]
    local vault; vault="$(mktemp -d)/lazymemo-settings"
    mkdir -p "$vault"
    env LAZYMEMO_VAULT="$vault" LAZYMEMO_SETTINGS="$OUT/$1" ${2:+LAZYMEMO_SETTINGS_END=1} "$BIN" >/dev/null 2>&1 &
    local app=$!
    disown
    for _ in $(seq 1 60); do [[ -f "$OUT/$1" ]] && break; sleep 0.25; done
    kill "$app" 2>/dev/null || true
    rm -rf "$vault"
    [[ -f "$OUT/$1" ]] && echo "  $OUT/$1" || { echo "✗ $1 이 나오지 않았습니다"; exit 1; }
}

echo "▸ 설정 창"
shoot settings.png
shoot settings-end.png end
