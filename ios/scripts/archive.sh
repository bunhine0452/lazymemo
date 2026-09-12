#!/usr/bin/env bash
# 아이폰 앱을 아카이브하고 TestFlight 로 올린다.
#
#   ./ios/scripts/archive.sh            # 아카이브 + 업로드
#   ./ios/scripts/archive.sh --no-upload  # 아카이브만 (build/ios/LazyMemo.xcarchive)
#
# 전제: Xcode 에 개발자 계정이 로그인돼 있고(자동 서명), App Store Connect 에
# 앱 레코드가 있다. 판 번호는 ios/LazyMemo.xcodeproj 의 MARKETING_VERSION,
# 빌드 번호는 App Store Connect 가 올린다(manageAppVersionAndBuildNumber).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE="$ROOT/build/ios/LazyMemo.xcarchive"
EXPORT="$ROOT/build/ios/export"
UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

cd "$ROOT/ios"
echo "▸ 아카이브 → $ARCHIVE"
xcodebuild archive \
    -project LazyMemo.xcodeproj -scheme LazyMemo-iOS \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    | grep -E 'error:|warning: .*sign|ARCHIVE' || true

[[ -d "$ARCHIVE" ]] || { echo "아카이브가 없다"; exit 1; }
codesign -d --entitlements - "$ARCHIVE/Products/Applications/LazyMemo.app" 2>/dev/null \
    | grep -E 'icloud-container-identifiers|application-groups' >/dev/null \
    && echo "  iCloud·App Group entitlement ✓"

if [[ "$UPLOAD" == "1" ]]; then
    echo "▸ TestFlight 로 업로드"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist Config/ExportOptions.plist \
        -exportPath "$EXPORT" \
        -allowProvisioningUpdates \
        | grep -E 'error:|EXPORT|Upload' || true
fi
