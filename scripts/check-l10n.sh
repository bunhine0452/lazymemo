#!/usr/bin/env bash
# 영어 표가 코드를 다 덮는지 본다 — 한국어 열쇠 중 en.lproj 에 없는 것, 코드에서 사라진 열쇠.
#
#   ./scripts/check-l10n.sh            # 패키지 넷(Core·UI·MCP·Reminders)
#   ./scripts/check-l10n.sh --ios      # + 아이폰 앱·공유 확장 (시뮬레이터 빌드가 한 번 돈다)
#
# 열쇠는 손으로 긁지 않고 컴파일러에게 묻는다(-emit-localized-strings) — 보간의 %lld·%@ 와
# 여러 줄 리터럴의 줄바꿈까지 코드가 실제로 찾는 모양 그대로 나온다. 빠진 열쇠가 있으면
# 영어 사용자에게 그 자리에 한국어가 보인다 (Sources/LazyMemoCore/Words.swift).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ 패키지 열쇠 추출"
for TARGET in LazyMemoCore LazyMemoUI LazyMemoMCP LazyMemoReminders; do
    mkdir -p "$WORK/$TARGET"
    # 이미 지어진 파일은 다시 안 짓는다 — 손대서 전부 다시 짓게 한다.
    find "Sources/$TARGET" -name '*.swift' -exec touch {} +
    swift build --scratch-path "$WORK/build" --target "$TARGET" \
        -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$WORK/$TARGET" \
        2>&1 | grep -E "error:" || true
done
IOS_DERIVED=""
if [[ "${1:-}" == "--ios" ]]; then
    IOS_DERIVED="$WORK/ios"
    echo "▸ 아이폰 열쇠 추출 (시뮬레이터 빌드)"
    ( cd ios && xcodebuild -project LazyMemo.xcodeproj -scheme LazyMemo-iOS -configuration Debug \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$IOS_DERIVED" \
        CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=YES build 2>&1 | grep -E "error:|BUILD" ) || true
fi

WORK="$WORK" IOS_DERIVED="$IOS_DERIVED" python3 - <<'PY'
import glob, json, os, plistlib, re, sys

work = os.environ["WORK"]; ios = os.environ["IOS_DERIVED"]
HANGUL = re.compile(r"[가-힣]")

def extracted(pattern, source_prefix):
    keys = {}
    for f in glob.glob(pattern, recursive=True):
        d = json.load(open(f))
        if source_prefix not in d["source"]: continue
        for entries in d["tables"].values():
            for e in entries:
                if HANGUL.search(e["key"]):
                    keys.setdefault(e["key"], f'{os.path.basename(d["source"])}:{e["location"]["startingLine"]}')
    return keys

def table(lproj):
    keys = set()
    strings = os.path.join(lproj, "Localizable.strings")
    if os.path.exists(strings):
        # .strings 는 plist 가 아니라 직접 읽는다 — "key" = "value"; 꼴, 열쇠 안의 \" 와 \n 을 푼다.
        text = open(strings, encoding="utf-8").read()
        for m in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=', text, re.M):
            keys.add(m.group(1).replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\"))
    sd = os.path.join(lproj, "Localizable.stringsdict")
    if os.path.exists(sd):
        with open(sd, "rb") as f:
            keys |= set(plistlib.load(f).keys())
    return keys

modules = [
    ("LazyMemoCore", f"{work}/LazyMemoCore/*.stringsdata", "/Sources/LazyMemoCore/", "Sources/LazyMemoCore/Resources"),
    ("LazyMemoUI",   f"{work}/LazyMemoUI/*.stringsdata",   "/Sources/LazyMemoUI/",   "Sources/LazyMemoUI/Resources"),
    ("LazyMemoMCP",  f"{work}/LazyMemoMCP/*.stringsdata",  "/Sources/LazyMemoMCP/",  "Sources/LazyMemoMCP/Resources"),
    ("LazyMemoReminders", f"{work}/LazyMemoReminders/*.stringsdata", "/Sources/LazyMemoReminders/", "Sources/LazyMemoReminders/Resources"),
]
if ios:
    modules += [
        ("iOS",   f"{ios}/Build/Intermediates.noindex/**/*.stringsdata", "/ios/LazyMemo/",      "ios/LazyMemo"),
        ("Share", f"{ios}/Build/Intermediates.noindex/**/*.stringsdata", "/ios/LazyMemoShare/", "ios/LazyMemoShare"),
    ]

trouble = 0
for name, pattern, prefix, resources in modules:
    code = extracted(pattern, prefix)
    en = table(os.path.join(resources, "en.lproj"))
    ko = table(os.path.join(resources, "ko.lproj"))   # 뜻이 갈려 따로 적은 열쇠는 코드에도 있다
    missing = sorted(k for k in code if k not in en)
    stale = sorted(k for k in en if k not in code and k not in ko)
    print(f"{name}: 코드 {len(code)} · en {len(en)} · 빠짐 {len(missing)} · 남음 {len(stale)}")
    for k in missing:
        print(f"  ✗ 빠짐  {code[k]}  {k[:70]!r}")
    for k in stale:
        print(f"  · 남음  {k[:70]!r}")
    trouble += len(missing)
sys.exit(1 if trouble else 0)
PY
