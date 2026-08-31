#!/usr/bin/env bash
# 빌드 부산물을 턴다. 전부 다시 만들어지는 것들만 지운다.
#
#   ./scripts/clean.sh          # 캐시만 (ModuleCache·index) — 다음 빌드는 증분
#   ./scripts/clean.sh --all    # .build · build · dist 통째로 — 다음 빌드는 전체
#
# ModuleCache 는 swift 가 프레임워크 모듈을 미리 씹어둔 곳으로, 상한이 없어
# 혼자 수백 MB 까지 자란다. 지워도 코드는 그대로라 다시 채워질 뿐이다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALL=0
[[ "${1:-}" == "--all" ]] && ALL=1

# du 는 대상이 없으면 실패하므로 존재하는 것만 센다.
usage() {
    local total=0 path size
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        size=$(du -sk "$path" 2>/dev/null | cut -f1)
        total=$((total + size))
    done
    echo "$total"
}

human() { echo "$(( $1 / 1024 ))MB"; }

TARGETS=()
if (( ALL )); then
    TARGETS=(.build build dist)
else
    while IFS= read -r path; do
        TARGETS+=("$path")
    done < <(find .build -maxdepth 3 \( -name ModuleCache -o -name index \) -type d 2>/dev/null)
fi

if (( ${#TARGETS[@]} == 0 )); then
    echo "✓ 지울 것이 없습니다"
    exit 0
fi

BEFORE=$(usage "${TARGETS[@]}")
echo "▸ 지울 대상"
for path in "${TARGETS[@]}"; do
    printf '  %-56s %s\n' "$path" "$(du -sh "$path" 2>/dev/null | cut -f1)"
done

for path in "${TARGETS[@]}"; do
    rm -rf "$path"
done

echo
echo "✓ $(human "$BEFORE") 회수 — 프로젝트 전체 $(du -sh "$ROOT" | cut -f1)"
if (( ! ALL )); then
    echo "  코드 산출물은 남겨서 다음 빌드는 증분입니다."
fi
