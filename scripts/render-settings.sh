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

# LAZYMEMO_SETTINGS_APPEARANCE=light|dark 로 창 하나만 갈아 끼운다 (시스템 설정은 안 건드린다).
# LAZYMEMO_THEME=<id> 를 내보내 두면 그 테마로 뜬다 (`ThemeRuntime`).
shoot() {  # <파일> [끝까지 스크롤]
    local vault; vault="$(mktemp -d)/lazymemo-settings"
    mkdir -p "$vault"
    # 지난 주행의 그림을 먼저 치운다 — 아래의 기다림은 «파일이 생겼는가» 로
    # 끝나므로, 남아 있으면 앱이 그리기도 전에 끝내고 옛 그림을 보게 된다.
    rm -f "$OUT/$1"
    env LAZYMEMO_VAULT="$vault" LAZYMEMO_SETTINGS_APPEARANCE="${LAZYMEMO_SETTINGS_APPEARANCE:-light}" LAZYMEMO_SETTINGS="$OUT/$1" ${2:+LAZYMEMO_SETTINGS_END=1} "$BIN" >/dev/null 2>&1 &
    local app=$!
    disown
    for _ in $(seq 1 60); do [[ -f "$OUT/$1" ]] && break; sleep 0.25; done
    kill "$app" 2>/dev/null || true
    rm -rf "$vault"
    [[ -f "$OUT/$1" ]] && echo "  $OUT/$1" || { echo "✗ $1 이 나오지 않았습니다"; exit 1; }
}

echo "▸ 설정 창"
LAZYMEMO_SETTINGS_APPEARANCE=light shoot settings.png
LAZYMEMO_SETTINGS_APPEARANCE=light shoot settings-end.png end
LAZYMEMO_SETTINGS_APPEARANCE=dark shoot settings-dark.png
LAZYMEMO_SETTINGS_APPEARANCE=dark shoot settings-dark-end.png end
