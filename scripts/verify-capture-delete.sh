#!/usr/bin/env bash
# 빠른 입력의 목록에서 ⌘⌫ 가 실제로 메모를 지우는지 검증한다.
#
# 키가 어디로 가는지는 화면에 나타나지 않는다. ⌘⌫ 는 원래 "줄 앞까지 지우기"
# 라는 글 편집 키이고(`deleteToBeginningOfLine:`), 우리는 고른 줄이 있을 때만
# 그것을 가로챈다. 가로채기가 끊기면 **메모는 그대로인 채 글자만 지워지는데**,
# 그림으로도 렌더로도 그 차이가 보이지 않는다.
#
# 게다가 이 상자는 `.nonactivatingPanel` 이라 ⌘ 조합이 글 쓰는 곳까지 닿지
# 못한 전력이 있다 (⌘V 가 죽었던 일 — `MemoNSTextView`). 그래서 앱 안에서
# 가짜 키를 눌러 보고 파일이 실제로 휴지통으로 옮겨졌는지까지 확인한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
VAULT="$(mktemp -d)/lazymemo-delete"
mkdir -p "$VAULT/vault/notes"
trap 'rm -rf "$VAULT"' EXIT

OUT="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_DELETE=1 "$BIN" 2>&1 || true)"
LINE="$(printf '%s\n' "$OUT" | grep '목록지우기' || true)"

if [ -z "$LINE" ]; then
    echo "✗ 진단이 나오지 않았습니다"
    printf '%s\n' "$OUT"
    exit 1
fi

echo "▸ $LINE"

case "$LINE" in
    *"지움=true"*) ;;
    *) echo "✗ ⌘⌫ 를 눌렀는데 메모가 휴지통으로 가지 않았습니다"; exit 1 ;;
esac
case "$LINE" in
    *"글유지=true"*) ;;
    *) echo "✗ 메모 대신 적던 글이 지워졌습니다 — 가로채기가 끊겼습니다"; exit 1 ;;
esac
case "$LINE" in
    *"되돌릴수있음=true"*) ;;
    *) echo "✗ 되돌리는 줄이 상자에 남지 않았습니다"; exit 1 ;;
esac

echo "✓ ⌘⌫ 는 고른 메모를 지우고, 적던 글은 건드리지 않습니다"
