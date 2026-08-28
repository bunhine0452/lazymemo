#!/usr/bin/env bash
# LazyMemo.app 번들을 조립하고 ad-hoc 서명한다.
# Xcode 없이 Command Line Tools 만으로 동작한다 (설계문서 §3).
#
#   ./scripts/build-app.sh            # release 빌드
#   ./scripts/build-app.sh debug      # debug 빌드
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/LazyMemo.app"

cd "$ROOT"

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ 번들 조립 → dist/LazyMemo.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/LazyMemo" "$APP/Contents/MacOS/LazyMemo"
# MCP 서버도 번들 안에 둔다. Claude Desktop 의 설정이 가리킬 경로가
# swift build 산출물이면 리빌드나 clean 에 끊어진다 (설계문서 §9).
cp "$BIN_PATH/lazymemo-mcp" "$APP/Contents/MacOS/lazymemo-mcp"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# SPM 이 만든 리소스 번들(메뉴바 아이콘)도 함께 넣는다.
cp -R "$BIN_PATH"/*.bundle "$APP/Contents/Resources/" 2>/dev/null || true
printf 'APPL????' > "$APP/Contents/PkgInfo"

# ad-hoc 서명. 유료 개발자 계정 없이 로컬 실행에 필요한 전부다 (설계문서 §12).
echo "▸ ad-hoc 서명"
codesign --force --sign - "$APP"
codesign --verify --verbose=1 "$APP"

echo
echo "✓ $APP"
echo "  실행: open $APP"
