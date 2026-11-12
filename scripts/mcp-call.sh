#!/usr/bin/env bash
# Call one margin-mcp tool the way Claude would. Usage: mcp-call.sh <tool> '<json args>' [--source cowork]
set -euo pipefail
BIN="$(cd "$(dirname "$0")/../MarginKit" && swift build -c release --show-bin-path)/margin-mcp"
TOOL="$1"; ARGS="$2"; shift 2
OUT="$(mktemp)"
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcp-call","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL\",\"arguments\":$ARGS}}"
  sleep 1.5
} | "$BIN" "$@" > "$OUT" 2>/dev/null || true
grep '"id":2' "$OUT" | python3 -I -c 'import json,sys; r=json.loads(sys.stdin.read())["result"]; print(r["content"][0]["text"])'
