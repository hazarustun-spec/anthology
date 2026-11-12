#!/usr/bin/env bash
# Build margin-mcp and register it with Claude Code (user scope).
set -euo pipefail
cd "$(dirname "$0")/../MarginKit"
swift build -c release --product margin-mcp
DEST="$HOME/Library/Application Support/Margin/bin"
mkdir -p "$DEST"
# Replace (not overwrite) so macOS does not kill the binary over a stale code-signature cache.
rm -f "$DEST/margin-mcp"
cp "$(swift build -c release --show-bin-path)/margin-mcp" "$DEST/margin-mcp"
claude mcp remove margin --scope user >/dev/null 2>&1 || true
claude mcp add --scope user margin -- "$DEST/margin-mcp"
echo "Installed: $DEST/margin-mcp"
