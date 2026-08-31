#!/usr/bin/env bash
# LazyMemo.app 번들을 조립하고 ad-hoc 서명한다.
# Xcode 없이 Command Line Tools 만으로 동작한다 (설계문서 §3).
#
#   ./scripts/build-app.sh            # release 빌드
#   ./scripts/build-app.sh debug      # debug 빌드
#
# LAZYMEMO_OSIZE=1 을 주면 코드 크기 우선(-Osize)으로 컴파일한다. 실행 파일이
# 약 225KB 더 줄지만 속도를 내주는 거래라, 켠 뒤에는 반드시
# ./scripts/measure-capture.sh 로 150ms 예산을 다시 재야 한다 (설계문서 §11).
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/LazyMemo.app"

cd "$ROOT"

SIZE_FLAGS=""
if [[ "${LAZYMEMO_OSIZE:-0}" == "1" ]]; then
    SIZE_FLAGS="-Xswiftc -Osize -Xlinker -dead_strip"
fi

echo "▸ swift build -c $CONFIG $SIZE_FLAGS"
swift build -c "$CONFIG" $SIZE_FLAGS
BIN_PATH="$(swift build -c "$CONFIG" $SIZE_FLAGS --show-bin-path)"

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

# 심볼 테이블을 턴다. 번들의 절반이 디버거용 이름표라 그냥 두면 3.8MB 가 나간다.
# dSYM 은 .build 에 그대로 남으므로 크래시 로그 심볼화는 여전히 된다.
# 반드시 서명 앞에서 해야 한다 — 뒤에 털면 서명이 깨진다.
if [[ "$CONFIG" == "release" ]]; then
    echo "▸ 심볼 스트립"
    for BIN in "$APP/Contents/MacOS/LazyMemo" "$APP/Contents/MacOS/lazymemo-mcp"; do
        BEFORE=$(stat -f%z "$BIN")
        strip -rSTx "$BIN"
        printf '  %s: %s → %s bytes\n' "$(basename "$BIN")" "$BEFORE" "$(stat -f%z "$BIN")"
    done
fi

# ad-hoc 서명. 유료 개발자 계정 없이 로컬 실행에 필요한 전부다 (설계문서 §12).
echo "▸ ad-hoc 서명"
codesign --force --sign - "$APP"
codesign --verify --verbose=1 "$APP"

echo
echo "✓ $APP  ($(du -sh "$APP" | cut -f1))"
echo "  실행: open $APP"
