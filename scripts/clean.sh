#!/usr/bin/env bash
# 빌드 부산물을 턴다. 전부 다시 만들어지는 것들만 지운다.
#
#   ./scripts/clean.sh          # 캐시만 (ModuleCache·index) — 다음 빌드는 증분
#   ./scripts/clean.sh --all    # 파생물 통째로 — 다음 빌드는 전체
#
# 어디에 무엇이 쌓이나 (2026-09-16 실측, 프로젝트 7.1GB 중 소스·문서·git 은 80MB):
#   .build/                    swift build — Swift 6.2 는 out/·xc-mac/ 에도 쓴다 (xcodebuild 잔재가 아니다) · ~3GB
#   .build/ios/                시뮬레이터 derived data (ios/scripts/uitest.sh·record-demo.sh)
#   spikes/*/.build/           로컬 모델 spike 산출물. LiteRTSpike 는 루트 패키지를 path 로 빌려 저장소 클론이 없다
#   build/                     xcarchive(ios/scripts/archive.sh)·render-ui PNG — 업로드·확인이 끝나면 쓸모가 없다
#   dist/                      build-app.sh 의 앱 번들
#   ~/Library/Developer/Xcode/DerivedData/LazyMemo-*   Xcode 로 열었을 때 — 프로젝트 밖이지만 이 프로젝트 것
#
# ModuleCache 는 swift 가 프레임워크 모듈을 미리 씹어둔 곳으로, 상한이 없어
# 혼자 수백 MB 까지 자란다. 지워도 코드는 그대로라 다시 채워질 뿐이다.
#
# 여러 세션이 한 워킹트리를 쓴다 — 다른 세션의 빌드가 도는 중이면 발밑을 빼지 않고 멈춘다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALL=0
[[ "${1:-}" == "--all" ]] && ALL=1

for proc in swift-build swift-frontend xcodebuild; do
    if pgrep -x "$proc" >/dev/null; then
        echo "✗ $proc 가 돌고 있습니다 — 다른 세션의 빌드일 수 있어 지우지 않습니다" >&2
        exit 1
    fi
done

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
    for path in .build build dist spikes/*/.build; do
        [[ -e "$path" ]] && TARGETS+=("$path")
    done
    # Xcode 가 열려 있으면 DerivedData 는 그쪽이 쓰고 있다 — 건드리지 않고 그렇게 말한다.
    if pgrep -x Xcode >/dev/null; then
        echo "▸ Xcode 가 열려 있어 DerivedData 는 두었습니다 (닫고 다시 돌리면 함께 지웁니다)"
    else
        for derived in "$HOME"/Library/Developer/Xcode/DerivedData/LazyMemo-* "$HOME"/Library/Developer/Xcode/DerivedData/lazymemo-*; do
            [[ -d "$derived" ]] && TARGETS+=("$derived")
        done
    fi
else
    ROOTS=()
    for path in .build spikes/*/.build; do
        [[ -d "$path" ]] && ROOTS+=("$path")
    done
    if (( ${#ROOTS[@]} )); then
        while IFS= read -r path; do
            TARGETS+=("$path")
        done < <(find "${ROOTS[@]}" -maxdepth 3 \( -name 'ModuleCache*' -o -name index \) -type d 2>/dev/null)
    fi
fi

if (( ${#TARGETS[@]} == 0 )); then
    echo "✓ 지울 것이 없습니다"
    exit 0
fi

BEFORE=$(usage "${TARGETS[@]}")
echo "▸ 지울 대상"
for path in "${TARGETS[@]}"; do
    printf '  %-56s %s\n' "${path/#$HOME/~}" "$(du -sh "$path" 2>/dev/null | cut -f1)"
done

for path in "${TARGETS[@]}"; do
    rm -rf "$path"
done

echo
echo "✓ $(human "$BEFORE") 회수 — 프로젝트 전체 $(du -sh "$ROOT" | cut -f1)"
if (( ! ALL )); then
    echo "  코드 산출물은 남겨서 다음 빌드는 증분입니다."
fi
