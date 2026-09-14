#!/usr/bin/env bash
# 소개 영상을 찍는다 — 실제 앱을 화면의 한 구역에 세우고 스스로 한 바퀴 돌게 한 뒤
# (`DemoTour`), 그 구역만 화면 기록으로 담는다. 폰 쪽은 `ios/scripts/record-demo.sh`.
#
#   ./scripts/record-demo.sh            # → site/media/demo.mp4 · demo.gif · demo-poster.jpg
#
# 화면 기록 권한이 있어야 한다 (시스템 설정 → 개인정보 보호 → 화면 기록에 이
# 셸을 띄운 앱). 없으면 검은 영상이 나온다. 도는 동안 다른 앱의 창은 잠깐 숨는다 —
# 무대를 가리면 찍히는 것이 그 창이기 때문이다. 끝나면 도로 나온다.
#
# 임시 Vault 를 쓰므로 실제 메모는 건드리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${1:-site/media}"
mkdir -p "$OUT"
VAULT="$(mktemp -d)/lazymemo-demo"
mkdir -p "$VAULT/vault/notes"
trap 'rm -rf "$VAULT"' EXIT

command -v ffmpeg >/dev/null || { echo "✗ ffmpeg 가 필요합니다 (brew install ffmpeg)"; exit 1; }
# 잠긴 화면은 잠금 화면이 찍힌다 — 앱은 돌지만 보이지 않는다.
if ioreg -n Root -d1 -a 2>/dev/null | grep -A1 CGSSessionScreenIsLocked | grep -q '<true/>'; then
    echo "✗ 화면이 잠겨 있습니다 — 잠금을 풀고 다시 돌리세요"; exit 1
fi

# 번들로 짓는다 — 다시 보기 창의 알림 절은 번들 안에서만 「켤 수 있는」 모양이다
# (`ReminderCenter.available`). 켜지는 않으므로 권한 창은 뜨지 않는다.
./scripts/build-app.sh >/dev/null
BIN="$ROOT/dist/LazyMemo.app/Contents/MacOS/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

# 무대 — 화면 위쪽 한가운데 1280×800 (포인트). 화면 기록은 왼쪽 위 원점,
# AppKit 은 왼쪽 아래 원점이라 세로만 뒤집어 넘긴다.
W=1280; H=800
SCREEN="$(osascript -e 'tell application "Finder" to get bounds of window of desktop')"
SW="$(echo "$SCREEN" | awk -F', ' '{print $3}')"
SH="$(echo "$SCREEN" | awk -F', ' '{print $4}')"
X=$(( (SW - W) / 2 ))
TOP=$(( (SH - H) / 2 + 10 ))
Y=$(( SH - TOP - H ))

RAW="$VAULT/raw.mov"
echo "▸ 무대 ${W}×${H} @ ${X},${TOP} (화면 ${SW}×${SH}) — 녹화 시작"
screencapture -x -V 55 -R "$X,$TOP,$W,$H" "$RAW" &
REC_PID=$!
sleep 1.0

START=$(date +%s.%N)
LAZYMEMO_VAULT="$VAULT" LAZYMEMO_DEMO="$X,$Y,$W,$H" "$BIN" >/dev/null 2>&1 || true
END=$(date +%s.%N)
# 앱이 돈 만큼만 남긴다 — 녹화는 넉넉히 걸어 두었다.
LENGTH="$(python3 -c "print(round($END - $START - 2.0, 2))")"
echo "▸ 앱 주행 ${LENGTH}s — 녹화가 끝나기를 기다린다"
wait "$REC_PID" || true

[ -s "$RAW" ] || { echo "✗ 녹화 파일이 비어 있습니다 — 화면 기록 권한을 확인하세요"; exit 1; }

echo "▸ mp4"
ffmpeg -v error -y -ss 2.6 -i "$RAW" -t "$LENGTH" \
    -vf "scale=1280:-2:flags=lanczos,fps=30" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -preset slow -movflags +faststart -an \
    "$OUT/demo.mp4"

echo "▸ gif"
ffmpeg -v error -y -i "$OUT/demo.mp4" \
    -vf "fps=12,scale=880:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$OUT/demo.gif"

echo "▸ poster"
ffmpeg -v error -y -ss 1.2 -i "$OUT/demo.mp4" -frames:v 1 -q:v 3 "$OUT/demo-poster.jpg"

echo
ls -la "$OUT"/demo.mp4 "$OUT"/demo.gif "$OUT"/demo-poster.jpg
echo "✓ $OUT"
