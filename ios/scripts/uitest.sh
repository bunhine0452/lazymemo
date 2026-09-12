#!/usr/bin/env bash
# 폰 UI 시험 — 맥의 scripts/verify-*.sh 자리 (MOBILE_DESIGN §12).
#
#   ./ios/scripts/uitest.sh                 # 전부
#   ./ios/scripts/uitest.sh testHerePin…    # 하나 (이름 일부)
#
# 시뮬레이터에 자리와 위치 권한을 미리 준다 — 「지금 여기」 시험이 시스템의
# 권한 창을 기다리지 않게. 실기기의 첫 누름은 그 창을 진짜로 띄운다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${LAZYMEMO_SIM:-iPhone 17}"
BUNDLE="io.github.bunhine0452.lazymemo"
ONLY="${1:-}"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl location "$DEVICE" set 37.4979,127.0276
xcrun simctl privacy "$DEVICE" grant location "$BUNDLE" 2>/dev/null || true

FILTER=()
if [[ -n "$ONLY" ]]; then
    FILTER=(-only-testing:"LazyMemoUITests/SmokeTests/$ONLY")
fi

cd "$ROOT/ios"
xcodebuild test \
    -project LazyMemo.xcodeproj -scheme LazyMemo-iOS \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "${LAZYMEMO_DERIVED:-$ROOT/.build/ios}" \
    ${FILTER[@]+"${FILTER[@]}"} 2>&1 \
    | grep -E 'error:|Test Case.*(passed|failed)|TEST |XCTAssert' | sort -u
