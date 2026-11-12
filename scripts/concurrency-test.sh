#!/usr/bin/env bash
# Many margin-mcp processes append to the same note at once; none of the appends may be lost.
set -euo pipefail
cd "$(dirname "$0")/../MarginKit"
swift build -c release --product margin-mcp >/dev/null
BIN="$(swift build -c release --show-bin-path)/margin-mcp"
ROOT="$(mktemp -d)"
N=12
call() {
  {
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"c","version":"1"}}}'
    echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    echo "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"save_note\",\"arguments\":{\"content\":\"- item $1\",\"summary\":\"s$1\",\"topic\":\"T\",\"note_title\":\"Shared\"}}}"
    sleep 3
  } | MARGIN_ROOT="$ROOT" "$BIN" >/dev/null 2>&1
}
# Seed the topic + note so every process appends to the same file.
call 0
for i in $(seq 1 $N); do call "$i" & done
wait
FILES=$(ls "$ROOT"/t-*/*.md | wc -l | tr -d ' ')
ITEMS=$(cat "$ROOT"/t-*/shared*.md | grep -c '^- item' || true)
HIST=$(cat "$ROOT"/t-*/.history/*.jsonl | wc -l | tr -d ' ')
TOPICS=$(ls -d "$ROOT"/t-* | wc -l | tr -d ' ')
echo "topics=$TOPICS files=$FILES items=$ITEMS history=$HIST (expected 1/1/$((N+1))/$((N+1)))"
[ "$TOPICS" = 1 ] && [ "$FILES" = 1 ] && [ "$ITEMS" = $((N+1)) ] && [ "$HIST" = $((N+1)) ] && echo PASS || { echo FAIL; exit 1; }
