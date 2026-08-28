#!/usr/bin/env bash
# lazymemo 를 Claude Desktop 의 MCP 서버로 등록한다 ({#mcp-onboarding}).
#
#   ./scripts/install-mcp.sh            # 등록
#   ./scripts/install-mcp.sh --dry-run  # 바뀔 내용만 보여주고 끝
#   ./scripts/install-mcp.sh --remove   # 등록 해제
#
# ⚠️ 이 등록이 곧 프라이버시 결정이다. 등록 전까지 lazymemo 는 네트워크를
#    쓰지 않는다. 등록하면 Claude 가 메모를 읽고 쓸 수 있게 된다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
MODE="${1:-install}"

# 앱 번들 안의 바이너리를 가리킨다. swift build 산출물(.build/…)을 가리키면
# clean 이나 리빌드 한 번에 Claude Desktop 쪽 설정이 끊어진다.
BIN="$ROOT/dist/LazyMemo.app/Contents/MacOS/lazymemo-mcp"

if [ "$MODE" != "--remove" ] && [ ! -x "$BIN" ]; then
    echo "▸ 앱 번들이 없어 먼저 빌드합니다"
    "$ROOT/scripts/build-app.sh" release
fi

if [ "$MODE" != "--remove" ] && [ ! -x "$BIN" ]; then
    echo "빌드 산출물을 찾을 수 없습니다: $BIN" >&2
    exit 1
fi

/usr/bin/python3 - "$CONFIG" "$BIN" "$MODE" <<'PY'
import json, os, shutil, sys

config_path, binary, mode = sys.argv[1], sys.argv[2], sys.argv[3]

config = {}
if os.path.exists(config_path):
    try:
        with open(config_path, encoding="utf-8") as handle:
            config = json.load(handle)
    except json.JSONDecodeError:
        print(f"기존 설정을 읽을 수 없습니다: {config_path}", file=sys.stderr)
        print("직접 고친 뒤 다시 실행하세요 — 덮어쓰지 않았습니다.", file=sys.stderr)
        sys.exit(1)

servers = config.setdefault("mcpServers", {})

if mode == "--remove":
    if servers.pop("lazymemo", None) is None:
        print("등록되어 있지 않습니다.")
        sys.exit(0)
else:
    servers["lazymemo"] = {"command": binary}

rendered = json.dumps(config, indent=2, ensure_ascii=False)

if mode == "--dry-run":
    print(f"— {config_path} 에 쓸 내용 —")
    print(rendered)
    sys.exit(0)

os.makedirs(os.path.dirname(config_path), exist_ok=True)
if os.path.exists(config_path):
    backup = config_path + ".lazymemo-backup"
    shutil.copy2(config_path, backup)
    print(f"기존 설정을 백업했습니다: {backup}")

with open(config_path, "w", encoding="utf-8") as handle:
    handle.write(rendered + "\n")

if mode == "--remove":
    print("등록을 해제했습니다.")
else:
    print(f"등록했습니다: {binary}")
print("Claude Desktop 을 완전히 종료했다가 다시 여세요.")
PY
