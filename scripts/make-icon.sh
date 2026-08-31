#!/usr/bin/env bash
# 아이콘을 그려 Resources/AppIcon.icns 와 메뉴바 템플릿을 갱신한다.
#
# 색이나 비례를 바꾸려면 scripts/make-icon.swift 를 고치고 이걸 다시 돌린다.
# 디자인 파일이 아니라 코드가 원본이라, 변경이 diff 로 남는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "▸ 아이콘 렌더"
swift scripts/make-icon.swift --variant "${1:-b}" >/dev/null

echo "▸ .icns 조립"
iconutil --convert icns build/icon/AppIcon.iconset --output Resources/AppIcon.icns

echo "▸ 종이 결"
swift scripts/make-icon.swift --texture >/dev/null

echo "▸ 미리보기"
swift scripts/make-icon.swift --sheet >/dev/null

# ImageIO 가 내보내는 PNG 는 압축이 얕다. 픽셀은 그대로 두고 다시 조이면
# 아이콘만 40% 넘게 준다 — 번들에 들어가는 그림이라 그만큼 앱이 가벼워진다.
echo "▸ 무손실 재압축"
./scripts/shrink-png.py \
    Resources/AppIcon.icns \
    Sources/LazyMemoUI/Resources/PaperGrain.png \
    Sources/LazyMemoUI/Resources/MenuBarIcon.png

echo
echo "✓ Resources/AppIcon.icns"
echo "✓ Sources/LazyMemoUI/Resources/MenuBarIcon.png"
echo "✓ Sources/LazyMemoUI/Resources/PaperGrain.png"
echo "  미리보기: build/icon/comparison.png"
