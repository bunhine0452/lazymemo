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
