#!/usr/bin/env bash
# 배포용 zip 을 만들고 Homebrew cask 가 필요로 하는 값을 뱉는다 (설계문서 §12).
#
#   ./scripts/package-release.sh
#
# 결과: dist/lazymemo-<버전>.zip · sha256 · 붙일 URL
#
# **`ditto` 로 묶는다.** `zip` 은 확장 속성과 심볼릭 링크를 흘려서 서명이
# 깨진다 — 받은 쪽에서 "손상되었다" 가 되고, 그건 서명이 실제로 깨진 것이라
# 검역 딱지와 무관하게 열리지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="$ROOT/dist/LazyMemo.app"
ZIP="$ROOT/dist/lazymemo-$VERSION.zip"

"$ROOT/scripts/build-app.sh" release

echo
echo "▸ ditto → $(basename "$ZIP")"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# 묶은 것을 도로 풀어 서명이 살아 있는지 본다. 여기서 안 보면 사용자가 대신 본다.
CHECK="$(mktemp -d)"
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$ZIP" "$CHECK"
codesign --verify --deep --strict "$CHECK/LazyMemo.app"
echo "  서명 확인 ✓ (풀어서 다시 검사)"

SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

echo
echo "✓ $ZIP  ($(du -h "$ZIP" | cut -f1))"
echo
echo "  version  $VERSION"
echo "  sha256   $SHA"
echo "  url      https://github.com/bunhine0452/lazymemo/releases/download/v$VERSION/$(basename "$ZIP")"
echo
echo "  올리기:  gh release upload v$VERSION \"$ZIP\""
