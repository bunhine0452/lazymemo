#!/usr/bin/env bash
# 빠른 입력 상자가 **다른 앱 창이 앞에 있을 때도** 화면에 오르는지 검증한다.
#
# 사용자가 겪은 결함: 다른 프로그램 창이 떠 있으면 단축키를 눌러도 상자가
# 안 보였다. 원인은 패널의 hidesOnDeactivate — NSApp.activate() 가 비동기라
# 창을 올리는 순간 앱은 아직 비활성이고, AppKit 이 그 창을 즉시 내렸다.
#
# 단축키를 프로그램으로 누르려면 손쉬운 사용 권한이 필요하므로, 앱이 스스로
# 상자를 여는 통로(LAZYMEMO_CAPTURE=<초>)를 쓰고 그 사이에 Finder 를 앞으로 세운다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VAULT="$(mktemp -d)/lazymemo-capture"
mkdir -p "$VAULT/vault/notes"

# 여러 번 잇달아 돌릴 때는 SwiftPM 잠금이 부딪히므로 건너뛸 수 있게 둔다.
[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
pkill -f "$BIN" 2>/dev/null || true

LAZYMEMO_VAULT="$VAULT" LAZYMEMO_CAPTURE=4 "$BIN" &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true; rm -rf "$VAULT"' EXIT

# 상자가 열리기 전에 다른 앱을 앞으로. 이것이 재현 조건이다.
sleep 1
osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
echo "▸ Finder 를 앞으로 세움 — 이제 lazymemo 는 비활성 상태"
sleep 5

if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "✗ 앱이 떠 있지 않습니다 — 검증 불가"
    exit 1
fi

FRONT="$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || echo "?")"
echo "▸ 지금 맨 앞 앱: $FRONT"

swift - "$APP_PID" <<'SWIFT'
import AppKit

let pid = Int32(CommandLine.arguments[1])!
let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let mine = onScreen.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
let everything = all.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }

print("  (우리 프로세스의 창: 화면 위 \(mine.count)개 / 전부 \(everything.count)개)")
for window in everything {
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let level = window[kCGWindowLayer as String] as? Int ?? -999
    let onscreen = (window[kCGWindowIsOnscreen as String] as? Bool) ?? false
    print(String(format: "    전체목록 level=%d %.0f×%.0f onscreen=%@",
                 level, bounds["Width"] ?? 0, bounds["Height"] ?? 0, onscreen ? "yes" : "no"))
}

var found = false
for window in mine {
    guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
          let level = window[kCGWindowLayer as String] as? Int else { continue }
    let width = bounds["Width"] ?? 0
    print(String(format: "  window level=%d  %.0f×%.0f", level, width, bounds["Height"] ?? 0))
    // 빠른 입력 상자는 440 폭에 floating(3) 레벨이다.
    if level == Int(CGWindowLevelForKey(.floatingWindow)), abs(width - 440) < 1 { found = true }
}

if found {
    print("\n✓ 다른 앱이 앞에 있어도 빠른 입력 상자가 화면에 올라왔습니다")
    exit(0)
}
print("\n✗ 상자가 화면에 없습니다 — 다른 앱 위에서 열리지 않습니다")
exit(1)
SWIFT
