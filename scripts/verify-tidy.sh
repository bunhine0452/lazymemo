#!/usr/bin/env bash
# 끝난 것이 스스로 물러나되, **물러났다고 메뉴가 말하는지** 검증한다
# (`{#auto-tidy}`, `{#tidy-visible-undo}`).
#
# 규칙이 맞는 것만으로는 부족하다. 다 체크한 목록과 지난 일정이 조용히
# 목록에서 빠지기만 하면 사람은 그것을 「정리됐다」가 아니라 「없어졌다」로
# 읽고, 없어지는 앱에는 아무것도 안 적는다. 그래서 여기서 재는 것은
# **메뉴에 몇 장이라고 적히는가**다.
#
# 메뉴는 시스템이 띄우는 창이라 렌더로도 캡처로도 잡히지 않으므로,
# 앱이 메뉴를 실제로 한 번 지어 항목을 적어 주는 통로(LAZYMEMO_MENU)를 쓴다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
VAULT="$(mktemp -d)/lazymemo-tidy"
NOTES="$VAULT/vault/notes/2026/08"
mkdir -p "$NOTES"
trap 'rm -rf "$VAULT"' EXIT

OLD="$(date -u -v-10d +%Y-%m-%dT%H:%M:%SZ)"
LONG_AGO="$(date -u -v-30d +%Y-%m-%d)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

note() { # id, frontmatter 추가줄, 본문
    cat > "$NOTES/$1.md" <<EOF
---
id: $1
created: $OLD
updated: $2
color: yellow
pinned: false
$3---
$4
EOF
}

# ① 다 체크한 목록 — 열흘 전에 손댔다. 물러나야 한다.
note 01K3ZQAAAAAAAAAAAAAAAAAAAA "$OLD" "" "장보기
- [x] 우유
- [x] 계란"
# ② 지난 일정 — 한 달 전. 물러나야 한다.
note 01K3ZQBBBBBBBBBBBBBBBBBBBB "$OLD" "due: $LONG_AGO
" "치과 예약"
# ③ 아직 남은 칸이 있다. 목록에 그대로 있어야 한다.
note 01K3ZQCCCCCCCCCCCCCCCCCCCC "$NOW" "" "이사 준비
- [x] 계약
- [ ] 박스"
# ④ 마감이 지난 미완료 목록 — 날짜 경과는 완료가 아니다 (인계서 R02). 그대로 있어야 한다.
note 01K3ZQDDDDDDDDDDDDDDDDDDDD "$OLD" "due: $LONG_AGO
" "서류 제출
- [ ] 등본 떼기"
# ⑤ 지난 약속에 앞으로 올 다시 보기 — 그날까지 살아 있어야 한다 (R01).
SOON="$(date -u -v+3d +%Y-%m-%dT09:00:00Z)"
note 01K3ZQEEEEEEEEEEEEEEEEEEEE "$OLD" "at: ${LONG_AGO}T15:00:00Z
surface: $SOON
" "견적 보내기"
# ⑥ 사람이 도로 꺼낸 지난 일정 — 규칙이 다시 치우지 않는다 (R03).
note 01K3ZQFFFFFFFFFFFFFFFFFFFF "$NOW" "due: $LONG_AGO
kept: $NOW
" "도로 꺼낸 약속"

OUT="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_MENU=1 "$BIN" 2>&1 || true)"

printf '%s\n' "$OUT" | sed -n '/메뉴/,$p'

case "$OUT" in
    *"치워 둔 2장"*) ;;
    *) echo "✗ 메뉴가 «치워 둔 2장» 이라고 적지 않았습니다 — 사라진 것으로 보입니다"; exit 1 ;;
esac
case "$OUT" in
    *"도로 꺼내기"*) ;;
    *) echo "✗ 한 번에 도로 꺼내는 길이 메뉴에 없습니다"; exit 1 ;;
esac
case "$OUT" in
    *"다 체크한 목록"*) ;;
    *) echo "✗ 무엇이 물러났는지 낱말로 적지 않았습니다"; exit 1 ;;
esac
case "$OUT" in
    *"지난 일정"*) ;;
    *) echo "✗ 지난 일정이 물러난 까닭으로 적히지 않았습니다"; exit 1 ;;
esac
case "$OUT" in
    *"이사 준비"*) ;;
    *) echo "✗ 아직 칸이 남은 목록까지 물러났습니다 — 그것은 아직 할 일입니다"; exit 1 ;;
esac
for kept in "서류 제출" "견적 보내기" "도로 꺼낸 약속"; do
    case "$OUT" in
        *"$kept"*) ;;
        *) echo "✗ «$kept» 이 물러났습니다 — 미완료 목록·앞으로 올 다시 보기·도로 꺼낸 것은 규칙이 이기지 못합니다"; exit 1 ;;
    esac
done
case "$OUT" in
    *"메모 4장"*) ;;
    *) echo "✗ 목록 수가 치운 것을 빼고 세어지지 않았습니다"; exit 1 ;;
esac

echo "✓ 끝난 둘은 물러나고, 메뉴가 «치워 둔 2장» 과 도로 꺼내는 길을 적습니다"
