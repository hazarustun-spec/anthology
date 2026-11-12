#!/usr/bin/env bash
# End-to-end smoke test for the margin-mcp stdio server.
set -euo pipefail
cd "$(dirname "$0")/../MarginKit"
swift build -c release --product margin-mcp >/dev/null
BIN="$(swift build -c release --show-bin-path)/margin-mcp"
ROOT="$(mktemp -d)"
OUT="$ROOT/out.txt"

{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"save_note","arguments":{"content":"- SQL","summary":"smoke","project_path":"/tmp/Kariyer","note_title":"Skills"}}}'
  sleep 2
} | MARGIN_ROOT="$ROOT" "$BIN" > "$OUT" 2>"$ROOT/err.txt" &
PID=$!
for _ in $(seq 1 50); do grep -q 'Saved to' "$OUT" 2>/dev/null && break; sleep 0.1; done
sleep 0.3; kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true

fail() { echo "FAIL: $1"; echo "--- stdout"; cat "$OUT"; echo "--- stderr"; cat "$ROOT/err.txt"; exit 1; }
grep -q '"instructions"' "$OUT" || fail "initialize has no instructions"
grep -q '"save_note"' "$OUT" || fail "tools/list missing save_note"
grep -q 'Saved to Kariyer › Skills' "$OUT" || fail "save_note did not save"
ls "$ROOT"/kariyer-*/skills.md >/dev/null 2>&1 || fail "note file not on disk"
echo "PASS: margin-mcp smoke"
