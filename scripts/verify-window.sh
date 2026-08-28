#!/usr/bin/env bash
# {#desktop-window} 자동 검증.
#
# 스파이크 창을 띄운 채 앱을 기동하고, 그 창이 실제로 화면에 올라왔는지와
# 창 레벨이 desktopIconWindow+1 인지 확인한 뒤 앱을 종료한다.
#
# 육안이 필요한 환경 시나리오(Stage Manager · Mission Control · 월페이퍼
# 클릭 · 다중 디스플레이)는 여기서 다루지 않는다 — 메뉴바의
# "바탕화면 창 스파이크" 로 직접 확인할 것.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"

pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_SPIKE=1 "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true' EXIT

echo "▸ pid $APP_PID 로 기동, 스파이크 창 확인"
swift "$ROOT/scripts/verify-window.swift" "$APP_PID"
