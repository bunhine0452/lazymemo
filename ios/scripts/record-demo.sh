#!/usr/bin/env bash
# 폰 소개 영상을 찍는다 — 시뮬레이터에서 앱이 스스로 한 바퀴 돌고(`DemoTests`),
# 그 화면을 기록한다. 맥 쪽은 `scripts/record-demo.sh`.
#
#   ./ios/scripts/record-demo.sh        # → site/media/phone.mp4 · phone.gif · phone-poster.jpg
#
# 배너 장면은 이 스크립트가 넣는다: 시험이 `push` 파일에 메모 id 를 적으면
# `simctl push` 로 그 메모의 알림을 보낸다 — 시험은 시뮬레이터 밖의 명령을 못 부른다.
# 앱을 먼저 지워 알림 권한 창이 한 번 뜨게 한다 (영상의 「알림 켜기」 장면).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${LAZYMEMO_SIM:-iPhone 17}"
BUNDLE="io.github.bunhine0452.lazymemo"
OUT="${1:-$ROOT/site/media}"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v ffmpeg >/dev/null || { echo "✗ ffmpeg 가 필요합니다 (brew install ffmpeg)"; exit 1; }

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl location "$DEVICE" set 37.4979,127.0276
xcrun simctl privacy "$DEVICE" grant location "$BUNDLE" 2>/dev/null || true
xcrun simctl spawn "$DEVICE" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true 2>/dev/null || true
xcrun simctl ui "$DEVICE" appearance light
# 상태 막대는 깨끗하게 — 시각은 그대로 둔다 (「한 시간 뒤」가 진짜 시계를 본다).
xcrun simctl status_bar "$DEVICE" override --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName "" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true

RAW="$WORK/raw.mov"
echo "▸ 녹화 시작 ($DEVICE)"
xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$RAW" 2>/dev/null &
REC_PID=$!
REC_START="$(python3 -c 'import time; print(time.time())')"

echo "▸ 주행 (DemoTests)"
cd "$ROOT/ios"
TEST_RUNNER_LAZYMEMO_DEMO=1 TEST_RUNNER_LAZYMEMO_DEMO_SIGNAL="$WORK" xcodebuild test \
    -project LazyMemo.xcodeproj -scheme LazyMemo-iOS \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "${LAZYMEMO_DERIVED:-$ROOT/.build/ios}" \
    -only-testing:"LazyMemoUITests/DemoTests" > "$WORK/xcodebuild.log" 2>&1 &
TEST_PID=$!

# 시험이 배너를 청하면 보낸다.
while kill -0 "$TEST_PID" 2>/dev/null; do
    if [[ -f "$WORK/push" ]]; then
        ID="$(cat "$WORK/push")"; rm -f "$WORK/push"
        cat > "$WORK/payload.json" <<JSON
{"aps":{"alert":{"title":"치과 예약","body":"다시 볼 시간이에요. 눌러서 메모를 펼치세요."},"sound":"default"},"memo":"$ID"}
JSON
        sleep 0.8
        xcrun simctl push "$DEVICE" "$BUNDLE" "$WORK/payload.json" >/dev/null && echo "▸ 배너 보냄 ($ID)"
    fi
    sleep 0.3
done
wait "$TEST_PID" || { echo "✗ 주행 실패"; grep -E "error:|failed" "$WORK/xcodebuild.log" | sort -u | head -20; kill -INT "$REC_PID" 2>/dev/null; exit 1; }
sleep 0.6
kill -INT "$REC_PID"
wait "$REC_PID" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE" clear 2>/dev/null || true
cd "$ROOT"

[ -s "$RAW" ] || { echo "✗ 녹화 파일이 비어 있습니다"; exit 1; }
[ -f "$WORK/ready" ] && [ -f "$WORK/done" ] || { echo "✗ 주행 신호가 없습니다"; exit 1; }
START="$(python3 -c "print(round($(cat "$WORK/ready") - $REC_START - 0.3, 2))")"
LENGTH="$(python3 -c "print(round($(cat "$WORK/done") - $(cat "$WORK/ready") + 0.3, 2))")"
echo "▸ 앞 ${START}s 자르고 ${LENGTH}s"

echo "▸ mp4"
ffmpeg -v error -y -ss "$START" -i "$RAW" -t "$LENGTH" \
    -vf "scale=590:-2:flags=lanczos,fps=30" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -preset slow -movflags +faststart -an \
    "$OUT/phone.mp4"
echo "▸ gif"
ffmpeg -v error -y -i "$OUT/phone.mp4" \
    -vf "fps=12,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$OUT/phone.gif"
echo "▸ poster"
ffmpeg -v error -y -ss 1.0 -i "$OUT/phone.mp4" -frames:v 1 -q:v 3 "$OUT/phone-poster.jpg"

ls -la "$OUT"/phone.mp4 "$OUT"/phone.gif "$OUT"/phone-poster.jpg
echo "✓ $OUT"
