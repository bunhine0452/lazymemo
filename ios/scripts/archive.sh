#!/usr/bin/env bash
# 아이폰·맥 앱을 아카이브하고 TestFlight 로 올린다.
#
#   ./ios/scripts/archive.sh                  # 아이폰: 아카이브 + 업로드
#   ./ios/scripts/archive.sh mac              # 맥 App Store 판: 아카이브 + 업로드
#   ./ios/scripts/archive.sh [mac] --no-upload  # 아카이브만 (build/ios/<판>.xcarchive)
#
# 전제: Xcode 에 개발자 계정이 로그인돼 있고(자동 서명 — Xcode › Settings › Accounts),
# App Store Connect 에 앱 레코드가 있다. 맥 판은 아카이브 단계에서 개발용 프로필을 먼저
# 쓰는데 그 프로필은 등록된 기기가 있어야 만들어진다 — 이 맥을 xcodebuild 가 스스로
# 등록하게 `-allowProvisioningDeviceRegistration` 을 준다 (첫 번에 한 번만 실제로 등록). 판 번호는 ios/LazyMemo.xcodeproj 의
# MARKETING_VERSION, 빌드 번호는 App Store Connect 가 올린다(manageAppVersionAndBuildNumber).
#
# 맥 판은 GitHub 판(scripts/build-app.sh)과 다른 물건이다 — 샌드박스 안이고
# Claude 연동이 없다 (Config/Mac-Info.plist 의 LazyMemoAppStoreBuild). 같은 번들
# id 라 App Store Connect 에서는 한 앱의 두 플랫폼이다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLATFORM=ios
UPLOAD=1
for arg in "$@"; do
    case "$arg" in
        mac) PLATFORM=mac ;;
        --no-upload) UPLOAD=0 ;;
        *) echo "모르는 인자: $arg"; exit 2 ;;
    esac
done

if [[ "$PLATFORM" == "mac" ]]; then
    SCHEME=LazyMemo-macOS
    DESTINATION='generic/platform=macOS'
    ARCHIVE="$ROOT/build/ios/LazyMemo-macOS.xcarchive"
else
    SCHEME=LazyMemo-iOS
    DESTINATION='generic/platform=iOS'
    ARCHIVE="$ROOT/build/ios/LazyMemo.xcarchive"
fi
EXPORT="$ROOT/build/ios/export-$PLATFORM"

cd "$ROOT/ios"
echo "▸ 아카이브 ($SCHEME) → $ARCHIVE"
rm -rf "$ARCHIVE"
xcodebuild archive \
    -project LazyMemo.xcodeproj -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    | grep -E 'error:|warning: .*sign|ARCHIVE' || true

[[ -d "$ARCHIVE" ]] || { echo "아카이브가 없다"; exit 1; }
APP="$ARCHIVE/Products/Applications/LazyMemo.app"
ENTITLEMENTS="$(codesign -d --entitlements - "$APP" 2>/dev/null)"
grep -E 'icloud-container-identifiers' <<<"$ENTITLEMENTS" >/dev/null && echo "  iCloud entitlement ✓"
if [[ "$PLATFORM" == "mac" ]]; then
    # 스토어는 샌드박스 없는 맥 앱을 받지 않는다. 여기서 안 보면 업로드가 대신 본다.
    grep -E 'app-sandbox' <<<"$ENTITLEMENTS" >/dev/null \
        && echo "  App Sandbox ✓" || { echo "  App Sandbox 가 없다"; exit 1; }
    /usr/libexec/PlistBuddy -c 'Print :LazyMemoAppStoreBuild' "$APP/Contents/Info.plist" >/dev/null \
        && echo "  LazyMemoAppStoreBuild ✓"
else
    grep -E 'application-groups' <<<"$ENTITLEMENTS" >/dev/null && echo "  App Group entitlement ✓"
fi

if [[ "$UPLOAD" == "1" ]]; then
    echo "▸ TestFlight 로 업로드"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist Config/ExportOptions.plist \
        -exportPath "$EXPORT" \
        -allowProvisioningUpdates \
        | grep -E 'error:|EXPORT|Upload' || true
fi
