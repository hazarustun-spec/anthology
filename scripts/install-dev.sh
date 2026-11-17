#!/usr/bin/env bash
# Build anthology-mcp and register it with Claude Code (user scope).
set -euo pipefail
cd "$(dirname "$0")/../MarginKit"
swift build -c release --product anthology-mcp
DEST="$HOME/Library/Application Support/Anthology/bin"
mkdir -p "$DEST"
# Replace (not overwrite) so macOS does not kill the binary over a stale code-signature cache.
rm -f "$DEST/anthology-mcp"
cp "$(swift build -c release --show-bin-path)/anthology-mcp" "$DEST/anthology-mcp"
claude mcp remove margin --scope user >/dev/null 2>&1 || true
claude mcp add --scope user margin -- "$DEST/anthology-mcp"
echo "Installed: $DEST/anthology-mcp"
