#!/usr/bin/env bash
# 빠른 입력에서 ⌘V 가 실제로 사진을 넣는지 검증한다.
#
# 단위 시험(`CapturePasteTests`)은 텍스트 뷰의 `performKeyEquivalent` 를 직접
# 부른다. 그 함수가 하는 일은 지키지만 **키가 거기까지 오는지**는 재지 못한다 —
# 사람이 누른 ⌘V 는 앱 → 창 → 뷰 계층을 타고 내려오므로, 그 사이 어디가
# 끊겨도 시험은 초록이고 화면에서는 아무 일도 안 난다. "아직도 사진이 안
# 붙는다" 가 정확히 그 자리에 살 수 있다.
#
# 그래서 여기서는 **사람이 쓰는 클립보드**(.general)에 진짜 PNG 를 올리고,
# 이벤트도 `NSApp.sendEvent` 로 흘려보낸다.
#
# 주의: 이 스크립트는 클립보드를 덮어쓴다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
VAULT="$(mktemp -d)/lazymemo-paste"
mkdir -p "$VAULT/vault/notes"
PNG="$VAULT/clip.png"
trap 'rm -rf "$VAULT"' EXIT

# 8×8 붉은 사각형. 진짜 PNG 여야 붙임판이 public.png 를 들고 있다.
base64 -d > "$PNG" <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX/AAD///9BHTQRAAAADklE
QVQI12P4z8Awi2EGAAmDA0G4EX3lAAAAAElFTkSuQmCC
B64

osascript -e "set the clipboard to (read (POSIX file \"$PNG\") as «class PNGf»)"

# 사람이 겪는 조건은 **다른 앱이 앞에 있는 상태**다 — 단축키는 거기서 눌린다.
LAZYMEMO_VAULT="$VAULT" LAZYMEMO_PASTE=1 "$BIN" >"$VAULT/out.txt" 2>&1 &
APP_PID=$!
sleep 1
osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
wait "$APP_PID" || true
OUT="$(cat "$VAULT/out.txt")"
LINE="$(printf '%s\n' "$OUT" | grep '붙여넣기' || true)"

if [ -z "$LINE" ]; then
    echo "✗ 진단이 나오지 않았습니다"
    printf '%s\n' "$OUT"
    exit 1
fi

echo "▸ $LINE"

# 두 번 잰 결과가 **둘 다** 성공이어야 한다. 상자가 키 윈도가 아닌 순간은
# 실제로 있고, 사용자가 겪은 것이 바로 그쪽이다.
for ROUND in "키윈도없이" "키윈도로"; do
    PART="$(printf '%s\n' "$LINE" | sed -n "s/.*$ROUND{\([^}]*\)}.*/\1/p")"
    [ -n "$PART" ] || { echo "✗ $ROUND 결과가 없습니다"; exit 1; }
    case "$PART" in
        *"글자=true"*) ;;
        *) echo "✗ [$ROUND] 글자조차 들어가지 않았습니다 — 붙여넣기 이전의 문제입니다"; exit 1 ;;
    esac
    case "$PART" in
        *"넣음=1"*) ;;
        *) echo "✗ [$ROUND] ⌘V 를 눌렀는데 사진 참조가 본문에 들어오지 않았습니다"; exit 1 ;;
    esac
    case "$PART" in
        *"조각=1"*) ;;
        *) echo "✗ [$ROUND] 붙은 사진이 조각으로 보이지 않습니다 — 화면에서는 아무 일도 안 난 것과 같습니다"; exit 1 ;;
    esac
    case "$PART" in
        *"파일=true"*) ;;
        *) echo "✗ [$ROUND] 사진 파일이 Vault 에 남지 않았습니다"; exit 1 ;;
    esac
done

echo "✓ 빠른 입력에서 ⌘V 가 사진을 넣고, 조각으로 보이고, 파일로 남습니다"
