#!/usr/bin/env bash
# 처리 상태가 **메뉴에 말로 서는지** 검증한다 (인계서 묶음 4 `#unfinished-recall`, 맥).
#
# 「지금」의 세 장이 전부가 아니다 — 놓친 것·오늘·나중에가 한 줄로 서고, 놓친 것은 하위 메뉴에서
# 열고·끝내고·보관하고·미룬다. 보관한 것은 지운 것과 따로 세어지고, 끝낸 것은 목록에 남아 있다
# (끝낸 순간 사라지면 사고). 메뉴는 시스템 창이라 렌더로 못 잡으므로 `verify-tidy.sh` 와 같은
# 통로(LAZYMEMO_MENU)를 쓴다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ "${LAZYMEMO_SKIP_BUILD:-}" = "1" ] || swift build >/dev/null
BIN="$(swift build --show-bin-path)/LazyMemo"
VAULT="$(mktemp -d)/lazymemo-state"
NOTES="$VAULT/vault/notes/2026/09"
mkdir -p "$NOTES"
trap 'rm -rf "$VAULT"' EXIT

OLD="$(date -u -v-10d +%Y-%m-%dT%H:%M:%SZ)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
YESTERDAY_9="$(date -u -v-1d +%Y-%m-%dT00:00:00Z)"
# 날짜만 있는 값은 **이 기계의 날**로 — UTC 로 재면 저녁의 「내일」이 오늘이 된다.
LONG_AGO="$(date -v-30d +%Y-%m-%d)"
TOMORROW="$(date -v+1d +%Y-%m-%d)"

note() { # id, updated, frontmatter 추가줄, 본문
    cat > "$NOTES/$1.md" <<EOF2
---
id: $1
created: $OLD
updated: $2
color: yellow
pinned: false
$3---
$4
EOF2
}

# ① 어제 다시 보기로 했는데 안 본 것 — 놓친 것.
note 01K3ZQAAAAAAAAAAAAAAAAAAAA "$OLD" "surface: $YESTERDAY_9
" "읽을 글 — 게으른 사람"
# ② 마감이 지난 칸 남은 목록 — 놓친 것 (정리가 치우지 않는다, R02).
note 01K3ZQBBBBBBBBBBBBBBBBBBBB "$OLD" "due: $LONG_AGO
" "서류 제출
- [ ] 등본"
# ③ 내일 일정 — 나중에.
note 01K3ZQCCCCCCCCCCCCCCCCCCCC "$NOW" "due: $TOMORROW
" "내일 치과"
# ④ 보관한 것 — 목록에 없고 「보관한 1장」에.
note 01K3ZQDDDDDDDDDDDDDDDDDDDD "$NOW" "archived: $NOW
" "나중에 볼 자료"
# ⑤ 방금 끝낸 것 — 목록에 남아 있다.
note 01K3ZQEEEEEEEEEEEEEEEEEEEE "$NOW" "done: $NOW
" "견적 보내기
- [x] 초안"
# ⑥ 열흘 전에 다 체크한 목록 — 켜자마자 규칙이 치우고, 「하나씩 꺼내기」에 이름이 선다.
note 01K3ZQFFFFFFFFFFFFFFFFFFFF "$OLD" "" "장보기
- [x] 우유"

OUT="$(LAZYMEMO_VAULT="$VAULT" LAZYMEMO_MENU=1 "$BIN" 2>&1 || true)"

printf '%s\n' "$OUT" | sed -n '/메뉴/,$p'

expect() { # 패턴, 설명
    case "$OUT" in
        *"$1"*) ;;
        *) echo "✗ $2 — 「$1」이 메뉴에 없습니다"; exit 1 ;;
    esac
}
expect "놓친 2장" "놓친 것의 수가 서야 한다"
expect "나중에 1장" "나중에의 수가 서야 한다"
expect "읽을 글 — 게으른 사람" "놓친 다시 보기가 하위 메뉴에 있어야 한다"
expect "서류 제출" "마감 지난 칸 남은 목록이 놓친 것에 있어야 한다"
expect "· 완료" "놓친 것마다 「완료」가 있어야 한다"
expect "· 보관" "놓친 것마다 「보관」이 있어야 한다"
expect "내일 아침으로" "놓친 것마다 미루는 길이 있어야 한다"
expect "보관한 1장" "보관한 것은 따로 세어야 한다"
expect "나중에 볼 자료" "보관한 것을 하나씩 꺼낼 수 있어야 한다"
expect "메모 4장" "보관한 것은 목록에서 빠지고, 끝낸 것은 남는다"
expect "견적 보내기" "방금 끝낸 것은 목록에 남아 있어야 한다"
expect "치워 둔 1장" "규칙이 치운 것은 따로 세어야 한다"
expect "하나씩 꺼내기" "치워 둔 것을 하나씩 꺼내는 길이 있어야 한다"
expect "장보기" "치워 둔 것의 이름이 하위 메뉴에 있어야 한다"
case "$OUT" in
    *"지운 메모"*) echo "✗ 보관한 것이 지운 메모로 세어졌습니다"; exit 1 ;;
esac
echo "✓ 놓친 것·나중에가 한 줄로 서고, 보관은 따로, 끝낸 것은 남습니다"
