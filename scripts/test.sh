#!/usr/bin/env bash
# swift test 래퍼.
#
# Xcode 없이 Command Line Tools 만 있는 환경에서는 swift-testing 이
# 툴체인 검색 경로 밖에 있어 `swift test` 가 그냥 실패한다.
#   - 컴파일: Testing.framework 가 .../Library/Developer/Frameworks 에 있고
#   - 실행:   그 프레임워크가 참조하는 lib_TestingInterop.dylib 은
#             .../Library/Developer/usr/lib 라는 다른 곳에 있다
# 두 경로를 각각 넣어줘야 빌드와 실행이 모두 통과한다.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 시험은 한 말에 고정한다. `swift test` 의 실행 파일은 툴체인의 헬퍼라 lproj 가
# 없고, 그러면 표 고르기가 기계의 말과 상관없이 개발 언어(영어)로 떨어진다 —
# 한국어 원문을 기대하는 시험이 한국어 기계에서도 빨개진다 (Words.locale 참조).
export LAZYMEMO_LANGUAGE="${LAZYMEMO_LANGUAGE:-ko}"

DEV="$(xcode-select -p)/Library/Developer"

if [ -d "$DEV/Frameworks/Testing.framework" ]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$DEV/Frameworks" \
        -Xlinker -F -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/usr/lib" \
        "$@"
fi

# Xcode 가 설치된 환경에서는 표준 경로로 이미 찾을 수 있다.
exec swift test "$@"
