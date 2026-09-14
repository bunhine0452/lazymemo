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
#
# 서명은 셋 중 하나다 (설계문서 §12).
#   (없음)                    ad-hoc. 본인 실행용. 내려받은 앱에는 검역 딱지가 붙는다.
#   LAZYMEMO_SIGN_IDENTITY    "Developer ID Application: …" — 강화된 런타임으로 서명.
#     + LAZYMEMO_PROFILE      iCloud 컨테이너가 든 Developer ID 프로비저닝 프로필(.provisionprofile).
#                             있을 때만 Resources/LazyMemo.entitlements 가 붙는다 — 프로필 없이
#                             제한된 entitlement 를 달면 macOS 가 앱을 열어 주지 않는다.
#     + LAZYMEMO_NOTARY_PROFILE  `xcrun notarytool store-credentials` 로 저장한 이름.
#                             있으면 공증하고 스테이플한다. 이것까지 되면 cask 의
#                             검역 딱지 떼기(§12.2)가 필요 없어진다.
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
# SPM 이 만든 리소스 번들(메뉴바 아이콘·번역 표)도 함께 넣는다.
cp -R "$BIN_PATH"/*.bundle "$APP/Contents/Resources/" 2>/dev/null || true
# 앱 번들이 어떤 말을 하는지는 이 폴더들이 말한다 — 없으면 macOS 가 영어 사용자에게도
# 개발 언어만 보이고, 패키지 번들의 번역 표는 쓰이지 않는다 (Words.swift).
cp -R "$ROOT"/Resources/*.lproj "$APP/Contents/Resources/"
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

IDENTITY="${LAZYMEMO_SIGN_IDENTITY:-}"
PROFILE="${LAZYMEMO_PROFILE:-}"
NOTARY="${LAZYMEMO_NOTARY_PROFILE:-}"

if [[ -z "$IDENTITY" ]]; then
    # ad-hoc 서명. 유료 개발자 계정 없이 로컬 실행에 필요한 전부다 (설계문서 §12).
    echo "▸ ad-hoc 서명"
    codesign --force --sign - "$APP"
else
    echo "▸ Developer ID 서명: $IDENTITY"
    ENTITLEMENT_FLAGS=()
    if [[ -n "$PROFILE" ]]; then
        cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
        ENTITLEMENT_FLAGS=(--entitlements "$ROOT/Resources/LazyMemo.entitlements")
        echo "  프로필 포함 → iCloud 컨테이너 entitlement 를 붙인다"
    else
        echo "  프로필 없음 → iCloud entitlement 없이 서명한다 (Mobile Documents 폴더로는 여전히 동기화된다)"
    fi
    # 안에 든 실행 파일부터. --deep 은 순서를 보장하지 않아 공증에서 걸린다.
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
        "$APP/Contents/MacOS/lazymemo-mcp"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
        ${ENTITLEMENT_FLAGS[@]+"${ENTITLEMENT_FLAGS[@]}"} "$APP"
fi
codesign --verify --verbose=1 "$APP"

if [[ -n "$IDENTITY" && -n "$NOTARY" ]]; then
    echo "▸ 공증 (notarytool: $NOTARY)"
    NOTARY_ZIP="$(mktemp -d)/LazyMemo.zip"
    ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY" --wait
    xcrun stapler staple "$APP"
    spctl -a -t exec -vv "$APP"
    rm -f "$NOTARY_ZIP"
fi

echo
echo "✓ $APP  ($(du -sh "$APP" | cut -f1))"
echo "  실행: open $APP"
