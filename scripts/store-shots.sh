#!/usr/bin/env bash
# 맥 App Store 스크린샷 — 실제 앱을 화면의 한 구역(1440×900 pt)에 세우고 장면마다 찍는다
# (`DemoTour.shots`). 레티나에서 그 구역이 곧 스토어 규격 2880×1800 이다.
#
#   ./scripts/store-shots.sh            # → dist/store/mac/{capture,desk,drawer,folder,desk-dark}.png
#
# 화면 기록 권한이 있어야 한다 (없으면 바탕화면만 찍힌다). 도는 동안 무대 위의 다른 창은
# 잠깐 가려진다. 임시 Vault 를 쓰므로 실제 메모는 건드리지 않는다. 스토어 판에는
# Claude 연동이 없으므로 종이의 ✧ 도 끈 채로 찍는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${1:-dist/store/mac}"
mkdir -p "$OUT"
VAULT="$(mktemp -d)/lazymemo-shots"
mkdir -p "$VAULT/vault/notes" "$VAULT/support"
trap 'rm -rf "$VAULT"' EXIT

# 스토어 판과 같은 얼굴 — Claude 없음, 시스템 달력 안 섞음(권한도 안 묻는다).
cat > "$VAULT/support/settings.json" <<'JSON'
{ "usesClaude": false, "showsSystemEvents": false, "greeted": true }
JSON

swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

W=1440; H=900
SCREEN="$(osascript -e 'tell application "Finder" to get bounds of window of desktop')"
SW="$(echo "$SCREEN" | awk -F', ' '{print $3}')"
SH="$(echo "$SCREEN" | awk -F', ' '{print $4}')"
[[ "$SW" -ge "$W" && "$SH" -ge "$H" ]] || { echo "✗ 화면(${SW}×${SH})이 무대(${W}×${H})보다 작다"; exit 1; }
X=$(( (SW - W) / 2 ))
TOP=$(( (SH - H) / 2 + 10 ))
Y=$(( SH - TOP - H ))

echo "▸ 무대 ${W}×${H} @ ${X},${TOP} (화면 ${SW}×${SH})"
LAZYMEMO_VAULT="$VAULT" LAZYMEMO_DEMO="$X,$Y,$W,$H" LAZYMEMO_SHOTS="$ROOT/$OUT" "$BIN" 2>&1 \
    | grep -E '^\[shots\]' || true

echo
for f in "$OUT"/*.png; do
    printf "  %-16s %s\n" "$(basename "$f")" "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
done
